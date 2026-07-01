import 'package:flutter_test/flutter_test.dart';
import 'package:ez_av1/models/preset_model.dart';
import 'package:ez_av1/services/av1an_service.dart';

void main() {
  group('Av1anService', () {
    test('calculatePhotonNoise handles bounds and mapping correctly', () {
      expect(Av1anService.calculatePhotonNoise(0.0), 0);
      expect(Av1anService.calculatePhotonNoise(1.0), 3); // 1.0 * 2.5 = 2.5 -> round to 3
      expect(Av1anService.calculatePhotonNoise(10.0), 25);
      expect(Av1anService.calculatePhotonNoise(100.0), 50); // clamped to 50
    });

    test('buildArgs generates correct CLI arguments without double quotes', () {
      const preset = PresetModel(
        id: 'test_preset',
        name: 'Test',
        denoiseStrength: 4.0, // photon noise should be 10
        targetVmaf: 95.0,
        audioBitrate: 128,
        downmixToStereo: true,
      );

      final args = Av1anService.buildArgs(
        sourceVideo: r'C:\My Videos\test.mkv',
        outputVideo: r'C:\My Videos\test_av1.mkv',
        preset: preset,
        workers: 1,
      );

      expect(args.contains('-i'), isTrue);
      expect(args.contains(r'C:\My Videos\test.mkv'), isTrue);
      expect(args.contains('-o'), isTrue);
      expect(args.contains(r'C:\My Videos\test_av1.mkv'), isTrue);
      
      // Check video parameters
      final vIndex = args.indexOf('-v');
      expect(vIndex, greaterThan(-1));
      final videoParams = args[vIndex + 1];
      expect(videoParams.contains('--target-quality 95.0'), isTrue);
      expect(videoParams.contains('--film-grain 10'), isTrue);

      // Check audio parameters
      final fIndex = args.indexOf('-f');
      expect(fIndex, greaterThan(-1));
      final audioParams = args[fIndex + 1];
      expect(audioParams.contains('-c:a libopus'), isTrue);
      expect(audioParams.contains('-b:a 128k'), isTrue);
      expect(audioParams.contains('-ac 2'), isTrue);

      // Check workers
      expect(args.contains('--workers'), isTrue);
      expect(args.contains('1'), isTrue);
    });
  });
}
