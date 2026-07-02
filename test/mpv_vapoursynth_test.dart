import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ez_av1/services/environment_service.dart';

typedef SetDllDirectoryC = Int32 Function(Pointer<Utf16> lpPathName);
typedef SetDllDirectoryDart = int Function(Pointer<Utf16> lpPathName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mpv-2.dll recognizes vf=vapoursynth option when VSScript dependencies are pre-loaded', () {
    final missing = EnvironmentService.init();
    expect(missing, isEmpty, reason: 'Portable binaries must be present for this test');

    final pythonDir = EnvironmentService.pythonDirectory;
    final binDir = EnvironmentService.binDirectory;
    final mpvPath = p.join(binDir, 'mpv-2.dll');

    // Win32 SetDllDirectoryW call
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final setDllDir = kernel32.lookupFunction<SetDllDirectoryC, SetDllDirectoryDart>('SetDllDirectoryW');

    final pythonDirPtr = pythonDir.toNativeUtf16();
    setDllDir(pythonDirPtr);
    calloc.free(pythonDirPtr);

    // Pre-load VapourSynth DLL dependencies into process memory
    try {
      DynamicLibrary.open(p.join(pythonDir, 'python311.dll'));
      DynamicLibrary.open(p.join(pythonDir, 'VapourSynth.dll'));
      DynamicLibrary.open(p.join(pythonDir, 'VSScript.dll'));
      debugPrint('Pre-loaded VapourSynth DLLs successfully!');
    } catch (e) {
      debugPrint('Failed to pre-load DLLs: $e');
    }

    // Open mpv-2.dll
    final mpvLib = DynamicLibrary.open(mpvPath);
    final mpvCreate = mpvLib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>('mpv_create');
    final mpvInit = mpvLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('mpv_initialize');
    final mpvSetOptString = mpvLib.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>),
        int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)
    >('mpv_set_option_string');
    final mpvErrorString = mpvLib.lookupFunction<Pointer<Utf8> Function(Int32), Pointer<Utf8> Function(int)>('mpv_error_string');

    final handle = mpvCreate();
    final initRes = mpvInit(handle);
    expect(initRes, equals(0));

    final scriptFile = p.join(Directory.systemTemp.path, 'ez_test.vpy');
    File(scriptFile).writeAsStringSync('import vapoursynth as vs\ncore = vs.core\nclip = video_in\nclip.set_output()\n');
    final escapedPath = scriptFile.replaceAll('\\', '/');

    final vfNamePtr = 'vf'.toNativeUtf8();
    final vfValPtr = 'vapoursynth="$escapedPath"'.toNativeUtf8();

    final setOptRes = mpvSetOptString(handle, vfNamePtr, vfValPtr);
    final errorMsg = mpvErrorString(setOptRes).toDartString();

    debugPrint('mpv_set_option_string vf=vapoursynth result code: $setOptRes ($errorMsg)');

    calloc.free(vfNamePtr);
    calloc.free(vfValPtr);

    expect(setOptRes, equals(0), reason: 'mpv must accept vf=vapoursynth without error');
  });
}
