import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ez_av1/services/preview_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PreviewService.extractKeyframeSnippet returns empty string safely for non-existent files', () async {
    final nonExistentPath = r'L:\NonExistentDrive\MissingFile_12345.mkv';
    expect(File(nonExistentPath).existsSync(), isFalse);

    final result = await PreviewService.extractKeyframeSnippet(nonExistentPath);
    expect(result, equals(''));
  });

  test('PreviewService.getVideoDuration returns 0.0 safely for non-existent files', () async {
    final nonExistentPath = r'L:\NonExistentDrive\MissingFile_12345.mkv';
    final duration = await PreviewService.getVideoDuration(nonExistentPath);
    expect(duration, equals(0.0));
  });
}
