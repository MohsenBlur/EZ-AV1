import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VapourSynthService {
  /// Generates a temporary .vpy script for the given video and denoise strength.
  /// Returns the absolute path to the generated script.
  static Future<String> generateDenoiseScript(String videoPath, double denoiseStrength) async {
    final tempDir = await getTemporaryDirectory();
    final scriptPath = p.join(tempDir.path, 'ez_av1_preview.vpy');
    final file = File(scriptPath);

    // Normalize path for Python string literals
    final safeVideoPath = videoPath.replaceAll('\\', '/');

    // Build the script content
    // We use KNLMeansCL if denoiseStrength > 0
    final sb = StringBuffer();
    sb.writeln('import vapoursynth as vs');
    sb.writeln('core = vs.core');
    sb.writeln('');
    sb.writeln('clip = core.lsmas.LWLibavSource(source=r"$safeVideoPath")');
    
    if (denoiseStrength > 0) {
      // The 'h' parameter in KNLMeansCL roughly correlates to denoise strength
      // Denoise slider is likely 0 to 10. We map it appropriately.
      // (a is temporal radius, d is spatial radius, h is strength)
      sb.writeln('clip = core.knlm.KNLMeansCL(clip, a=1, h=$denoiseStrength, d=1, device_type="gpu")');
    }
    
    sb.writeln('clip.set_output()');

    await file.writeAsString(sb.toString());
    return scriptPath;
  }
}
