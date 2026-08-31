import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/video_service.dart';

/// The video slider is the only thing that decides how often videos play
/// (audit 2026-08-10, F2). Four cockpits used to pre-roll the *meme* slider
/// on top, so turning memes up produced more videos — which the two
/// independent sliders in Settings imply nothing about.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VideoService.instance.setEnabled(true);
  });

  test('video frequency 10 always plays, whatever the meme slider says',
      () async {
    await AppSettings.setVideoFrequency(10);
    await AppSettings.setMemeFrequency(1);
    await VideoService.instance.init();
    VideoService.instance.setEnabled(true);

    for (var i = 0; i < 50; i++) {
      expect(VideoService.instance.shouldPlay(), isTrue);
    }
  });

  test('a low video frequency suppresses regardless of the meme slider',
      () async {
    await AppSettings.setVideoFrequency(1); // 1-in-8
    await AppSettings.setMemeFrequency(10);
    await VideoService.instance.init();
    VideoService.instance.setEnabled(true);

    var plays = 0;
    for (var i = 0; i < 400; i++) {
      if (VideoService.instance.shouldPlay()) plays++;
    }
    expect(plays, lessThan(120),
        reason: '1-in-8 should land far below a quarter of 400');
  });

  test('disabled videos never play, at any frequency', () async {
    await AppSettings.setVideoFrequency(10);
    await VideoService.instance.init();
    VideoService.instance.setEnabled(false);

    expect(VideoService.instance.shouldPlay(), isFalse);
  });

  // NOT covered here: that showRandomFromFolder honours `alreadyDecided`
  // instead of re-rolling. `disableForTest` short-circuits the method before
  // any observable effect, so a test would only assert that it does not
  // throw — theatre, not coverage. The cockpits passing the flag is enforced
  // by the compiler; the behaviour itself is a two-line read of
  // video_service.dart.
}
