import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VapourSynthService {
  /// Generates a temporary .vpy script for the given video and denoise strength.
  /// Returns the absolute path to the generated script.
  static Future<String> generateDenoiseScript(double denoiseStrength) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final scriptPath = p.join(tempDir.path, 'ez_av1_preview.vpy');
    final file = File(scriptPath);

    // Build the script content for mpv vf=vapoursynth
    final sb = StringBuffer();
    sb.writeln('import vapoursynth as vs');
    sb.writeln('core = vs.core');
    sb.writeln('');
    sb.writeln('clip = video_in');
    
    if (denoiseStrength > 0) {
      // The 'h' parameter in KNLMeansCL correlates to denoise strength
      final hVal = denoiseStrength.toStringAsFixed(2);
      final sigmaRVal = (denoiseStrength / 10.0).clamp(0.1, 10.0).toStringAsFixed(2);

      sb.writeln('try:');
      sb.writeln('    clip = core.knlm.KNLMeansCL(clip, a=1, h=$hVal, d=1, device_type="auto")');
      sb.writeln('except Exception as e:');
      sb.writeln('    try:');
      sb.writeln('        # Fallback to built-in CPU Bilateral filter if GPU KNLMeansCL is unavailable');
      sb.writeln('        clip = core.std.Bilateral(clip, sigmaS=3.0, sigmaR=$sigmaRVal)');
      sb.writeln('        clip = core.text.Text(clip, f"GPU Denoise Warning: KNLMeansCL failed ({e}). Using CPU Bilateral fallback.", alignment=7)');
      sb.writeln('    except Exception as e2:');
      sb.writeln('        clip = core.text.Text(clip, f"Denoise Filter Error: {e}", alignment=7)');
    }
    
    sb.writeln('clip.set_output()');

    await file.writeAsString(sb.toString());
    return scriptPath;
  }
}
