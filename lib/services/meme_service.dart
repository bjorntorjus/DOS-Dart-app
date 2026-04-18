import '../models/dart_throw.dart';
import 'tts_service.dart';
import 'sound_service.dart';
import 'app_settings.dart';
import 'game_logger.dart';

class MemeService {
  final TtsService _tts = TtsService.instance;
  final SoundService _sound = SoundService.instance;
  final GameLogger _log = GameLogger.instance;

  bool _enabled = false;
  bool _meme67 = true;
  bool _memeNice = true;
  bool _memeRoundSounds = true;
  bool _memeOffensive = false;
  int _frequency = 5; // 1 (rare) to 10 (always)

  final List<DartThrow> _turnThrows = [];
  bool _soundPlayedThisTurn = false;

  Future<void> init() async {
    _enabled = await AppSettings.getMemeEnabled();
    _meme67 = await AppSettings.getMeme67();
    _memeNice = await AppSettings.getMemeNice();
    _memeRoundSounds = await AppSettings.getMemeRoundSounds();
    _memeOffensive = await AppSettings.getMemeOffensive();
    _frequency = await AppSettings.getMemeFrequency();
    await _sound.init();
  }

  void setEnabled(bool value) => _enabled = value;
  void setOffensive(bool value) => _memeOffensive = value;
  void setFrequency(int value) => _frequency = value;
  int get frequency => _frequency;

  /// Mark that a sound was already played this turn (e.g. miss, triple, bust).
  /// Prevents meme sounds from stacking on top.
  void markSoundPlayed() {
    _soundPlayedThisTurn = true;
    _log.logMeme(event: 'markSoundPlayed', outcome: 'external sound played', soundPlayedThisTurn: true);
  }

  /// Convert frequency (1-10) to a chance denominator for playRandomMaybe.
  /// 1=1/8, 3=1/5, 5=1/3 (default), 7=1/2, 10=always (1/1).
  int get frequencyChance {
    if (_frequency >= 10) return 1;
    if (_frequency >= 8) return 2;
    if (_frequency >= 6) return 3;
    if (_frequency >= 4) return 4;
    if (_frequency >= 2) return 6;
    return 8;
  }

  /// Call after each dart is thrown. Tracks the throw and checks for memes.
  /// [remainingScore] is the player's score after this throw (optional).
  /// Returns true if a meme sound was triggered (caller should skip TTS).
  bool onThrow(DartThrow dart, {int? remainingScore}) {
    _turnThrows.add(dart);
    if (!_enabled) return false;
    if (_soundPlayedThisTurn) {
      _log.logMeme(event: 'onThrow', outcome: 'skipped (soundPlayedThisTurn)', soundPlayedThisTurn: true);
      return true; // sound already playing — caller should skip TTS
    }

    bool triggered = false;

    // 6-7 sequence check
    if (_meme67 && _turnThrows.length >= 2) {
      final prev = _turnThrows[_turnThrows.length - 2];
      final curr = _turnThrows[_turnThrows.length - 1];
      if (prev.segment == 6 && prev.multiplier >= 1 &&
          curr.segment == 7 && curr.multiplier >= 1) {
        _log.logMeme(event: 'onThrow 6-7', outcome: 'triggered tts+sound', soundPlayedThisTurn: false);
        _log.logTts(event: 'speak "6 7, 6 7"', queueLength: null);
        _tts.speak('6 7, 6 7');
        _tts.callWhenIdle(() => _sound.playRandom(['six_seven'], fallback: 'six_seven'));
        _soundPlayedThisTurn = true;
        triggered = true;
      }
    }

    // Nice check: remaining score is 69
    if (!triggered && _memeNice && remainingScore == 69) {
      _log.logMeme(event: 'onThrow nice (remaining=69)', outcome: 'triggered tts+sound', soundPlayedThisTurn: false);
      _log.logTts(event: 'speak "nice"', queueLength: null);
      _tts.speak('nice');
      _tts.callWhenIdle(() => _sound.playRandom(['nice'], fallback: 'nice'));
      _soundPlayedThisTurn = true;
      triggered = true;
    }

    return triggered;
  }

  /// Call when a turn ends (3 darts or player advances). Checks round score then resets.
  /// Returns true if a meme sound was triggered (caller should skip TTS).
  bool onTurnEnd() {
    bool triggered = false;
    if (_enabled && _turnThrows.isNotEmpty && !_soundPlayedThisTurn) {
      final total = _turnThrows.fold<int>(0, (sum, t) => sum + t.points);

      if (_memeNice && total == 69) {
        _log.logMeme(event: 'onTurnEnd nice (total=69)', outcome: 'triggered tts+sound', soundPlayedThisTurn: false);
        _tts.speak('nice');
        _tts.callWhenIdle(() => _sound.playRandom(['nice'], fallback: 'nice'));
        _soundPlayedThisTurn = true;
        triggered = true;
      }

      if (!_soundPlayedThisTurn && _memeRoundSounds) {
        if (total >= 100) {
          _log.logMeme(event: 'onTurnEnd positive (total=$total)', outcome: 'playRoundSound', soundPlayedThisTurn: false);
          _playRoundSound('x01/positive/end of round');
          triggered = true;
        } else if (total < 10) {
          _log.logMeme(event: 'onTurnEnd negative (total=$total)', outcome: 'playRoundSound', soundPlayedThisTurn: false);
          _playRoundSound('x01/negative/end of round');
          triggered = true;
        }
      }
    } else if (_soundPlayedThisTurn) {
      final total = _turnThrows.isEmpty ? 0 : _turnThrows.fold<int>(0, (sum, t) => sum + t.points);
      _log.logMeme(event: 'onTurnEnd (total=$total)', outcome: 'skipped (soundPlayedThisTurn)', soundPlayedThisTurn: true);
    }
    _turnThrows.clear();
    _soundPlayedThisTurn = false;
    return triggered;
  }

  void _playRoundSound(String folder) {
    final folders = [folder];
    if (_memeOffensive) folders.add('x01/offensive/end of round');
    _log.logSound(source: 'meme', event: 'playRandomMaybe($folders, chance=$frequencyChance)');
    _sound.playRandomMaybe(folders, chance: frequencyChance);
  }

  /// Call on bust or other turn-reset scenarios.
  void resetTurn() {
    _turnThrows.clear();
    _soundPlayedThisTurn = false;
  }
}
