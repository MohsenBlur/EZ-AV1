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

typedef MpvRequestLogMessagesC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef MpvRequestLogMessagesDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef MpvWaitEventC = Pointer<MpvEvent> Function(Pointer<Void>, Double);
typedef MpvWaitEventDart = Pointer<MpvEvent> Function(Pointer<Void>, double);

typedef MpvErrorStringC = Pointer<Utf8> Function(Int32);
typedef MpvErrorStringDart = Pointer<Utf8> Function(int);

final class MpvEvent extends Struct {
  @Int32()
  external int eventId;
  @Int32()
  external int error;
  @Uint64()
  external int replyUserdata;
  external Pointer<Void> data;
}

final class MpvEventLogMessage extends Struct {
  external Pointer<Utf8> prefix;
  external Pointer<Utf8> level;
  external Pointer<Utf8> text;
  @Int32()
  external int logLevel;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Trace mpv internal logs during initialize and option setting', () {
    final missing = EnvironmentService.init();
    expect(missing, isEmpty);

    final binDir = EnvironmentService.binDirectory;
    final mpvPath = p.join(binDir, 'mpv-2.dll');

    final mpvLib = DynamicLibrary.open(mpvPath);
    final mpvCreate = mpvLib.lookupFunction<MpvCreateC, MpvCreateDart>('mpv_create');
    final mpvInit = mpvLib.lookupFunction<MpvInitializeC, MpvInitializeDart>('mpv_initialize');
    final mpvSetOptString = mpvLib.lookupFunction<MpvSetOptionStringC, MpvSetOptionStringDart>('mpv_set_option_string');
    final mpvReqLog = mpvLib.lookupFunction<MpvRequestLogMessagesC, MpvRequestLogMessagesDart>('mpv_request_log_messages');
    final mpvWaitEvt = mpvLib.lookupFunction<MpvWaitEventC, MpvWaitEventDart>('mpv_wait_event');
    final mpvErrorStr = mpvLib.lookupFunction<MpvErrorStringC, MpvErrorStringDart>('mpv_error_string');

    final handle = mpvCreate();

    final logLvlPtr = 'trace'.toNativeUtf8();
    mpvReqLog(handle, logLvlPtr);
    calloc.free(logLvlPtr);

    final initRes = mpvInit(handle);
    debugPrint('mpv_initialize result: $initRes (${mpvErrorStr(initRes).toDartString()})');

    _drainLogs(handle, mpvWaitEvt, 'POST-INIT LOGS');

    final scriptFile = p.join(Directory.systemTemp.path, 'ez_test.vpy');
    File(scriptFile).writeAsStringSync('import vapoursynth as vs\ncore = vs.core\nclip = video_in\nclip.set_output()\n');
    final escapedPath = scriptFile.replaceAll('\\', '/');

    final vfNamePtr = 'vf'.toNativeUtf8();
    final vfValPtr = 'vapoursynth="$escapedPath"'.toNativeUtf8();

    final setOptRes = mpvSetOptString(handle, vfNamePtr, vfValPtr);
    debugPrint('mpv_set_option_string(vf, vapoursynth="$escapedPath") result: $setOptRes (${mpvErrorStr(setOptRes).toDartString()})');

    calloc.free(vfNamePtr);
    calloc.free(vfValPtr);

    _drainLogs(handle, mpvWaitEvt, 'POST-SET-OPTION LOGS');

    expect(setOptRes, equals(0));
  });
}

void _drainLogs(Pointer<Void> handle, MpvWaitEventDart mpvWaitEvt, String section) {
  debugPrint('--- $section ---');
  while (true) {
    final event = mpvWaitEvt(handle, 0.05);
    if (event.address == 0 || event.ref.eventId == 0) {
      break;
    }
    if (event.ref.eventId == 1) {
      final logMsg = event.ref.data.cast<MpvEventLogMessage>().ref;
      final prefix = logMsg.prefix != nullptr ? logMsg.prefix.toDartString() : '';
      final level = logMsg.level != nullptr ? logMsg.level.toDartString() : '';
      final text = logMsg.text != nullptr ? logMsg.text.toDartString().trim() : '';
      debugPrint('[$prefix] ($level) $text');
    }
  }
}
