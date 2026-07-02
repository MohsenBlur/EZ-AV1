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
try:
    clip = core.lsmas.LWLibavSource(source=r"$escapedSource")
except Exception:
    try:
        clip = core.bs.VideoSource(source=r"$escapedSource")
    except Exception:
        clip = core.ffms2.Source(source=r"$escapedSource")

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
    clip = core.lsmas.LWLibavSource(source=r"$escapedSource")
except Exception:
    try:
        clip = core.bs.VideoSource(source=r"$escapedSource")
    except Exception:
        clip = core.ffms2.Source(source=r"$escapedSource")

try:
    core.std.LoadPlugin(r"$escapedKnlPath")
    denoised = core.knlm.KNLMeansCL(clip, d=$d, a=2, s=4, h=$h, channels="Y")
except Exception as e:
    denoised = core.std.Convolution(clip, matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1])
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
    denoised = core.knlm.KNLMeansCL(clip, d=$d, a=2, s=4, h=$h, channels="Y")
except Exception as e:
    denoised = core.std.Convolution(clip, matrix=[1, 2, 1, 2, 4, 2, 1, 2, 1])
    denoised = core.text.Text(denoised, f"GPU Denoise Fallback: {e}")

denoised.set_output()
''';
      }
    }

    await scriptFile.writeAsString(pythonScript);
    return scriptFile.path;
  }

  /// Renders a VapourSynth .vpy script to a preview MP4 file using VSPipe piped into FFmpeg (~0.15s).
  /// Enforces BT.709 yuv420p color calibration and drains process stderr streams to prevent deadlocks.
  static Future<String> renderDenoisedPreview(String scriptPath, String outputPath) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('[VapourSynthService] Rendering preview script to MP4: $scriptPath -> $outputPath');

    final vsPipePath = p.join(EnvironmentService.pythonDirectory, 'VSPipe.exe');
    final vsPipeArgs = <String>['-c', 'y4m', scriptPath, '-'];
    final ffmpegArgs = <String>[
      '-y',
      '-i', '-',
      '-vf', 'scale=out_color_matrix=bt709:out_range=limited',
      '-c:v', 'libx264',
      '-pix_fmt', 'yuv420p',
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

      final vsPipeErr = StringBuffer();
      final ffmpegErr = StringBuffer();

      p1.stderr.listen((data) => vsPipeErr.write(String.fromCharCodes(data)));
      p2.stderr.listen((data) => ffmpegErr.write(String.fromCharCodes(data)));

      await p1.stdout.pipe(p2.stdin);

      final exitCode = await p2.exitCode.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[VapourSynthService] Render timed out after 15s');
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
        debugPrint('[VapourSynthService] Render failed with exitCode: $exitCode. VSPipe err: $vsPipeErr, FFmpeg err: $ffmpegErr');
      }
    } catch (e) {
      debugPrint('[VapourSynthService] Render exception: $e');
    }

    return outputPath;
  }
}
