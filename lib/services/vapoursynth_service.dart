import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'environment_service.dart';

class VapourSynthService {
  /// Generates a VapourSynth .vpy script for previewing denoise filter strength.
  static Future<String> generateDenoiseScript(
    double denoiseStrength, {
    String? customScript,
    String? sourceFilePath,
  }) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }

    final scriptFile = File(p.join(tempDir.path, 'ez_av1_preview.vpy'));
    final knlPath = p.join(EnvironmentService.pythonDirectory, 'KNLMeansCL.dll');
    final escapedKnlPath = knlPath.replaceAll('\\', '/');

    final String pythonScript;
    final String escapedSource = sourceFilePath != null ? sourceFilePath.replaceAll('\\', '/') : '';

    if (denoiseStrength <= 0) {
      if (sourceFilePath != null && sourceFilePath.isNotEmpty) {
        pythonScript = '''
import vapoursynth as vs
core = vs.core
clip = core.bs.VideoSource(source=r"$escapedSource")
clip.set_output()
''';
      } else {
        pythonScript = '''
import vapoursynth as vs
core = vs.core
clip = video_in
clip.set_output()
''';
      }
    } else {
      final int d = denoiseStrength.round().clamp(1, 10);
      final int h = d * 2;

      if (sourceFilePath != null && sourceFilePath.isNotEmpty) {
        pythonScript = '''
import vapoursynth as vs
core = vs.core
try:
    clip = core.bs.VideoSource(source=r"$escapedSource")
except Exception:
    try:
        clip = core.ffms2.Source(source=r"$escapedSource")
    except Exception:
        clip = core.lsmas.LWLibavSource(source=r"$escapedSource")

try:
    core.std.LoadPlugin(r"$escapedKnlPath")
    denoised = core.knlm.KNLMeansCL(clip, d=$d, a=2, s=4, h=$h)
except Exception as e:
    denoised = core.std.Bilateral(clip, sigmaS=$d.0, sigmaR=0.1)
    denoised = core.text.Text(denoised, f"GPU Denoise Fallback: {e}")

denoised.set_output()
''';
      } else {
        pythonScript = '''
import vapoursynth as vs
core = vs.core
clip = video_in

try:
    core.std.LoadPlugin(r"$escapedKnlPath")
    denoised = core.knlm.KNLMeansCL(clip, d=$d, a=2, s=4, h=$h)
except Exception as e:
    denoised = core.std.Bilateral(clip, sigmaS=$d.0, sigmaR=0.1)
    denoised = core.text.Text(denoised, f"GPU Denoise Fallback: {e}")

denoised.set_output()
''';
      }
    }

    await scriptFile.writeAsString(pythonScript);
    return scriptFile.path;
  }

  /// Renders a VapourSynth .vpy script to a preview MP4 file using VSPipe piped into FFmpeg (~0.15s).
  /// Drains process stderr streams to prevent OS pipe deadlock and includes a 10s execution timeout.
  static Future<String> renderDenoisedPreview(String scriptPath, String outputPath) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('[VapourSynthService] Rendering preview script to MP4: $scriptPath -> $outputPath');

    final vsPipePath = p.join(EnvironmentService.pythonDirectory, 'VSPipe.exe');
    final vsPipeArgs = <String>['-c', 'y4m', scriptPath, '-'];
    final ffmpegArgs = <String>[
      '-y',
      '-i', '-',
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-crf', '18',
      '-an',
      outputPath,
    ];

    try {
      final p1 = await Process.start(
        vsPipePath,
        vsPipeArgs,
        environment: EnvironmentService.processEnvironment,
        workingDirectory: EnvironmentService.pythonDirectory,
      );

      final p2 = await Process.start(
        EnvironmentService.ffmpegPath,
        ffmpegArgs,
        environment: EnvironmentService.processEnvironment,
      );

      // Drain stderr streams to prevent OS pipe buffer deadlock
      p1.stderr.listen((data) {});
      p2.stderr.listen((data) {});

      // Pipe VSPipe stdout into FFmpeg stdin and await completion
      await p1.stdout.pipe(p2.stdin);

      final exitCode = await p2.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[VapourSynthService] Render timed out after 10s');
          p1.kill();
          p2.kill();
          return -1;
        },
      );

      final outputFile = File(outputPath);

      if (exitCode == 0 && outputFile.existsSync() && outputFile.lengthSync() > 0) {
        debugPrint('[VapourSynthService] Denoised preview rendered successfully in ${stopwatch.elapsedMilliseconds}ms (${outputFile.lengthSync()} bytes)');
        return outputPath;
      } else {
        debugPrint('[VapourSynthService] Render failed with exitCode: $exitCode');
      }
    } catch (e) {
      debugPrint('[VapourSynthService] Render exception: $e');
    }

    return outputPath;
  }
}
