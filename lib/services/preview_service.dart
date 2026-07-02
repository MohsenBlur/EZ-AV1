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
    keyframes.sort();
    return keyframes;
  }

  /// Extracts a keyframe-aligned snippet from [videoPath] of approximately [targetDurationSec] seconds.
  /// Uses stream copy (-c copy) between keyframe boundaries for instant, 100% lossless extraction.
  static Future<String> extractKeyframeSnippet(
    String videoPath, {
    double targetDurationSec = 3.0,
    bool forceReextract = false,
  }) async {
    if (!forceReextract && _snippetCache.containsKey(videoPath)) {
      final cachedPath = _snippetCache[videoPath]!;
      if (File(cachedPath).existsSync()) {
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
    double? endSec;

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
        endSec = keyframes[endIdx];
      }
    }

    final args = <String>[
      '-ss', startSec.toStringAsFixed(3),
    ];
    if (endSec != null) {
      args.addAll(['-to', endSec.toStringAsFixed(3)]);
    } else {
      args.addAll(['-t', targetDurationSec.toStringAsFixed(3)]);
    }

    args.addAll([
      '-i', videoPath,
      '-c', 'copy',
      '-avoid_negative_ts', 'make_zero',
      '-y',
      outputPath,
    ]);

    try {
      final result = await Process.run(
        EnvironmentService.ffmpegPath,
        args,
        environment: EnvironmentService.processEnvironment,
      );

      if (result.exitCode == 0 && File(outputPath).existsSync()) {
        _snippetCache[videoPath] = outputPath;
        return outputPath;
      } else {
        debugPrint('FFmpeg snippet extraction non-zero exit: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('FFmpeg snippet extraction failed: $e');
    }

    // Fallback if keyframe stream copy failed: fallback to raw input video
    return videoPath;
  }
}
