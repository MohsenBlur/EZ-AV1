import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ez_av1/services/environment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MediaKit.ensureInitialized accepts custom libmpv path from EnvironmentService', () {
    final missing = EnvironmentService.init();
    expect(missing, isEmpty);

    final mpvPath = EnvironmentService.mpvLibraryPath;
    expect(mpvPath, isNotEmpty);

    // Call MediaKit.ensureInitialized with explicit libmpv path
    MediaKit.ensureInitialized(libmpv: mpvPath);
    debugPrint('MediaKit initialized with custom libmpv path: $mpvPath');
  });
}
