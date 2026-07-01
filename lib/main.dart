import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'services/environment_service.dart';
import 'ui/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize paths and portable binaries before anything else
  EnvironmentService.init();

  // Initialize media_kit for native video playback
  MediaKit.ensureInitialized();

  runApp(const ProviderScope(child: EzAv1App()));
}

class EzAv1App extends StatelessWidget {
  const EzAv1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EZ-AV1',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181818),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF39C12), // Subtle orange highlight
          surface: Color(0xFF222222),
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
