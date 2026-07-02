import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/batch_node_model.dart';
import '../models/execution_model.dart';
import '../services/av1an_service.dart';
import '../services/environment_service.dart';
import 'batch_queue_provider.dart';

final executionProvider = NotifierProvider<ExecutionNotifier, ExecutionState>(() {
  return ExecutionNotifier();
});

class ExecutionState {
  final List<ExecutionJob> jobs;
  final bool isRunning;
  final bool lowSpecMode;
  final bool overwriteFiles;
  final String? customOutputDirectory;
  final String? activeJobId;
  
  ExecutionState({
    this.jobs = const [],
    this.isRunning = false,
    this.lowSpecMode = false,
    this.overwriteFiles = false,
    this.customOutputDirectory,
    this.activeJobId,
  });

  ExecutionState copyWith({
    List<ExecutionJob>? jobs,
    bool? isRunning,
    bool? lowSpecMode,
    bool? overwriteFiles,
    String? customOutputDirectory,
    String? activeJobId,
  }) {
    return ExecutionState(
      jobs: jobs ?? this.jobs,
      isRunning: isRunning ?? this.isRunning,
      lowSpecMode: lowSpecMode ?? this.lowSpecMode,
      overwriteFiles: overwriteFiles ?? this.overwriteFiles,
      customOutputDirectory: customOutputDirectory ?? this.customOutputDirectory,
      activeJobId: activeJobId ?? this.activeJobId,
    );
  }
}

class ExecutionNotifier extends Notifier<ExecutionState> {
  Process? _activeProcess;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  @override
  ExecutionState build() {
    // Listen to changes in the batch queue to sync pending jobs
    ref.listen<List<BatchNode>>(batchQueueProvider, (previous, next) {
      if (!state.isRunning) {
        _syncJobsFromQueue(next);
      }
    });
    
    // Initial sync
    Future.microtask(() => _syncJobsFromQueue(ref.read(batchQueueProvider)));
    
    return ExecutionState();
  }

  void setLowSpecMode(bool value) {
    state = state.copyWith(lowSpecMode: value);
  }

  void setCustomOutputDirectory(String? dir) {
    state = ExecutionState(
      jobs: state.jobs,
      isRunning: state.isRunning,
      lowSpecMode: state.lowSpecMode,
      overwriteFiles: state.overwriteFiles,
      customOutputDirectory: dir,
      activeJobId: state.activeJobId,
    );
  }

  void _syncJobsFromQueue(List<BatchNode> nodes) {
    final files = BatchNode.extractFileNodes(nodes);

    // Group & deduplicate by absolutePath so render queue NEVER contains duplicate jobs for the same file
    final uniqueFilesByPath = <String, FileNode>{};
    for (final f in files) {
      if (!uniqueFilesByPath.containsKey(f.absolutePath)) {
        uniqueFilesByPath[f.absolutePath] = f;
      }
    }

    final existingJobs = {for (var j in state.jobs) (j.node as FileNode).absolutePath: j};
    final newJobs = uniqueFilesByPath.values.map((f) {
      if (existingJobs.containsKey(f.absolutePath)) {
        return existingJobs[f.absolutePath]!.copyWith(node: f);
      }
      return ExecutionJob(id: f.id, node: f);
    }).toList();

    state = state.copyWith(jobs: newJobs);
  }

  List<String> getExistingOutputFiles() {
    final existing = <String>[];
    for (final job in state.jobs) {
      if (job.status == JobStatus.done) continue;
      final fileNode = job.node as FileNode;
      final outputDir = (state.customOutputDirectory != null && state.customOutputDirectory!.isNotEmpty)
          ? state.customOutputDirectory!
          : p.dirname(fileNode.absolutePath);
      final outputVideo = p.join(outputDir, '${p.basenameWithoutExtension(fileNode.name)}_av1.mkv');
      if (File(outputVideo).existsSync()) {
        existing.add(outputVideo);
      }
    }
    return existing;
  }

  Future<void> startBatch({bool overwriteFiles = false}) async {
    if (state.isRunning) return;
    if (state.jobs.isEmpty) return;

    state = state.copyWith(isRunning: true, overwriteFiles: overwriteFiles);
    
    // Execution Loop
    for (int i = 0; i < state.jobs.length; i++) {
      if (!state.isRunning) break; // User stopped
      
      final job = state.jobs[i];
      if (job.status == JobStatus.done) continue;

      await _executeJob(job.id);
    }

    state = state.copyWith(isRunning: false, activeJobId: null);
  }

  Future<void> stopBatch() async {
    state = state.copyWith(isRunning: false);
    
    if (_activeProcess != null) {
      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/F', '/T', '/PID', _activeProcess!.pid.toString()]);
        } catch (e) {
          _activeProcess!.kill();
        }
      } else {
        _activeProcess!.kill();
      }
      _activeProcess = null;
    }
    
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
  }

  List<String> _capLogLines(List<String> lines, {int maxLines = 500, int headLines = 50}) {
    if (lines.length <= maxLines) return lines;
    final head = lines.sublist(0, headLines);
    final tailCount = maxLines - headLines - 1;
    final tail = lines.sublist(lines.length - tailCount);
    return [
      ...head,
      '--- [log output truncated: ${lines.length - maxLines} lines omitted] ---',
      ...tail,
    ];
  }

  void _updateJob(String id, ExecutionJob Function(ExecutionJob) updater) {
    if (!state.jobs.any((j) => j.id == id)) return;
    final newJobs = state.jobs.map((j) {
      if (j.id == id) return updater(j);
      return j;
    }).toList();
    state = state.copyWith(jobs: newJobs);
  }

  Future<void> _executeJob(String jobId) async {
    state = state.copyWith(activeJobId: jobId);
    _updateJob(jobId, (j) => j.copyWith(status: JobStatus.encoding));

    final jobIndex = state.jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;
    final job = state.jobs[jobIndex];

    final fileNode = job.node as FileNode;
    
    final preset = fileNode.effectivePreset;
    if (preset == null) {
      _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: 'No preset assigned'));
      return;
    }

    // Determine output path (User custom folder or adjacent to original)
    final outputDir = (state.customOutputDirectory != null && state.customOutputDirectory!.isNotEmpty)
        ? state.customOutputDirectory!
        : p.dirname(fileNode.absolutePath);

    final outDirObj = Directory(outputDir);
    if (!outDirObj.existsSync()) {
      try {
        outDirObj.createSync(recursive: true);
      } catch (e) {
        _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: 'Cannot create output directory: $e'));
        return;
      }
    }

    final outputVideo = p.join(outputDir, '${p.basenameWithoutExtension(fileNode.name)}_av1.mkv');

    // Pre-flight file deletion to prevent Av1an hanging on overwrite prompts
    if (state.overwriteFiles) {
      final outFile = File(outputVideo);
      if (outFile.existsSync()) {
        try {
          outFile.deleteSync();
        } catch (e) {
          _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: 'Failed to overwrite existing file: $e'));
          return;
        }
      }
    }

    final args = Av1anService.buildArgs(
      sourceVideo: fileNode.absolutePath,
      outputVideo: outputVideo,
      preset: preset,
      workers: state.lowSpecMode ? 1 : null,
    );

    try {
      _activeProcess = await Process.start(
        EnvironmentService.av1anPath,
        args,
        environment: EnvironmentService.processEnvironment,
      );

      final watch = Stopwatch()..start();
      double? latestProgress;
      double? latestFps;
      String? latestEta;
      List<String> pendingLogs = [];

      void handleLog(String data) {
        final percentMatch = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(data);
        final fpsMatch = RegExp(r'(\d+(?:\.\d+)?)\s*fps', caseSensitive: false).firstMatch(data);
        final etaMatch = RegExp(r'ETA:\s*([0-9:]+)', caseSensitive: false).firstMatch(data);

        if (percentMatch != null) {
          latestProgress = double.tryParse(percentMatch.group(1)!);
        } else {
          final fractionMatch = RegExp(r'\[(\d+)/(\d+)\]').firstMatch(data);
          if (fractionMatch != null) {
            final done = double.tryParse(fractionMatch.group(1)!);
            final total = double.tryParse(fractionMatch.group(2)!);
            if (done != null && total != null && total > 0) {
              latestProgress = (done / total) * 100.0;
            }
          }
        }

        if (fpsMatch != null) latestFps = double.tryParse(fpsMatch.group(1)!);
        if (etaMatch != null) latestEta = etaMatch.group(1);

        pendingLogs.add(data);

        if (watch.elapsedMilliseconds > 250) {
          _updateJob(jobId, (j) {
            final newLines = List<String>.from(j.logLines)..addAll(pendingLogs);
            return j.copyWith(
              progress: latestProgress != null ? (latestProgress! / 100.0) : j.progress,
              fps: latestFps ?? j.fps,
              eta: latestEta ?? j.eta,
              logLines: _capLogLines(newLines),
            );
          });
          pendingLogs.clear();
          watch.reset();
        }
      }

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      _stdoutSub = _activeProcess!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            handleLog,
            onDone: () => stdoutDone.complete(),
            onError: (_) => stdoutDone.complete(),
          );
      _stderrSub = _activeProcess!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            handleLog,
            onDone: () => stderrDone.complete(),
            onError: (_) => stderrDone.complete(),
          );

      final exitCode = await _activeProcess!.exitCode;

      await Future.wait([
        stdoutDone.future,
        stderrDone.future,
      ]).timeout(const Duration(seconds: 2), onTimeout: () => []);

      if (pendingLogs.isNotEmpty) {
        _updateJob(jobId, (j) {
          final newLines = List<String>.from(j.logLines)..addAll(pendingLogs);
          return j.copyWith(logLines: _capLogLines(newLines));
        });
        pendingLogs.clear();
      }

      if (exitCode == 0) {
        _updateJob(jobId, (j) => j.copyWith(status: JobStatus.done, progress: 1.0));
      } else {
        if (state.isRunning) {
          _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: 'Process exited with code $exitCode'));
        } else {
          _updateJob(jobId, (j) => j.copyWith(status: JobStatus.paused));
        }
      }
    } catch (e) {
      _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: e.toString()));
    } finally {
      _activeProcess = null;
      await _stdoutSub?.cancel();
      await _stderrSub?.cancel();
    }
  }
}
