import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'environment_service.dart';

class PreviewService {
  static final Map<String, String> _snippetCache = {};

  /// Multi-fallback container duration probing in seconds (~5ms execution).
  static Future<double> getVideoDuration(String videoPath) async {
    if (videoPath.isEmpty || !File(videoPath).existsSync()) {
      return 0.0;
    }

    try {
      // 1. Format duration
      final result1 = await Process.run(
        EnvironmentService.ffprobePath,
        [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          videoPath,
        ],
        environment: EnvironmentService.processEnvironment,
      );

      if (result1.exitCode == 0) {
        final val = double.tryParse((result1.stdout as String).trim());
        if (val != null && val > 0) return val;
      }

      // 2. Stream duration (video stream 0)
      final result2 = await Process.run(
        EnvironmentService.ffprobePath,
        [
          '-v', 'error',
          '-select_streams', 'v:0',
          '-show_entries', 'stream=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          videoPath,
        ],
        environment: EnvironmentService.processEnvironment,
      );

      if (result2.exitCode == 0) {
        final val = double.tryParse((result2.stdout as String).trim());
        if (val != null && val > 0) return val;
      }

      // 3. Container tag DURATION (HH:MM:SS.mmm format)
      final result3 = await Process.run(
        EnvironmentService.ffprobePath,
        [
          '-v', 'error',
          '-show_entries', 'format_tags=DURATION:stream_tags=DURATION',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          videoPath,
        ],
        environment: EnvironmentService.processEnvironment,
      );

      if (result3.exitCode == 0) {
        final tagStr = (result3.stdout as String).trim();
        for (final line in tagStr.split('\n')) {
          final parts = line.trim().split(':');
          if (parts.length == 3) {
            final h = double.tryParse(parts[0]) ?? 0;
            final m = double.tryParse(parts[1]) ?? 0;
            final s = double.tryParse(parts[2]) ?? 0;
            final total = h * 3600 + m * 60 + s;
            if (total > 0) return total;
          }
        }
      }
    } catch (e) {
      debugPrint('[PreviewService] Duration probe exception: $e');
    }
    return 0.0;
  }

  /// Extracts a keyframe-aligned snippet from [videoPath] of approximately [targetDurationSec] seconds.
  /// Uses fast input seeking (-ss before -i) and stream copy (-c copy) to cut at keyframe boundaries instantly (~15ms).
  /// Falls back to ultrafast re-encode if stream copy fails for exotic video containers.
  static Future<String> extractKeyframeSnippet(
    String videoPath, {
    double targetDurationSec = 3.0,
    bool forceReextract = false,
  }) async {
    if (videoPath.isEmpty || !File(videoPath).existsSync()) {
      debugPrint('[PreviewService] Cannot extract snippet, file does not exist on disk: $videoPath');
      return '';
    }

    final stopwatch = Stopwatch()..start();
    debugPrint('[PreviewService] Starting keyframe snippet extraction for: $videoPath');

    if (!forceReextract && _snippetCache.containsKey(videoPath)) {
      final cachedPath = _snippetCache[videoPath]!;
      if (File(cachedPath).existsSync() && File(cachedPath).lengthSync() > 0) {
        debugPrint('[PreviewService] Serving cached snippet (${File(cachedPath).lengthSync()} bytes) in ${stopwatch.elapsedMilliseconds}ms: $cachedPath');
        return cachedPath;
      }
    }

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }

    final ext = p.extension(videoPath).isNotEmpty ? p.extension(videoPath) : '.mp4';
    final fileName = 'ez_av1_snippet_${videoPath.hashCode.abs()}$ext';
    final outputPath = p.join(tempDir.path, fileName);

    final totalDurationSec = await getVideoDuration(videoPath);
    debugPrint('[PreviewService] Probed total video duration: ${totalDurationSec.toStringAsFixed(2)}s');

    double startSec = 0.0;
    if (totalDurationSec > targetDurationSec + 2.0) {
      final minStart = totalDurationSec * 0.15;
      final maxStart = totalDurationSec - (targetDurationSec + 2.0);
      startSec = minStart + Random().nextDouble() * (maxStart - minStart);
    }

    debugPrint('[PreviewService] Selected target start timestamp: ${startSec.toStringAsFixed(2)}s (Target duration: ${targetDurationSec}s)');

    // 1. Primary Attempt: Instant Keyframe Seek Stream Copy (-ss BEFORE -i seeks to nearest I-frame in ~10ms)
    final args = <String>[
      '-ss', startSec.toStringAsFixed(3),
      '-i', videoPath,
      '-t', targetDurationSec.toStringAsFixed(3),
      '-c', 'copy',
      '-avoid_negative_ts', 'make_zero',
      '-y',
      outputPath,
    ];

    debugPrint('[PreviewService] Executing FFmpeg fast keyframe stream-copy: ${args.join(" ")}');

    try {
      final result = await Process.run(
        EnvironmentService.ffmpegPath,
        args,
        environment: EnvironmentService.processEnvironment,
      );

      final outputFile = File(outputPath);
      if (result.exitCode == 0 && outputFile.existsSync() && outputFile.lengthSync() > 0) {
        _snippetCache[videoPath] = outputPath;
        debugPrint('[PreviewService] Snippet extracted successfully in ${stopwatch.elapsedMilliseconds}ms (${outputFile.lengthSync()} bytes): $outputPath');
        return outputPath;
      } else {
        debugPrint('[PreviewService] FFmpeg stream copy warning: exitCode=${result.exitCode}, stderr=${result.stderr}');
      }
    } catch (e) {
      debugPrint('[PreviewService] FFmpeg stream copy exception: $e');
    }

    // 2. Fallback Attempt: Fast Re-encode if Stream Copy Fails
    debugPrint('[PreviewService] Falling back to ultrafast re-encode...');
    final fallbackArgs = <String>[
      '-ss', startSec.toStringAsFixed(3),
      '-i', videoPath,
      '-t', targetDurationSec.toStringAsFixed(3),
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-crf', '18',
      '-an',
      '-y',
      outputPath,
    ];

    try {
      final result = await Process.run(
        EnvironmentService.ffmpegPath,
        fallbackArgs,
        environment: EnvironmentService.processEnvironment,
      );

      final outputFile = File(outputPath);
      if (result.exitCode == 0 && outputFile.existsSync() && outputFile.lengthSync() > 0) {
        _snippetCache[videoPath] = outputPath;
        debugPrint('[PreviewService] Fallback snippet re-encoded in ${stopwatch.elapsedMilliseconds}ms: $outputPath');
        return outputPath;
      }
    } catch (e) {
      debugPrint('[PreviewService] Fallback re-encode exception: $e');
    }

    return videoPath;
  }

  /// Clears the in-memory snippet cache.
  static void clearCache() {
    _snippetCache.clear();
  }
}
