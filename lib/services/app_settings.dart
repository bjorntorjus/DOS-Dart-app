import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // Handicap
  static const String _handicapScaleKey = 'handicap_scale';
  static const double defaultHandicapScale = 0.5;

  // TTS
  static const String _ttsEnabledKey = 'tts_enabled';
  static const String _ttsLanguageKey = 'tts_language';
  static const String _ttsNextPlayerKey = 'tts_announce_next_player';
  static const String _ttsThrowResultKey = 'tts_announce_throw_result';
  static const String _ttsScoreKey = 'tts_announce_score';
  static const String _ttsWinnerKey = 'tts_announce_winner';
  static const String _ttsGameEventsKey = 'tts_announce_game_events';
  static const String _ttsVoiceKey = 'tts_voice';

  // Handicap getters/setters
  static Future<double> getHandicapScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_handicapScaleKey) ?? defaultHandicapScale;
  }

  static Future<void> setHandicapScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_handicapScaleKey, value);
  }

  // TTS getters/setters
  static Future<bool> getTtsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsEnabledKey) ?? false;
  }

  static Future<void> setTtsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsEnabledKey, value);
  }

  static Future<String> getTtsLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ttsLanguageKey) ?? 'en-US';
  }

  static Future<void> setTtsLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ttsLanguageKey, value);
  }

  static Future<String> getTtsVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ttsVoiceKey) ?? '';
  }

  static Future<void> setTtsVoice(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ttsVoiceKey, value);
  }

  static Future<bool> getTtsNextPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsNextPlayerKey) ?? true;
  }

  static Future<void> setTtsNextPlayer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsNextPlayerKey, value);
  }

  static Future<bool> getTtsThrowResult() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsThrowResultKey) ?? true;
  }

  static Future<void> setTtsThrowResult(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsThrowResultKey, value);
  }

  static Future<bool> getTtsScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsScoreKey) ?? true;
  }

  static Future<void> setTtsScore(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsScoreKey, value);
  }

  static Future<bool> getTtsWinner() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsWinnerKey) ?? true;
  }

  static Future<void> setTtsWinner(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsWinnerKey, value);
  }

  static Future<bool> getTtsGameEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsGameEventsKey) ?? true;
  }

  static Future<void> setTtsGameEvents(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsGameEventsKey, value);
  }

  // ELO Rating
  static const String _eloKNewKey = 'elo_k_new';
  static const String _eloKExpKey = 'elo_k_experienced';
  static const String _eloThresholdKey = 'elo_threshold';
  static const double defaultEloKNew = 32.0;
  static const double defaultEloKExp = 16.0;
  static const int defaultEloThreshold = 20;

  static Future<double> getEloKNew() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_eloKNewKey) ?? defaultEloKNew;
  }

  static Future<void> setEloKNew(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_eloKNewKey, value);
  }

  static Future<double> getEloKExp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_eloKExpKey) ?? defaultEloKExp;
  }

  static Future<void> setEloKExp(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_eloKExpKey, value);
  }

  static Future<int> getEloThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_eloThresholdKey) ?? defaultEloThreshold;
  }

  static Future<void> setEloThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eloThresholdKey, value);
  }

  // Memes
  static const String _memeEnabledKey = 'meme_enabled';
  static const String _meme67Key = 'meme_67';
  static const String _memeNiceKey = 'meme_nice';
  static const String _memeRoundSoundsKey = 'meme_round_sounds';
  static const String _memeOffensiveKey = 'meme_offensive';
  static const String _memeFrequencyKey = 'meme_frequency';

  static Future<bool> getMemeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_memeEnabledKey) ?? false;
  }

  static Future<void> setMemeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memeEnabledKey, value);
  }

  static Future<bool> getMeme67() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_meme67Key) ?? true;
  }

  static Future<void> setMeme67(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_meme67Key, value);
  }

  static Future<bool> getMemeNice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_memeNiceKey) ?? true;
  }

  static Future<void> setMemeNice(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memeNiceKey, value);
  }

  static Future<bool> getMemeRoundSounds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_memeRoundSoundsKey) ?? true;
  }

  static Future<void> setMemeRoundSounds(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memeRoundSoundsKey, value);
  }

  static Future<bool> getMemeOffensive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_memeOffensiveKey) ?? false;
  }

  static Future<void> setMemeOffensive(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_memeOffensiveKey, value);
  }

  /// Meme frequency: 1 (rare) to 10 (always). Default 5.
  static Future<int> getMemeFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_memeFrequencyKey) ?? 5;
  }

  static Future<void> setMemeFrequency(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_memeFrequencyKey, value);
  }

  // Sound effects
  static const String _soundEffectsEnabledKey = 'sound_effects_enabled';

  static Future<bool> getSoundEffectsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEffectsEnabledKey) ?? true;
  }

  static Future<void> setSoundEffectsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsEnabledKey, value);
  }

  // Video events
  static const String _videoEventsEnabledKey = 'video_events_enabled';

  static Future<bool> getVideoEventsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_videoEventsEnabledKey) ?? true;
  }

  static Future<void> setVideoEventsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_videoEventsEnabledKey, value);
  }
}
