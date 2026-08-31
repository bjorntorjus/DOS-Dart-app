import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/meme_service.dart';

/// Meme-damping 2026-08-10 (audit F4): the default drops from 5 to 3,
/// offsetting the 1UP parity fix which adds meme paths. Only clean installs
/// move.
///
/// In real terms that is 1-in-4 → 1-in-6, NOT the 1-in-3 → 1-in-5 the spec
/// first claimed: `frequencyChance` buckets the 10 slider stops into 6
/// outcomes, and its own doc comment described them wrongly until this
/// change. The mapping is pinned below so the next reader gets the truth
/// from a test rather than a comment.
///
/// The MemeService cases use testWidgets, not test: its constructor reaches
/// TtsService and SoundService, both of which wire platform channels, and a
/// bare unit test has no binding to serve them — the failure lands after the
/// test completes, which is confusing to diagnose.
void main() {
  test('a clean install defaults to 3', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await AppSettings.getMemeFrequency(), 3);
  });

  test('a stored value always wins over the default', () async {
    SharedPreferences.setMockInitialValues({'meme_frequency': 8});
    expect(await AppSettings.getMemeFrequency(), 8);
  });

  testWidgets('the default frequency means 1-in-6 throws', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final meme = MemeService();
    await meme.init();
    expect(meme.frequencyChance, 6);
  });

  testWidgets('frequencyChance buckets the slider into 6 outcomes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final meme = MemeService();
    await meme.init();
    const expected = {
      1: 8,
      2: 6,
      3: 6,
      4: 4,
      5: 4,
      6: 3,
      7: 3,
      8: 2,
      9: 2,
      10: 1,
    };
    for (final entry in expected.entries) {
      meme.setFrequency(entry.key);
      expect(meme.frequencyChance, entry.value,
          reason: 'frequency ${entry.key}');
    }
  });
}
