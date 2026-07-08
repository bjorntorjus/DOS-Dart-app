import 'tts_service.dart';
import 'sound_service.dart';
import 'video_service.dart';
import 'app_settings.dart';

class GameAnnouncer {
  final TtsService _tts = TtsService.instance;
  final SoundService _sound = SoundService.instance;

  bool _nextPlayer = true;
  bool _throwResult = true;
  bool _score = true;
  bool _winner = true;
  bool _gameEvents = true;

  Future<void> init() async {
    await _tts.init();
    await _sound.init();
    await VideoService.instance.init();
    _nextPlayer = await AppSettings.getTtsNextPlayer();
    _throwResult = await AppSettings.getTtsThrowResult();
    _score = await AppSettings.getTtsScore();
    _winner = await AppSettings.getTtsWinner();
    _gameEvents = await AppSettings.getTtsGameEvents();
  }

  void announceNextPlayer(String name) {
    if (_nextPlayer) _tts.speak(name);
  }

  void announceThrow(String label) {
    if (_throwResult) _tts.speak(label);
  }

  void announceScore(String scoreText) {
    if (_score) _tts.speak(scoreText);
  }

  void announceWinner(String name) {
    if (_winner) _tts.speak('$name wins!');
    // Play win sound after TTS finishes so they don't overlap
    _tts.callWhenIdle(() => _sound.playRandom(['win'], fallback: 'win'));
  }

  /// Gotcha kill: speak the event, then layer the kill sound when TTS is idle.
  /// assets/sounds/gotcha/kill/ ships no recordings in v1 (spec §9) —
  /// playRandom is a silent no-op until files are added + declared in pubspec.
  void announceKill(List<String> victimNames) {
    if (_gameEvents) {
      final names = victimNames.join(' and ');
      _tts.speak(victimNames.length > 1
          ? 'Double gotcha! $names back to zero'
          : 'Gotcha! $names back to zero');
    }
    _tts.callWhenIdle(() => _sound.playRandom(['gotcha/kill']));
  }

  void announceGameEvent(String event) {
    if (_gameEvents) _tts.speak(event);
    if (event == 'Bust') _tts.callWhenIdle(() => _sound.play('bust'));
    if (event == 'Out') _tts.callWhenIdle(() => _sound.play('checkout'));
  }

  void stop() {
    _tts.stop();
  }
}
