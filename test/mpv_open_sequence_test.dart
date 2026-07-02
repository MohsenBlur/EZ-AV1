import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ez_av1/services/environment_service.dart';

typedef MpvCreateC = Pointer<Void> Function();
typedef MpvCreateDart = Pointer<Void> Function();

typedef MpvInitializeC = Int32 Function(Pointer<Void>);
typedef MpvInitializeDart = int Function(Pointer<Void>);

typedef MpvSetOptionStringC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef MpvSetOptionStringDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Setting hwdec=no and vf=vapoursynth BEFORE loadfile succeeds in mpv', () {
    final missing = EnvironmentService.init();
    expect(missing, isEmpty);

    final binDir = EnvironmentService.binDirectory;
    final mpvPath = p.join(binDir, 'mpv-2.dll');

    final mpvLib = DynamicLibrary.open(mpvPath);
    final mpvCreate = mpvLib.lookupFunction<MpvCreateC, MpvCreateDart>('mpv_create');
    final mpvInit = mpvLib.lookupFunction<MpvInitializeC, MpvInitializeDart>('mpv_initialize');
    final mpvSetOptString = mpvLib.lookupFunction<MpvSetOptionStringC, MpvSetOptionStringDart>('mpv_set_option_string');

    final handle = mpvCreate();
    expect(handle, isNot(equals(nullptr)));

    // 1. Set hwdec to no BEFORE mpv_initialize / loadfile
    final hwdecNamePtr = 'hwdec'.toNativeUtf8();
    final hwdecValPtr = 'no'.toNativeUtf8();
    final hwdecRes = mpvSetOptString(handle, hwdecNamePtr, hwdecValPtr);
    calloc.free(hwdecNamePtr);
    calloc.free(hwdecValPtr);
    expect(hwdecRes, equals(0));

    // 2. Initialize mpv
    final initRes = mpvInit(handle);
    expect(initRes, equals(0));

    // 3. Set vf=vapoursynth BEFORE loadfile
    final scriptFile = p.join(Directory.systemTemp.path, 'ez_seq_test.vpy');
    File(scriptFile).writeAsStringSync('import vapoursynth as vs\ncore = vs.core\nclip = video_in\nclip.set_output()\n');
    final escapedPath = scriptFile.replaceAll('\\', '/');

    final vfNamePtr = 'vf'.toNativeUtf8();
    final vfValPtr = 'vapoursynth="$escapedPath"'.toNativeUtf8();
    final setVfRes = mpvSetOptString(handle, vfNamePtr, vfValPtr);
    calloc.free(vfNamePtr);
    calloc.free(vfValPtr);
    expect(setVfRes, equals(0));

    debugPrint('hwdec=no and vf=vapoursynth set successfully prior to loadfile!');
  });
}
