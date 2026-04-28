import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'app_settings.dart';

/// Persistent game logger that writes detailed event logs to daily files.
/// Keeps last 5 daily log files. All game modes use this service.
class GameLogger {
  GameLogger._();
  static final GameLogger instance = GameLogger._();

  File? _logFile;
  Directory? _logDir;
  bool _initialized = false;
  int _gameIndex = 0;

  LogMode _mode = LogMode.full;

  LogMode get mode => _mode;
  void setMode(LogMode value) => _mode = value;

  bool get isBatteryAllowed => _mode != LogMode.off;
  bool get isGeneralAllowed => _mode == LogMode.full;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logDir = Directory('${dir.path}/game_logs');
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }
      final today = _todayString();
      _logFile = File('${_logDir!.path}/game_log_$today.txt');
      await _cleanOldLogs();
    } catch (e) {
      debugPrint('GameLogger init failed: $e');
    }
    _mode = await AppSettings.getLogMode();
  }

  /// Delete log files older than 5 days.
  Future<void> _cleanOldLogs() async {
    if (_logDir == null) return;
    try {
      final files = _logDir!
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path)); // newest first
      for (int i = 5; i < files.length; i++) {
        await files[i].delete();
      }
    } catch (_) {}
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}.${_pad3(now.millisecond)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _pad3(int n) => n.toString().padLeft(3, '0');

  // ─── Game lifecycle ─────────────────────────────────────────

  void logGameStart({
    required String gameMode,
    required List<String> playerNames,
    required List<int> playerScores,
    Map<String, dynamic>? config,
  }) {
    if (!isGeneralAllowed) return;
    _gameIndex++;
    _write('');
    _write('${'=' * 60}');
    _write('GAME #$_gameIndex: $gameMode | ${DateTime.now().toIso8601String()}');
    final players = <String>[];
    for (int i = 0; i < playerNames.length; i++) {
      players.add('P$i:${playerNames[i]}(score=${playerScores[i]})');
    }
    _write('Players: ${players.join(', ')}');
    if (config != null && config.isNotEmpty) {
      _write('Config: $config');
    }
    _write('${'=' * 60}');
  }

  void logGameEnd({
    required List<String> playerNames,
    required List<int> finishedOrder,
    bool gameFullyOver = true,
  }) {
    if (!isGeneralAllowed) return;
    final placements = finishedOrder
        .map((i) => 'P$i:${i < playerNames.length ? playerNames[i] : '?'}')
        .join(', ');
    _write('GAME_END gameOver=$gameFullyOver placements=[$placements]');
    _write('${'─' * 60}');
  }

  // ─── Turn events ────────────────────────────────────────────

  void logTurnStart({
    required int roundNumber,
    required int playerIndex,
    required String playerName,
    required int score,
    String? checkoutHint,
  }) {
    if (!isGeneralAllowed) return;
    final hint = checkoutHint != null ? ' checkout=$checkoutHint' : '';
    _write('R$roundNumber TURN P$playerIndex($playerName) score=$score$hint');
  }

  void logThrow({
    required int roundNumber,
    required int playerIndex,
    required String label,
    required int points,
    required int scoreBefore,
    required int scoreAfter,
    required int dartNumber,
    String? extra,
  }) {
    if (!isGeneralAllowed) return;
    final ex = extra != null ? ' $extra' : '';
    _write('R$roundNumber THROW P$playerIndex $label($points) $scoreBefore→$scoreAfter dart=${dartNumber + 1}/3$ex');
  }

  void logBust({
    required int roundNumber,
    required int playerIndex,
    required String playerName,
    required String throwLabel,
    required int scoreReset,
  }) {
    if (!isGeneralAllowed) return;
    _write('R$roundNumber BUST P$playerIndex($playerName) $throwLabel → score reset to $scoreReset');
  }

  void logCheckout({
    required int roundNumber,
    required int playerIndex,
    required String playerName,
    required int dartsUsed,
    required int checkoutScore,
  }) {
    if (!isGeneralAllowed) return;
    _write('R$roundNumber CHECKOUT P$playerIndex($playerName) darts=$dartsUsed from=$checkoutScore');
  }

  void logFinish({
    required int roundNumber,
    required int playerIndex,
    required String playerName,
    String? details,
  }) {
    if (!isGeneralAllowed) return;
    final det = details != null ? ' $details' : '';
    _write('R$roundNumber FINISH P$playerIndex($playerName)$det');
  }

  void logAdvance({
    required int roundNumber,
    required int fromIndex,
    required int toIndex,
    required String toName,
    required int toScore,
    String? reason,
  }) {
    if (!isGeneralAllowed) return;
    final r = reason != null ? ' ($reason)' : '';
    _write('R$roundNumber ADVANCE P$fromIndex→P$toIndex($toName) score=$toScore$r');
  }

  // ─── Round events ───────────────────────────────────────────

  void logRoundComplete({
    required int roundNumber,
    required Set<int> completedPlayers,
    required List<int> finishedPlayers,
  }) {
    if (!isGeneralAllowed) return;
    _write('R$roundNumber ROUND_COMPLETE completed=$completedPlayers finished=$finishedPlayers');
  }

  void logResolve({
    required int roundNumber,
    required String details,
  }) {
    if (!isGeneralAllowed) return;
    _write('R$roundNumber RESOLVE $details');
  }

  void logPostGame({required String action, String? details}) {
    if (!isGeneralAllowed) return;
    final det = details != null ? ' $details' : '';
    _write('POSTGAME action=$action$det');
  }

  // ─── Undo ───────────────────────────────────────────────────

  void logUndo({
    required int playerIndex,
    required String playerName,
    required String throwLabel,
    required int scoreRestored,
    required int roundNumber,
  }) {
    if (!isGeneralAllowed) return;
    _write('UNDO P$playerIndex($playerName) $throwLabel → score=$scoreRestored round=$roundNumber');
  }

  // ─── State snapshots ───────────────────────────────────────

  void logState(Map<String, dynamic> state) {
    if (!isGeneralAllowed) return;
    final parts = state.entries.map((e) => '${e.key}=${e.value}').join(', ');
    _write('STATE $parts');
  }

  // ─── Sound events ──────────────────────────────────────────

  void logSound({
    required String source,
    required String event,
    String? outcome,
  }) {
    if (!isGeneralAllowed) return;
    final out = outcome != null ? ' → $outcome' : '';
    _write('SOUND [$source] $event$out');
  }

  void logMeme({
    required String event,
    required String outcome,
    bool? soundPlayedThisTurn,
  }) {
    if (!isGeneralAllowed) return;
    final flag = soundPlayedThisTurn != null ? ' soundPlayedThisTurn=$soundPlayedThisTurn' : '';
    _write('MEME $event → $outcome$flag');
  }

  void logTts({required String event, int? queueLength}) {
    if (!isGeneralAllowed) return;
    final q = queueLength != null ? ' queue=$queueLength' : '';
    _write('TTS $event$q');
  }

  // ─── Errors ─────────────────────────────────────────────────

  void logError(String message, [Object? error, StackTrace? stack]) {
    if (!isGeneralAllowed) return;
    _write('ERROR $message');
    if (error != null) _write('  exception: $error');
    if (stack != null) {
      final lines = stack.toString().split('\n').take(5);
      for (final line in lines) {
        _write('  $line');
      }
    }
  }

  // ─── Generic ────────────────────────────────────────────────

  void logBattery({required int level, required String state}) {
    if (!isBatteryAllowed) return;
    _write('BATTERY level=$level% state=$state');
  }

  void log(String message) {
    if (!isGeneralAllowed) return;
    _write(message);
  }

  // ─── File access ────────────────────────────────────────────

  /// Returns today's log file, or null if not initialized.
  Future<File?> getTodaysLogFile() async {
    await init();
    if (_logFile != null && await _logFile!.exists()) {
      return _logFile;
    }
    return null;
  }

  /// Returns all available log files sorted newest first.
  Future<List<File>> getAllLogFiles() async {
    await init();
    if (_logDir == null) return [];
    try {
      final files = _logDir!
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return [];
    }
  }

  // ─── Internal ───────────────────────────────────────────────

  void _write(String line) {
    if (_logFile == null) return;
    try {
      final ts = _timestamp();
      _logFile!.writeAsStringSync('[$ts] $line\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('GameLogger write failed: $e');
    }
  }
}
