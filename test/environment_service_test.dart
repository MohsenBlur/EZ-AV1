import 'package:flutter_test/flutter_test.dart';
import 'package:ez_av1/services/environment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnvironmentService', () {
    test('getMissingBinaries returns list of missing files without throwing', () {
      final missing = EnvironmentService.getMissingBinaries();
      expect(missing, isA<List<String>>());
    });

    test('init returns missing binaries list safely', () {
      final missing = EnvironmentService.init();
      expect(missing, isA<List<String>>());
    });
  });
}
