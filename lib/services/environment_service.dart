import 'dart:ffi';
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

  /// Initializes environment paths and pre-loads VapourSynth DLL dependencies.
  /// Returns a list of missing components if any.
  static List<String> init() {
    final missing = getMissingBinaries();
    if (missing.isEmpty) {
      _injectPath();
      _preloadVapourSynthDLLs();
    }
    return missing;
  }

  /// Injects the bundled python and bin directories into process PATH, DLL search path,
  /// and sets VSSCRIPT_PATH for libmpv.
  static void _injectPath() {
    if (!Platform.isWindows) return;

    // Use Win32 FFI to mutate process PATH and DLL search order
    NativePathHelper.prependToPath(binDirectory);
    NativePathHelper.prependToPath(pythonDirectory);
    
    // Set Win32 DLL Search Directory so Windows OS Loader finds python311.dll & VapourSynth.dll
    NativePathHelper.setDllDirectory(pythonDirectory);
    NativePathHelper.setDllDirectory(binDirectory);

    // Tell mpv where VSScript.dll is
    final vsScriptPath = p.join(pythonDirectory, 'VSScript.dll');
    NativePathHelper.setEnvVar('VSSCRIPT_PATH', vsScriptPath);
    NativePathHelper.setEnvVar('PYTHONHOME', pythonDirectory);
    NativePathHelper.setEnvVar('PYTHONPATH', pythonDirectory);
  }

  /// Pre-loads python311.dll, VapourSynth.dll, and VSScript.dll into process address space.
  /// When libmpv runs LoadLibrary('VSScript.dll'), Windows will find them already loaded,
  /// enabling vf=vapoursynth without 'Option vf: vapoursynth doesn't exist' errors.
  static void _preloadVapourSynthDLLs() {
    if (!Platform.isWindows) return;

    try {
      final python311 = p.join(pythonDirectory, 'python311.dll');
      final vapourSynth = p.join(pythonDirectory, 'VapourSynth.dll');
      final vsScript = p.join(pythonDirectory, 'VSScript.dll');

      if (File(python311).existsSync()) DynamicLibrary.open(python311);
      if (File(vapourSynth).existsSync()) DynamicLibrary.open(vapourSynth);
      if (File(vsScript).existsSync()) DynamicLibrary.open(vsScript);

      debugPrint('VapourSynth DLL dependencies pre-loaded successfully.');
    } catch (e) {
      debugPrint('VapourSynth DLL pre-load warning: $e');
    }
  }

  /// Returns a map with the modified PATH environment variable
  /// to be used when spawning Av1an or FFmpeg via Process.start
  static Map<String, String> get processEnvironment {
    final env = Map<String, String>.from(Platform.environment);
    if (Platform.isWindows) {
      final currentPath = env['PATH'] ?? '';
      env['PATH'] = '$pythonDirectory;$binDirectory;$currentPath';
      env['VSSCRIPT_PATH'] = p.join(pythonDirectory, 'VSScript.dll');
      env['PYTHONHOME'] = pythonDirectory;
      env['PYTHONPATH'] = pythonDirectory;
    }
    return env;
  }
}
