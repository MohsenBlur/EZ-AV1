import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'environment_service.dart';

class FfprobeService {
  /// Probes a video file and returns the number of audio channels.
  /// If it fails or no audio is found, returns 2 (Stereo) as a safe fallback.
  static Future<int> getAudioChannelCount(String videoPath) async {
    try {
      final result = await Process.run(
        EnvironmentService.ffprobePath,
        [
          '-v', 'error',
          '-select_streams', 'a:0',
          '-show_entries', 'stream=channels',
          '-of', 'json',
          videoPath,
        ],
        environment: EnvironmentService.processEnvironment,
      );

      if (result.exitCode == 0) {
        final jsonResult = jsonDecode(result.stdout as String);
        final streams = jsonResult['streams'] as List<dynamic>?;
        
        if (streams != null && streams.isNotEmpty) {
          final channels = streams[0]['channels'] as int?;
          if (channels != null) return channels;
        }
      }
    } catch (e) {
      // Log error (for production, use a proper logger)
      debugPrint('FFprobe error: $e');
    }
    
    // Default fallback
    return 2;
  }
}
