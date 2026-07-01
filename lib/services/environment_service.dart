import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'native_path_helper.dart';

class EnvironmentException implements Exception {
  final String message;
  EnvironmentException(this.message);
  @override
  String toString() => 'EnvironmentException: $message';
}

class EnvironmentService {
  static late final String binDirectory;
  static late final String pythonDirectory;
  static late final String ffmpegPath;
  static late final String ffprobePath;
  static late final String av1anPath;
  static late final String svtAv1Path;

  /// Initializes the environment by resolving the absolute paths
  /// to the bundled portable binaries. Throws EnvironmentException if missing.
  static void init() {
    String rootPath;
    
    if (kDebugMode) {
      rootPath = Directory.current.path;
    } else {
      rootPath = p.dirname(Platform.resolvedExecutable);
    }

    binDirectory = p.join(rootPath, 'assets', 'bin');
    pythonDirectory = p.join(binDirectory, 'python');
    
    ffmpegPath = p.join(binDirectory, 'ffmpeg.exe');
    ffprobePath = p.join(binDirectory, 'ffprobe.exe');
    av1anPath = p.join(binDirectory, 'av1an.exe');
    svtAv1Path = p.join(binDirectory, 'SvtAv1EncApp.exe');

    // Physical File Validation
    final requiredBinaries = [
      ffmpegPath,
      ffprobePath,
      av1anPath,
      svtAv1Path,
      p.join(binDirectory, 'mpv-2.dll'),
      p.join(binDirectory, 'vapoursynth.dll'),
    ];

    for (final path in requiredBinaries) {
      if (!File(path).existsSync()) {
        throw EnvironmentException('Missing critical component: ${p.basename(path)}');
      }
    }

    _injectPath();
  }

  /// Injects the bundled python directory into the current process's PATH
  /// This ensures that when libmpv (or av1an) spawns child processes or 
  /// looks for python/vapoursynth, it finds our portable ones first.
  static void _injectPath() {
    if (!Platform.isWindows) return;

    final currentPath = Platform.environment['PATH'] ?? '';
    
    if (currentPath.contains(pythonDirectory)) return;

    // Use FFI to actually mutate the C-runtime environment variable
    // so that when Windows calls LoadLibrary('mpv-2.dll'), it will 
    // find 'vapoursynth.dll' and 'python310.dll' lying around or in pythonDirectory.
    NativePathHelper.prependToPath(binDirectory);
    NativePathHelper.prependToPath(pythonDirectory);
    
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
