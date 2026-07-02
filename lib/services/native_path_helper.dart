import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef SetEnvironmentVariableC = Int32 Function(Pointer<Utf16> lpName, Pointer<Utf16> lpValue);
typedef SetEnvironmentVariableDart = int Function(Pointer<Utf16> lpName, Pointer<Utf16> lpValue);

class NativePathHelper {
  static void prependToPath(String pathToAdd) {
    if (!Platform.isWindows) return;
    
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final getEnvVar = kernel32.lookupFunction<
        Int32 Function(Pointer<Utf16> lpName, Pointer<Utf16> lpBuffer, Int32 nSize),
        int Function(Pointer<Utf16> lpName, Pointer<Utf16> lpBuffer, int nSize)
    >('GetEnvironmentVariableW');
    
    final setEnvVar = kernel32.lookupFunction<
        Int32 Function(Pointer<Utf16> lpName, Pointer<Utf16> lpValue),
        int Function(Pointer<Utf16> lpName, Pointer<Utf16> lpValue)
    >('SetEnvironmentVariableW');

    final namePtr = 'PATH'.toNativeUtf16();
    
    // Get current PATH length
    final bufferSize = getEnvVar(namePtr, nullptr, 0);
    if (bufferSize > 0) {
      final buffer = calloc<Uint16>(bufferSize).cast<Utf16>();
      getEnvVar(namePtr, buffer, bufferSize);
      final currentPath = buffer.toDartString();
      calloc.free(buffer);
      
      if (!currentPath.contains(pathToAdd)) {
        final newPath = '$pathToAdd;$currentPath'.toNativeUtf16();
        setEnvVar(namePtr, newPath);
        calloc.free(newPath);
      }
    }
    
    calloc.free(namePtr);
  }

  static void setEnvVar(String name, String value) {
    if (!Platform.isWindows) return;
    
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final setEnvVar = kernel32.lookupFunction<
        Int32 Function(Pointer<Utf16> lpName, Pointer<Utf16> lpValue),
        int Function(Pointer<Utf16> lpName, Pointer<Utf16> lpValue)
    >('SetEnvironmentVariableW');

    final namePtr = name.toNativeUtf16();
    final valuePtr = value.toNativeUtf16();
    
    setEnvVar(namePtr, valuePtr);
    
    calloc.free(namePtr);
    calloc.free(valuePtr);
  }
}
