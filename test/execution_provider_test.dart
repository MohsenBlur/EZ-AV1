import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Log Parsing Regex', () {
    final percentRegex = RegExp(r'(\d+(?:\.\d+)?)%');
    final fpsRegex = RegExp(r'(\d+(?:\.\d+)?)\s*fps', caseSensitive: false);
    final etaRegex = RegExp(r'ETA:\s*([0-9:]+)', caseSensitive: false);
    final fractionRegex = RegExp(r'\[(\d+)/(\d+)\]');

    test('parses decimal values correctly', () {
      const log = '[12/100] 12.5% | 2.1 fps | ETA: 00:15:30';

      final percent = percentRegex.firstMatch(log)?.group(1);
      final fps = fpsRegex.firstMatch(log)?.group(1);
      final eta = etaRegex.firstMatch(log)?.group(1);

      expect(double.tryParse(percent!), equals(12.5));
      expect(double.tryParse(fps!), equals(2.1));
      expect(eta, equals('00:15:30'));
    });

    test('parses integer values correctly', () {
      const log = '[50/100] 50% | 4 fps | ETA: 00:02:10';

      final percent = percentRegex.firstMatch(log)?.group(1);
      final fps = fpsRegex.firstMatch(log)?.group(1);
      final eta = etaRegex.firstMatch(log)?.group(1);

      expect(double.tryParse(percent!), equals(50.0));
      expect(double.tryParse(fps!), equals(4.0));
      expect(eta, equals('00:02:10'));
    });

    test('parses fraction format fallback when percentage sign is omitted', () {
      const log = 'Encoding chunk [25/100] (25 fps)';

      final percentMatch = percentRegex.firstMatch(log);
      expect(percentMatch, isNull);

      final fractionMatch = fractionRegex.firstMatch(log);
      expect(fractionMatch, isNotNull);

      final done = double.parse(fractionMatch!.group(1)!);
      final total = double.parse(fractionMatch.group(2)!);
      final calculatedPercent = (done / total) * 100.0;

      expect(calculatedPercent, equals(25.0));
    });
  });

  group('Log Capping Algorithm', () {
    List<String> capLogLines(List<String> lines, {int maxLines = 500, int headLines = 50}) {
      if (lines.length <= maxLines) return lines;
      final head = lines.sublist(0, headLines);
      final tailCount = maxLines - headLines - 1;
      final tail = lines.sublist(lines.length - tailCount);
      return [
        ...head,
        '--- [log output truncated: ${lines.length - maxLines} lines omitted] ---',
        ...tail,
      ];
    }

    test('preserves head setup lines and tail status lines when log length exceeds cap', () {
      final lines = List.generate(600, (i) => 'Line $i');
      final capped = capLogLines(lines, maxLines: 500, headLines: 50);

      expect(capped.length, equals(500));
      expect(capped.first, equals('Line 0'));
      expect(capped[49], equals('Line 49'));
      expect(capped[50], contains('log output truncated: 100 lines omitted'));
      expect(capped.last, equals('Line 599'));
    });
  });
}
