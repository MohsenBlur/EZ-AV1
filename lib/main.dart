import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'services/environment_service.dart';
import 'ui/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  List<String> missing = [];
  try {
    missing = EnvironmentService.init();
  } catch (e) {
    missing = ['Environment error: $e'];
  }

  // Initialize media_kit for native video playback
  MediaKit.ensureInitialized();

  runApp(ProviderScope(child: EzAv1App(missingComponents: missing)));
}

class EzAv1App extends StatefulWidget {
  final List<String> missingComponents;
  const EzAv1App({super.key, this.missingComponents = const []});

  @override
  State<EzAv1App> createState() => _EzAv1AppState();
}

class _EzAv1AppState extends State<EzAv1App> {
  late List<String> _missingComponents;

  @override
  void initState() {
    super.initState();
    _missingComponents = List.from(widget.missingComponents);
  }

  void _retryDiagnostics() {
    try {
      final missing = EnvironmentService.init();
      setState(() {
        _missingComponents = missing;
      });
    } catch (e) {
      setState(() {
        _missingComponents = ['Initialization error: $e'];
      });
    }
  }

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
      home: _missingComponents.isEmpty
          ? const AppShell()
          : EnvironmentDiagnosticScreen(
              missingComponents: _missingComponents,
              onRetry: _retryDiagnostics,
            ),
    );
  }
}

class EnvironmentDiagnosticScreen extends StatelessWidget {
  final List<String> missingComponents;
  final VoidCallback onRetry;

  const EnvironmentDiagnosticScreen({
    super.key,
    required this.missingComponents,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Missing Dependencies',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'EZ-AV1 requires bundled portable binaries to function. The following component(s) were not found:',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: missingComponents
                          .map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                    const SizedBox(width: 8),
                                    Text(item, style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace')),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Please run setup_deps.ps1 in PowerShell to automatically download and extract the required binaries into assets/bin.',
                    style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Re-check Dependencies'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
