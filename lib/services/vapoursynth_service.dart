import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VapourSynthService {
  /// Generates a temporary .vpy script for the given video and denoise strength.
  /// Returns the absolute path to the generated script.
  static Future<String> generateDenoiseScript(double denoiseStrength) async {
    final tempDir = await getTemporaryDirectory();
    final scriptPath = p.join(tempDir.path, 'ez_av1_preview.vpy');
    final file = File(scriptPath);

    // Build the script content for mpv vf=vapoursynth
    final sb = StringBuffer();
    sb.writeln('import vapoursynth as vs');
    sb.writeln('core = vs.core');
    sb.writeln('');
    sb.writeln('clip = video_in');
    
    if (denoiseStrength > 0) {
      // The 'h' parameter in KNLMeansCL roughly correlates to denoise strength
      sb.writeln('try:');
      sb.writeln('    clip = core.knlm.KNLMeansCL(clip, a=1, h=$denoiseStrength, d=1, device_type="auto")');
      sb.writeln('except Exception as e:');
      sb.writeln('    pass # Fallback to original clip if KNLMeansCL fails');
    }
    
    sb.writeln('clip.set_output()');

    await file.writeAsString(sb.toString());
    return scriptPath;
  }
}
