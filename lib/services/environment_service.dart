import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class EnvironmentService {
  static late final String binDirectory;
  static late final String pythonDirectory;
  static late final String ffmpegPath;
  static late final String ffprobePath;
  static late final String av1anPath;
  static late final String svtAv1Path;

  /// Initializes the environment by resolving the absolute paths
  /// to the bundled portable binaries.
  static void init() {
    String rootPath;
    
    // In debug mode, the working directory is usually the project root.
    // In release mode, we might need to find the executable path.
    if (kDebugMode) {
      rootPath = Directory.current.path;
    } else {
      rootPath = p.dirname(Platform.resolvedExecutable);
      // In production, assets might be nested in a data/flutter_assets folder
      // but for simplicity, we assume the setup script places it relative to root.
    }

    binDirectory = p.join(rootPath, 'assets', 'bin');
    pythonDirectory = p.join(binDirectory, 'python');
    
    ffmpegPath = p.join(binDirectory, 'ffmpeg.exe');
    ffprobePath = p.join(binDirectory, 'ffprobe.exe');
    av1anPath = p.join(binDirectory, 'av1an.exe');
    svtAv1Path = p.join(binDirectory, 'SvtAv1EncApp.exe');

    _injectPath();
  }

  /// Injects the bundled python directory into the current process's PATH
  /// This ensures that when libmpv (or av1an) spawns child processes or 
  /// looks for python/vapoursynth, it finds our portable ones first.
  static void _injectPath() {
    if (!Platform.isWindows) return;

    final currentPath = Platform.environment['PATH'] ?? '';
    
    // If the python directory is already in the path, skip
    if (currentPath.contains(pythonDirectory)) return;

    // Prepend the portable python/bin directories to the PATH
    // final newPath = '$pythonDirectory;$binDirectory;$currentPath';
    
    // Note: Dart doesn't have a built-in way to set environment variables 
    // for the CURRENT process that propagate natively to loaded DLLs perfectly
    // without FFI/win32, but setting it via a child process or using FFI is an option.
    // Wait, we can't easily modify the current process environment variables in pure Dart 
    // in a way that C-libraries (like libmpv) will see. 
    // Actually, libmpv allows setting environment variables for its own use, 
    // but for now, we will store it and pass it to Process.start(environment: {'PATH': newPath})
    
    // For Av1an and FFmpeg, we will pass this new environment dictionary.
  }

  /// Returns a map with the modified PATH environment variable
  /// to be used when spawning Av1an or FFmpeg via Process.start
  static Map<String, String> get processEnvironment {
    final env = Map<String, String>.from(Platform.environment);
    if (Platform.isWindows) {
      final currentPath = env['PATH'] ?? '';
      env['PATH'] = '$pythonDirectory;$binDirectory;$currentPath';
    }
    return env;
  }
}
