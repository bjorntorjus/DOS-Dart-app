// test/design/no_norwegian_ui_text_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// F21 (audit 2026-07-06): UI text must be English. This scans every string
/// literal in lib/ for Norwegian characters. Comments are stripped first —
/// they must be English too, but only literals can reach the screen.
void main() {
  test('no Norwegian characters in lib/ string literals', () {
    final nordicInString = RegExp("['\"][^'\"\\n]*[æøåÆØÅ][^'\"\\n]*['\"]");
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first; // strip line comments
        if (nordicInString.hasMatch(code)) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'UI text must be English (F21):\n${offenders.join('\n')}');
  });
}
