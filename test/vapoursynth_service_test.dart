import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_av1/services/vapoursynth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VapourSynthService', () {
    test('generateDenoiseScript creates script with CPU fallback and text overlay on exception', () async {
      final scriptPath = await VapourSynthService.generateDenoiseScript(3.5);
      final file = File(scriptPath);

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('import vapoursynth as vs'));
      expect(content, contains('KNLMeansCL(clip, d=1, a=2, s=4, h=1.75, channels="Y")'));
      expect(content, contains('core.std.Convolution'));
      expect(content, contains('GPU Denoise Fallback'));
      expect(content, contains('denoised.set_output()'));

      // Clean up temp file
      if (file.existsSync()) file.deleteSync();
    });
  });
}
