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

  /// Returns the absolute path to the VapourSynth-enabled mpv-2.dll library
  static String get mpvLibraryPath {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final exeMpv = p.join(exeDir, 'mpv-2.dll');
    if (File(exeMpv).existsSync() && File(exeMpv).lengthSync() > 100000000) {
      return exeMpv;
    }
    return p.join(binDirectory, 'mpv-2.dll');
  }

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

  /// Initializes environment paths, pre-loads DLLs, and syncs core DLLs to executable folder.
  /// Returns a list of missing components if any.
  static List<String> init() {
    final missing = getMissingBinaries();
    if (missing.isEmpty) {
      _injectPath();
      _syncBinariesToExeDir();
      _preloadVapourSynthDLLs();
    }
    return missing;
  }

  /// Injects the bundled python and bin directories into process PATH, DLL search path,
  /// and sets VSSCRIPT_PATH for libmpv using both Win32 and C runtime API.
  static void _injectPath() {
    if (!Platform.isWindows) return;

    NativePathHelper.prependToPath(binDirectory);
    NativePathHelper.prependToPath(pythonDirectory);
    
    NativePathHelper.setDllDirectory(pythonDirectory);
    NativePathHelper.setDllDirectory(binDirectory);

    final vsScriptPath = p.join(pythonDirectory, 'VSScript.dll');
    NativePathHelper.setEnvVar('VSSCRIPT_PATH', vsScriptPath);
    NativePathHelper.setEnvVar('PYTHONHOME', pythonDirectory);
    NativePathHelper.setEnvVar('PYTHONPATH', pythonDirectory);
  }

  /// Copies VapourSynth DLL dependencies and plugins to the target executable directory
  static void _syncBinariesToExeDir() {
    if (!Platform.isWindows) return;
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      if (exeDir == binDirectory || exeDir == pythonDirectory || exeDir.isEmpty) return;

      final filesToSync = [
        'VSScript.dll',
        'VapourSynth.dll',
        'python311.dll',
        'python311.zip',
        'python311._pth',
        'KNLMeansCL.dll',
        'mpv-2.dll',
      ];

      for (final filename in filesToSync) {
        final src = File(p.join(pythonDirectory, filename));
        final altSrc = File(p.join(binDirectory, filename));
        final target = File(p.join(exeDir, filename));

        final sourceFile = src.existsSync() ? src : (altSrc.existsSync() ? altSrc : null);
        if (sourceFile != null) {
          if (!target.existsSync() || target.lengthSync() != sourceFile.lengthSync()) {
            sourceFile.copySync(target.path);
            debugPrint('Synced $filename to executable directory: ${target.path}');
          }
        }
      }

      // Sync vapoursynth64 plugins directory (including LSMASHSource.dll)
      final vsPluginsSrc = Directory(p.join(pythonDirectory, 'vapoursynth64', 'plugins'));
      final vsPluginsTarget = Directory(p.join(exeDir, 'vapoursynth64', 'plugins'));
      if (vsPluginsSrc.existsSync()) {
        vsPluginsTarget.createSync(recursive: true);
        for (final entity in vsPluginsSrc.listSync()) {
          if (entity is File) {
            final targetFile = File(p.join(vsPluginsTarget.path, p.basename(entity.path)));
            if (!targetFile.existsSync() || targetFile.lengthSync() != entity.lengthSync()) {
              entity.copySync(targetFile.path);
              debugPrint('Synced plugin ${p.basename(entity.path)} to executable plugins dir: ${targetFile.path}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Warning syncing binaries to executable dir: $e');
    }
  }

  /// Pre-loads python311.dll, VapourSynth.dll, and VSScript.dll into process address space.
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
