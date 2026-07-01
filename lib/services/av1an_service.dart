import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/preset_model.dart';
import 'environment_service.dart';

class Av1anService {
  /// Converts Phase 1 denoise strength into Phase 2 photon-noise (synthetic grain).
  /// This is the "Predictive Inversion" logic.
  static int calculatePhotonNoise(double denoiseStrength) {
    // If there is no denoising, there should be no synthetic grain applied.
    if (denoiseStrength <= 0) return 0;
    
    // Scale denoise strength (e.g. 1.0 - 10.0) to photon noise (e.g. 1 - 50)
    // For AV1, photon noise is typically best between 1 and 20 for most content.
    // This is a basic linear map; could be tweaked based on testing.
    final noise = (denoiseStrength * 2.5).round();
    return noise.clamp(0, 50);
  }

  /// Builds the Av1an CLI arguments based on the preset and source video.
  static List<String> buildArgs({
    required String sourceVideo,
    required String outputVideo,
    required PresetModel preset,
    bool isChunkTest = false,
  }) {
    final args = <String>[];
    
    // Properly quote input path to avoid shell escaping issues
    args.addAll(['-i', '"$sourceVideo"']);
    
    // SVT-AV1 encoder flags
    final photonNoise = calculatePhotonNoise(preset.denoiseStrength);
    
    final videoParams = [
      '--preset', '4', // Good balance for SVT-AV1
      // EXPERT POLISH: Av1an handles VMAF targeting natively via --target-quality, NOT --crf.
      '--target-quality', '${preset.targetVmaf}', 
    ];

    if (photonNoise > 0) {
      videoParams.addAll(['--film-grain', '$photonNoise', '--film-grain-denoise', '0']);
    }

    args.add('-v');
    // For Av1an, we pass encoder parameters as a single quoted string to the -v flag
    args.add('"${videoParams.join(' ')}"');

    // Audio / Metadata flags
    final audioFlags = <String>['-c:s', 'copy', '-c:a', 'libopus', '-b:a', '${preset.audioBitrate}k'];
    if (preset.downmixToStereo) {
      audioFlags.addAll(['-ac', '2']);
    }
    
    args.add('-f');
    args.add('"${audioFlags.join(' ')}"');

    // Optional Av1an features
    args.addAll(['--resume', '--split-method', 'pyscenedetect']);

    // Output
    args.addAll(['-o', '"$outputVideo"']);

    return args;
  }

  /// Generates a test chunk (e.g. 5 seconds) for Phase 2 quad-split.
  /// Returns the Process running the Av1an encode.
  static Future<Process> generateTestChunk({
    required String sourceVideo,
    required String outputDir,
    required PresetModel preset,
  }) async {
    final outputVideo = p.join(outputDir, '${const Uuid().v4()}.mkv');
    
    final args = buildArgs(
      sourceVideo: sourceVideo,
      outputVideo: outputVideo,
      preset: preset,
      isChunkTest: true,
    );
    
    // In a test chunk scenario, we'd normally cut the video first or pass a time flag.
    // For simplicity, we assume sourceVideo is already a 5-second chunk.
    
    return Process.start(
      EnvironmentService.av1anPath,
      args,
      environment: EnvironmentService.processEnvironment,
    );
  }
}
