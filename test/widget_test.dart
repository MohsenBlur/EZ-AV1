import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ez_av1/main.dart';

void main() {
  testWidgets('EzAv1App renders EnvironmentDiagnosticScreen when dependencies are missing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EzAv1App(missingComponents: ['ffmpeg.exe', 'mpv-2.dll']),
      ),
    );

    expect(find.text('Missing Dependencies'), findsOneWidget);
    expect(find.text('ffmpeg.exe'), findsOneWidget);
    expect(find.text('mpv-2.dll'), findsOneWidget);
  });
}
