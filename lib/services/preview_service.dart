import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'environment_service.dart';

class MediaColorProfile {
  final String? colorSpace;
  final String? colorTransfer;
  final String? colorPrimaries;
  final String? colorRange;

  const MediaColorProfile({
    this.colorSpace,
    this.colorTransfer,
    this.colorPrimaries,
    this.colorRange,
  });

  List<String> toFfmpegArgs() {
    final args = <String>[];
    if (colorSpace != null && colorSpace != 'unknown' && colorSpace != 'unspecified') {
      args.addAll(['-colorspace', colorSpace!]);
    }
    if (colorTransfer != null && colorTransfer != 'unknown' && colorTransfer != 'unspecified') {
      args.addAll(['-color_trc', colorTransfer!]);
    }
    if (colorPrimaries != null && colorPrimaries != 'unknown' && colorPrimaries != 'unspecified') {
      args.addAll(['-color_primaries', colorPrimaries!]);
    }
    if (colorRange != null && colorRange != 'unknown' && colorRange != 'unspecified') {
      args.addAll(['-color_range', colorRange!]);
    }
    return args;
  }

  List<String> toSvtAv1Args() {
    if (colorSpace == 'bt2020nc' || colorSpace == 'bt2020c') {
      return ['--color-primaries', '9', '--transfer-characteristics', '16', '--matrix-coefficients', '9', '--color-range', '0'];
    } else if (colorSpace == 'smpte170m' || colorSpace == 'bt470bg') {
      return ['--color-primaries', '6', '--transfer-characteristics', '6', '--matrix-coefficients', '6', '--color-range', '0'];
    }
    return ['--color-primaries', '1', '--transfer-characteristics', '1', '--matrix-coefficients', '1', '--color-range', '0'];
  }

  List<String> toAv1MetadataBsf() {
    if (colorSpace == 'bt2020nc' || colorSpace == 'bt2020c') {
      return ['-bsf:v', 'av1_metadata=color_primaries=9:transfer_characteristics=16:matrix_coefficients=9:color_range=tv'];
    } else if (colorSpace == 'smpte170m' || colorSpace == 'bt470bg') {
      return ['-bsf:v', 'av1_metadata=color_primaries=6:transfer_characteristics=6:matrix_coefficients=6:color_range=tv'];
    }
    return ['-bsf:v', 'av1_metadata=color_primaries=1:transfer_characteristics=1:matrix_coefficients=1:color_range=tv'];
  }
}

class PreviewService {
  static final Map<String, String> _snippetCache = {};
  static final Map<String, MediaColorProfile> _profileCache = {};

  /// Probes exact color space, transfer, primaries, and range attributes of [videoPath] using ffprobe (0 guessing).
  static Future<MediaColorProfile> detectColorProfile(String videoPath) async {
    if (videoPath.isEmpty || !File(videoPath).existsSync()) {
      return const MediaColorProfile();
    }

    if (_profileCache.containsKey(videoPath)) {
      return _profileCache[videoPath]!;
    }

    try {
      final result = await Process.run(
        EnvironmentService.ffprobePath,
        [
          '-v', 'error',
          '-select_streams', 'v:0',
          '-show_entries', 'stream=color_space,color_transfer,color_primaries,color_range',
          '-of', 'json',
          videoPath,
        ],
        environment: EnvironmentService.processEnvironment,
      );

      if (result.exitCode == 0) {
        final Map<String, dynamic> data = json.decode(result.stdout as String);
        final streams = data['streams'] as List<dynamic>?;
        if (streams != null && streams.isNotEmpty) {
          final s = streams.first as Map<String, dynamic>;
          final profile = MediaColorProfile(
            colorSpace: s['color_space']?.toString(),
            colorTransfer: s['color_transfer']?.toString(),
            colorPrimaries: s['color_primaries']?.toString(),
            colorRange: s['color_range']?.toString(),
          );
          _profileCache[videoPath] = profile;
          debugPrint('[PreviewService] Probed source color profile for $videoPath: space=${profile.colorSpace}, trc=${profile.colorTransfer}, primaries=${profile.colorPrimaries}, range=${profile.colorRange}');
          return profile;
        }
      }
    } catch (e) {
      debugPrint('[PreviewService] Color profile probe exception: $e');
    }

    return const MediaColorProfile();
  }

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
  /// Uses a deterministic timestamp (25% of duration) so Phase 1, Phase 2, and Phase 3 share the EXACT same frame range.
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

    final profile = await detectColorProfile(videoPath);

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }

    final fileName = 'ez_av1_snippet_${videoPath.hashCode.abs()}.mp4';
    final outputPath = p.join(tempDir.path, fileName);

    final totalDurationSec = await getVideoDuration(videoPath);
    debugPrint('[PreviewService] Probed total video duration: ${totalDurationSec.toStringAsFixed(2)}s');

    // 100% Deterministic start timestamp at 25% of total video duration for exact frame sync across Phase 1, 2, and 3
    double startSec = 0.0;
    if (totalDurationSec > targetDurationSec + 2.0) {
      startSec = totalDurationSec * 0.25;
    }

    debugPrint('[PreviewService] Selected deterministic start timestamp: ${startSec.toStringAsFixed(2)}s (Target duration: ${targetDurationSec}s)');

    final args = <String>[
      '-ss', startSec.toStringAsFixed(3),
      '-i', videoPath,
      '-t', targetDurationSec.toStringAsFixed(3),
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      ...profile.toFfmpegArgs(),
      '-an',
      '-y',
      outputPath,
    ];

    debugPrint('[PreviewService] Executing FFmpeg keyframe extraction with detected color profile: ${args.join(" ")}');

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
        debugPrint('[PreviewService] FFmpeg extraction warning: exitCode=${result.exitCode}, stderr=${result.stderr}');
      }
    } catch (e) {
      debugPrint('[PreviewService] FFmpeg extraction exception: $e');
    }

    return videoPath;
  }

  /// Clears the in-memory snippet cache.
  static void clearCache() {
    _snippetCache.clear();
    _profileCache.clear();
  }
}
