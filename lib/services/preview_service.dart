import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'environment_service.dart';

class PreviewService {
  static final Map<String, String> _snippetCache = {};

  /// Returns keyframe timestamps (in seconds) for the specified video file.
  static Future<List<double>> getKeyframeTimestamps(String videoPath) async {
    final keyframes = <double>[];
    try {
      final result = await Process.run(
        EnvironmentService.ffprobePath,
        [
          '-v', 'error',
          '-select_streams', 'v:0',
          '-skip_frame', 'nokey',
          '-show_entries', 'frame=pts_time',
          '-of', 'json',
          videoPath,
        ],
        environment: EnvironmentService.processEnvironment,
      );

      if (result.exitCode == 0) {
        final jsonResult = jsonDecode(result.stdout as String);
        final frames = jsonResult['frames'] as List<dynamic>?;
        if (frames != null) {
          for (final frame in frames) {
            final ptsTimeStr = frame['pts_time']?.toString();
            if (ptsTimeStr != null) {
              final val = double.tryParse(ptsTimeStr);
              if (val != null) keyframes.add(val);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error probing keyframes: $e');
    }
    // Remove duplicates and sort
    final uniqueSorted = keyframes.toSet().toList()..sort();
    return uniqueSorted;
  }

  /// Extracts a keyframe-aligned snippet from [videoPath] of approximately [targetDurationSec] seconds.
  /// Uses fast, 100% lossless stream copy (-c copy) between keyframe boundaries.
  /// Falls back to ultrafast re-encode if stream copy fails for exotic video containers.
  static Future<String> extractKeyframeSnippet(
    String videoPath, {
    double targetDurationSec = 3.0,
    bool forceReextract = false,
  }) async {
    if (!forceReextract && _snippetCache.containsKey(videoPath)) {
      final cachedPath = _snippetCache[videoPath]!;
      if (File(cachedPath).existsSync() && File(cachedPath).lengthSync() > 0) {
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

    final keyframes = await getKeyframeTimestamps(videoPath);

    double startSec = 0.0;
    double durationSec = targetDurationSec;

    if (keyframes.length >= 2) {
      final totalDuration = keyframes.last;

      if (totalDuration > targetDurationSec) {
        // Pick a start keyframe between 10% and 75% of total duration (avoiding intros/outros)
        final minStart = totalDuration * 0.10;
        final maxStart = max(minStart, totalDuration - (targetDurationSec + 2.0));

        final candidateIndices = <int>[];
        for (int i = 0; i < keyframes.length - 1; i++) {
          if (keyframes[i] >= minStart && keyframes[i] <= maxStart) {
            candidateIndices.add(i);
          }
        }

        int startIdx = 0;
        if (candidateIndices.isNotEmpty) {
          final rand = Random();
          startIdx = candidateIndices[rand.nextInt(candidateIndices.length)];
        }

        startSec = keyframes[startIdx];

        // Find the keyframe index j >= startIdx where keyframes[j] - startSec >= targetDurationSec
        int endIdx = startIdx + 1;
        for (int j = startIdx + 1; j < keyframes.length; j++) {
          endIdx = j;
          if (keyframes[j] - startSec >= targetDurationSec) {
            break;
          }
        }
        durationSec = max(1.0, keyframes[endIdx] - startSec);
      }
    }

    // 1. Primary Attempt: Keyframe-aligned Lossless Stream Copy
    final streamCopyArgs = <String>[
      '-ss', startSec.toStringAsFixed(3),
      '-i', videoPath,
      '-t', durationSec.toStringAsFixed(3),
      '-c', 'copy',
      '-avoid_negative_ts', 'make_zero',
      '-y',
      outputPath,
    ];

    try {
      final result = await Process.run(
        EnvironmentService.ffmpegPath,
        streamCopyArgs,
        environment: EnvironmentService.processEnvironment,
      );

      final outputFile = File(outputPath);
      if (result.exitCode == 0 && outputFile.existsSync() && outputFile.lengthSync() > 0) {
        _snippetCache[videoPath] = outputPath;
        return outputPath;
      }
      debugPrint('FFmpeg stream copy warning: exitCode=${result.exitCode}, stderr=${result.stderr}. Attempting fallback re-encode...');
    } catch (e) {
      debugPrint('FFmpeg stream copy exception: $e. Attempting fallback re-encode...');
    }

    // 2. Fallback Attempt: Fast Re-encode if Stream Copy Fails
    final fallbackArgs = <String>[
      '-ss', startSec.toStringAsFixed(3),
      '-i', videoPath,
      '-t', durationSec.toStringAsFixed(3),
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
        return outputPath;
      }
    } catch (e) {
      debugPrint('FFmpeg fallback re-encode failed: $e');
    }

    // Fallback to raw input video if extraction completely fails
    return videoPath;
  }

  /// Clears the in-memory snippet cache.
  static void clearCache() {
    _snippetCache.clear();
  }
}
