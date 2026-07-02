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
  final String? activeJobId;
  
  ExecutionState({
    this.jobs = const [],
    this.isRunning = false,
    this.lowSpecMode = false,
    this.overwriteFiles = false,
    this.activeJobId,
  });

  ExecutionState copyWith({
    List<ExecutionJob>? jobs,
    bool? isRunning,
    bool? lowSpecMode,
    bool? overwriteFiles,
    String? activeJobId,
  }) {
    return ExecutionState(
      jobs: jobs ?? this.jobs,
      isRunning: isRunning ?? this.isRunning,
      lowSpecMode: lowSpecMode ?? this.lowSpecMode,
      overwriteFiles: overwriteFiles ?? this.overwriteFiles,
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

  void _syncJobsFromQueue(List<BatchNode> nodes) {
    final files = BatchNode.extractFileNodes(nodes);

    // Smart Merge: Retain existing state for known IDs
    final existingJobs = {for (var j in state.jobs) j.id: j};
    final newJobs = files.map((f) {
      if (existingJobs.containsKey(f.id)) {
        return existingJobs[f.id]!.copyWith(node: f); // Update node but keep status/logs
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
      final outputVideo = p.join(p.dirname(fileNode.absolutePath), '${p.basenameWithoutExtension(fileNode.name)}_av1.mkv');
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
      // Aggressively kill the process tree in Windows
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

  void _updateJob(String id, ExecutionJob Function(ExecutionJob) updater) {
    final newJobs = state.jobs.map((j) {
      if (j.id == id) return updater(j);
      return j;
    }).toList();
    state = state.copyWith(jobs: newJobs);
  }

  Future<void> _executeJob(String jobId) async {
    state = state.copyWith(activeJobId: jobId);
    _updateJob(jobId, (j) => j.copyWith(status: JobStatus.encoding));

    final job = state.jobs.firstWhere((j) => j.id == jobId);
    final fileNode = job.node as FileNode;
    
    final preset = fileNode.effectivePreset;
    if (preset == null) {
      _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: 'No preset assigned'));
      return;
    }

    // Determine output path (e.g. adjacent to original)
    final outputVideo = p.join(p.dirname(fileNode.absolutePath), '${p.basenameWithoutExtension(fileNode.name)}_av1.mkv');

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
        // Regex for standard Av1an stderr: [12/100] 12.0% | 2.1 fps | ETA: 00:15:30
        final percentMatch = RegExp(r'(\d+\.\d+)%').firstMatch(data);
        final fpsMatch = RegExp(r'(\d+\.\d+)\s*fps').firstMatch(data);
        final etaMatch = RegExp(r'ETA:\s*([0-9:]+)').firstMatch(data);

        if (percentMatch != null) latestProgress = double.tryParse(percentMatch.group(1)!);
        if (fpsMatch != null) latestFps = double.tryParse(fpsMatch.group(1)!);
        if (etaMatch != null) latestEta = etaMatch.group(1);

        pendingLogs.add(data);

        // Throttle UI updates to roughly every 250ms without losing logs
        if (watch.elapsedMilliseconds > 250) {
          _updateJob(jobId, (j) {
            final newLines = List<String>.from(j.logLines)..addAll(pendingLogs);
            if (newLines.length > 200) {
              newLines.removeRange(0, newLines.length - 200); // Keep buffer capped at 200 lines
            }

            return j.copyWith(
              progress: latestProgress != null ? (latestProgress! / 100.0) : j.progress,
              fps: latestFps ?? j.fps,
              eta: latestEta ?? j.eta,
              logLines: newLines,
            );
          });
          pendingLogs.clear();
          watch.reset();
        }
      }

      _stdoutSub = _activeProcess!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(handleLog);
      _stderrSub = _activeProcess!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(handleLog);

      final exitCode = await _activeProcess!.exitCode;

      // Flush any remaining logs that were caught in the throttle buffer
      if (pendingLogs.isNotEmpty) {
        _updateJob(jobId, (j) {
          final newLines = List<String>.from(j.logLines)..addAll(pendingLogs);
          if (newLines.length > 200) newLines.removeRange(0, newLines.length - 200);
          return j.copyWith(logLines: newLines);
        });
      }

      if (exitCode == 0) {
        _updateJob(jobId, (j) => j.copyWith(status: JobStatus.done, progress: 1.0));
      } else {
        if (state.isRunning) {
          _updateJob(jobId, (j) => j.copyWith(status: JobStatus.error, errorMessage: 'Process exited with code $exitCode'));
        } else {
           // It was stopped by user
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
