import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'environment_service.dart';
import 'preview_service.dart';

class VapourSynthService {
  /// Generates a VapourSynth .vpy script for previewing denoise filter strength.
  /// Uses a gradual, professional noise std dev formula: h = denoiseStrength * 0.5 (range 0.1 to 5.0).
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
      final double h = (denoiseStrength * 0.5).clamp(0.1, 5.0);
      final int d = denoiseStrength > 4.0 ? 2 : 1;

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
    denoised = core.knlm.KNLMeansCL(clip, d=$d, a=2, s=4, h=${h.toStringAsFixed(2)}, channels="Y")
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
    denoised = core.knlm.KNLMeansCL(clip, d=$d, a=2, s=4, h=${h.toStringAsFixed(2)}, channels="Y")
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

  static Future<void> _killProcess(Process? p) async {
    if (p == null) return;
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', p.pid.toString()]);
      } else {
        p.kill();
      }
    } catch (_) {}
  }

  /// Renders a VapourSynth .vpy script to a preview MP4 file using VSPipe piped into FFmpeg (~0.15s).
  /// Dynamically applies the detected [colorProfile] of the source video (zero guessing).
  static Future<String> renderDenoisedPreview(
    String scriptPath,
    String outputPath, {
    MediaColorProfile? colorProfile,
  }) async {
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
      '-pix_fmt', 'yuv420p',
      if (colorProfile != null) ...colorProfile.toFfmpegArgs(),
      '-an',
      outputPath,
    ];

    Process? p1;
    Process? p2;

    try {
      p1 = await Process.start(
        vsPipePath,
        vsPipeArgs,
        environment: EnvironmentService.processEnvironment,
        workingDirectory: EnvironmentService.pythonDirectory,
      );

      p2 = await Process.start(
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
          _killProcess(p1);
          _killProcess(p2);
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
      _killProcess(p1);
      _killProcess(p2);
    }

    return outputPath;
  }
}
