import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_settings.dart';
import '../services/elo_service.dart';
import '../services/game_logger.dart';
import '../services/tts_service.dart';
import 'meme_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _handicapScale = AppSettings.defaultHandicapScale;
  bool _isLoading = true;

  // ELO
  double _eloKNew = AppSettings.defaultEloKNew;
  double _eloKExp = AppSettings.defaultEloKExp;
  int _eloThreshold = AppSettings.defaultEloThreshold;

  // Memes
  bool _memeEnabled = false;

  // Debug
  LogMode _logMode = LogMode.full;

  // Sound & Video
  bool _soundEffectsEnabled = true;
  bool _videoEventsEnabled = true;

  // TTS
  bool _ttsEnabled = false;
  String _ttsLanguage = 'en-US';
  String _ttsVoice = '';
  List<String> _availableLanguages = [];
  List<Map<String, String>> _availableVoices = [];
  bool _ttsNextPlayer = true;
  bool _ttsThrowResult = true;
  bool _ttsScore = true;
  bool _ttsWinner = true;
  bool _ttsGameEvents = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scale = await AppSettings.getHandicapScale();
    final ttsEnabled = await AppSettings.getTtsEnabled();
    final ttsLanguage = await AppSettings.getTtsLanguage();
    final ttsNextPlayer = await AppSettings.getTtsNextPlayer();
    final ttsThrowResult = await AppSettings.getTtsThrowResult();
    final ttsScore = await AppSettings.getTtsScore();
    final ttsWinner = await AppSettings.getTtsWinner();
    final ttsGameEvents = await AppSettings.getTtsGameEvents();
    final memeEnabled = await AppSettings.getMemeEnabled();
    final soundEffectsEnabled = await AppSettings.getSoundEffectsEnabled();
    final videoEventsEnabled = await AppSettings.getVideoEventsEnabled();
    final ttsVoice = await AppSettings.getTtsVoice();
    final eloKNew = await AppSettings.getEloKNew();
    final eloKExp = await AppSettings.getEloKExp();
    final eloThreshold = await AppSettings.getEloThreshold();
    final logMode = await AppSettings.getLogMode();

    await TtsService.instance.init();
    final languages = await TtsService.instance.getLanguages();
    final voices = await TtsService.instance.getVoices();

    setState(() {
      _handicapScale = scale;
      _ttsEnabled = ttsEnabled;
      _ttsLanguage = ttsLanguage;
      _ttsVoice = ttsVoice;
      _availableLanguages = languages;
      _availableVoices = voices;
      _ttsNextPlayer = ttsNextPlayer;
      _ttsThrowResult = ttsThrowResult;
      _ttsScore = ttsScore;
      _ttsWinner = ttsWinner;
      _ttsGameEvents = ttsGameEvents;
      _memeEnabled = memeEnabled;
      _soundEffectsEnabled = soundEffectsEnabled;
      _videoEventsEnabled = videoEventsEnabled;
      _eloKNew = eloKNew;
      _eloKExp = eloKExp;
      _eloThreshold = eloThreshold;
      _logMode = logMode;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Handicap section
                Text('Handicap',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scale factor: ${_handicapScale.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Points per rating point above/below 1200.\n'
                          'Example: A 1400-rated player starts '
                          '${(200 * _handicapScale).round()} points higher.',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _handicapScale,
                          min: 0.1,
                          max: 2.0,
                          divisions: 19,
                          label: _handicapScale.toStringAsFixed(2),
                          onChanged: (v) {
                            setState(() => _handicapScale = v);
                            AppSettings.setHandicapScale(v);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('0.10',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                            Text('2.00',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ELO Rating section
                Text('ELO Rating',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How ELO works',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Each game compares players pairwise. Winners gain rating, losers drop. '
                          'The K-factor controls how much ratings change per game. '
                          'New players use a higher K so their rating adjusts quickly. '
                          'After a threshold of games, K drops for more stable ratings. '
                          'Rating changes are scaled by 1/(N-1) for multi-player games.',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'K-factor (new players): ${_eloKNew.round()}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rating change per game for players with < $_eloThreshold games.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Slider(
                          value: _eloKNew,
                          min: 8,
                          max: 64,
                          divisions: 14,
                          label: _eloKNew.round().toString(),
                          onChanged: (v) {
                            setState(() => _eloKNew = v);
                            AppSettings.setEloKNew(v);
                            EloService.loadSettings();
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'K-factor (experienced): ${_eloKExp.round()}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rating change per game for players with >= $_eloThreshold games.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Slider(
                          value: _eloKExp,
                          min: 4,
                          max: 48,
                          divisions: 11,
                          label: _eloKExp.round().toString(),
                          onChanged: (v) {
                            setState(() => _eloKExp = v);
                            AppSettings.setEloKExp(v);
                            EloService.loadSettings();
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Experience threshold: $_eloThreshold games',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'After this many games, K-factor drops from ${_eloKNew.round()} to ${_eloKExp.round()}.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Slider(
                          value: _eloThreshold.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          label: _eloThreshold.toString(),
                          onChanged: (v) {
                            setState(() => _eloThreshold = v.round());
                            AppSettings.setEloThreshold(v.round());
                            EloService.loadSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // TTS section
                Text('Text-to-Speech',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Enable TTS'),
                        subtitle:
                            const Text('Voice announcements during games'),
                        value: _ttsEnabled,
                        onChanged: (v) {
                          setState(() => _ttsEnabled = v);
                          TtsService.instance.setEnabled(v);
                        },
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                      ),
                      if (_ttsEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Language'),
                          trailing: DropdownButton<String>(
                            value: _availableLanguages.contains(_ttsLanguage)
                                ? _ttsLanguage
                                : _availableLanguages.isNotEmpty
                                    ? _availableLanguages.first
                                    : null,
                            items: _availableLanguages
                                .map((lang) => DropdownMenuItem(
                                      value: lang,
                                      child: Text(lang, style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _ttsLanguage = v;
                                _ttsVoice = '';
                              });
                              TtsService.instance.setLanguage(v);
                            },
                            underline: const SizedBox(),
                          ),
                        ),
                        const Divider(height: 1),
                        Builder(builder: (context) {
                          final voicesForLang = _availableVoices
                              .where((v) =>
                                  (v['locale'] ?? '').startsWith(_ttsLanguage))
                              .toList();
                          if (voicesForLang.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final currentValid = voicesForLang
                              .any((v) => v['name'] == _ttsVoice);
                          return ListTile(
                            title: const Text('Voice'),
                            trailing: DropdownButton<String>(
                              value: currentValid ? _ttsVoice : '',
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Default',
                                      style: TextStyle(fontSize: 14)),
                                ),
                                ...voicesForLang.map((v) => DropdownMenuItem(
                                      value: v['name'] ?? '',
                                      child: Text(
                                        v['name'] ?? 'Unknown',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    )),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _ttsVoice = v);
                                if (v.isEmpty) {
                                  // Reset to default
                                  TtsService.instance.setLanguage(_ttsLanguage);
                                } else {
                                  final voice = voicesForLang.firstWhere(
                                      (vv) => vv['name'] == v);
                                  TtsService.instance.setVoice(voice);
                                }
                              },
                              underline: const SizedBox(),
                            ),
                          );
                        }),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text('Announcements',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13)),
                        ),
                        SwitchListTile(
                          title: const Text('Next player'),
                          dense: true,
                          value: _ttsNextPlayer,
                          onChanged: (v) {
                            setState(() => _ttsNextPlayer = v);
                            AppSettings.setTtsNextPlayer(v);
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        SwitchListTile(
                          title: const Text('Throw result'),
                          dense: true,
                          value: _ttsThrowResult,
                          onChanged: (v) {
                            setState(() => _ttsThrowResult = v);
                            AppSettings.setTtsThrowResult(v);
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        SwitchListTile(
                          title: const Text('Score / remaining'),
                          dense: true,
                          value: _ttsScore,
                          onChanged: (v) {
                            setState(() => _ttsScore = v);
                            AppSettings.setTtsScore(v);
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        SwitchListTile(
                          title: const Text('Winner'),
                          dense: true,
                          value: _ttsWinner,
                          onChanged: (v) {
                            setState(() => _ttsWinner = v);
                            AppSettings.setTtsWinner(v);
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        SwitchListTile(
                          title: const Text('Game events'),
                          subtitle: const Text(
                              'Bust, halved, eliminated, killer, etc.'),
                          dense: true,
                          value: _ttsGameEvents,
                          onChanged: (v) {
                            setState(() => _ttsGameEvents = v);
                            AppSettings.setTtsGameEvents(v);
                          },
                          activeTrackColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Memes section
                Text('Memes',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: GestureDetector(
                    onLongPress: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MemeSettingsScreen(),
                        ),
                      );
                    },
                    child: SwitchListTile(
                      title: const Text('Enable memes'),
                      subtitle: const Text('Fun announcements during games'),
                      value: _memeEnabled,
                      onChanged: (v) {
                        setState(() => _memeEnabled = v);
                        AppSettings.setMemeEnabled(v);
                      },
                      activeTrackColor:
                          Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Sound effects section
                Text('Sound Effects',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Sound effects'),
                        subtitle: const Text(
                            'Plays .mp3 files from assets/sounds/ on game events'),
                        value: _soundEffectsEnabled,
                        onChanged: (v) {
                          setState(() => _soundEffectsEnabled = v);
                          AppSettings.setSoundEffectsEnabled(v);
                        },
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                      ),
                      SwitchListTile(
                        title: const Text('Video events'),
                        subtitle: const Text(
                            'Shows .mp4 clips from assets/videos/ on special throws'),
                        value: _videoEventsEnabled,
                        onChanged: (v) {
                          setState(() => _videoEventsEnabled = v);
                          AppSettings.setVideoEventsEnabled(v);
                        },
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Debug section
                Text('Debug',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Log mode',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),
                      ),
                      RadioListTile<LogMode>(
                        title: const Text('Full (every event)'),
                        value: LogMode.full,
                        groupValue: _logMode,
                        onChanged: (v) async {
                          if (v == null) return;
                          await AppSettings.setLogMode(v);
                          GameLogger.instance.setMode(v);
                          setState(() => _logMode = v);
                        },
                      ),
                      RadioListTile<LogMode>(
                        title: const Text('Minimal (battery only)'),
                        value: LogMode.minimal,
                        groupValue: _logMode,
                        onChanged: (v) async {
                          if (v == null) return;
                          await AppSettings.setLogMode(v);
                          GameLogger.instance.setMode(v);
                          setState(() => _logMode = v);
                        },
                      ),
                      RadioListTile<LogMode>(
                        title: const Text('Off'),
                        value: LogMode.off,
                        groupValue: _logMode,
                        onChanged: (v) async {
                          if (v == null) return;
                          await AppSettings.setLogMode(v);
                          GameLogger.instance.setMode(v);
                          setState(() => _logMode = v);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Feedback section
                Text('Feedback',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.grey)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.feedback_outlined),
                        title: const Text('Send feedback'),
                        subtitle: const Text(
                            'Report a bug or suggest an improvement'),
                        onTap: _showFeedbackDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showFeedbackDialog() async {
    final log = GameLogger.instance;
    await log.init();
    final logFile = await log.getTodaysLogFile();
    final hasLog = logFile != null;

    if (!mounted) return;

    final messageController = TextEditingController();
    bool attachLog = hasLog;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Send feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the bug or suggestion...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              if (hasLog) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: attachLog,
                      onChanged: (v) =>
                          setDialogState(() => attachLog = v ?? false),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(child: Text("Attach today's game log")),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final message = messageController.text.trim();
    final params = ShareParams(
      text: message.isEmpty ? null : message,
      files: (attachLog && logFile != null) ? [XFile(logFile.path)] : null,
      subject: 'Dart Scorer - Feedback',
    );
    await SharePlus.instance.share(params);
  }
}
