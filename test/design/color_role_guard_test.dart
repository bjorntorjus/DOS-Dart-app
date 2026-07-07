import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// F22 (audit 2026-07-06): the classic track must use colorScheme roles.
/// Two palettes live side by side by design — the DOSSEDART track uses
/// DossedartTokens (raw hex there is checked in review, not here).
void main() {
  // Whole-file exceptions (documented in the color spec).
  const allowlist = <String>{
    'lib/utils/player_colors.dart', // avatar palette
    'lib/widgets/heatmap_board.dart', // data-viz gradient
    // Dead widgets — deleted in audit Round 5 (F25), not worth fixing:
    'lib/widgets/checkout_widget.dart',
    'lib/widgets/clock_progress.dart',
    'lib/widgets/cricket_scoreboard.dart',
    'lib/widgets/halve_it_scoreboard.dart',
  };

  final roleLiterals =
      RegExp(r'Colors\.(blue|green|red|amber|purple|pink|teal|indigo|cyan)\b');
  // orange only as the D-button literal; brown only as the bronze literal.
  final orangeNotDButton = RegExp(r'Colors\.orange(?!\[800\])');
  final brownNotBronze = RegExp(r'Colors\.brown(?!\[300\])');

  test('no role-colored Material literals on the classic track', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            !allowlist.contains(f.path.replaceAll('\\', '/')));
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (roleLiterals.hasMatch(code) ||
            orangeNotDButton.hasMatch(code) ||
            brownNotBronze.hasMatch(code)) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use Theme.of(context).colorScheme roles (F22):\n'
            '${offenders.join('\n')}');
  });
}
