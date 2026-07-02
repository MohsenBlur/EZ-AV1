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
  static String binDirectory = '';
  static String pythonDirectory = '';
  static String ffmpegPath = '';
  static String ffprobePath = '';
  static String av1anPath = '';
  static String svtAv1Path = '';

  /// Resolves portable binary paths and returns a list of missing required files.
  static List<String> getMissingBinaries() {
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

    final requiredBinaries = [
      ffmpegPath,
      ffprobePath,
      av1anPath,
      svtAv1Path,
      p.join(binDirectory, 'mpv-2.dll'),
      p.join(pythonDirectory, 'vapoursynth.dll'),
    ];

    final missing = <String>[];
    for (final path in requiredBinaries) {
      if (!File(path).existsSync()) {
        missing.add(p.basename(path));
      }
    }

    return missing;
  }

  /// Initializes environment paths. Returns a list of missing components if any.
  static List<String> init() {
    final missing = getMissingBinaries();
    if (missing.isEmpty) {
      _injectPath();
    }
    return missing;
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
    
    // Specifically tell mpv where VSScript.dll is, otherwise it disables the vf=vapoursynth filter!
    final vsScriptPath = p.join(pythonDirectory, 'VSScript.dll');
    NativePathHelper.setEnvVar('VSSCRIPT_PATH', vsScriptPath);
    
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
