import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'game_logger.dart';

/// Periodically samples battery level/state during an active game and writes
/// the result to GameLogger. Active only between start() and stop() — never
/// runs globally. On API failure, logs once and stops trying.
class BatterySampler {
  BatterySampler._();
  static final BatterySampler instance = BatterySampler._();

  static const Duration _interval = Duration(seconds: 30);

  final Battery _battery = Battery();
  Timer? _timer;
  bool _failed = false;

  bool get isRunning => _timer != null;

  void start(String gameMode) {
    if (_timer != null) return;
    _failed = false;
    _sampleNow();
    _timer = Timer.periodic(_interval, (_) => _sampleNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sampleNow() async {
    if (_failed) return;
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      GameLogger.instance.logBattery(
        level: level,
        state: state.name,
      );
    } catch (e) {
      _failed = true;
      GameLogger.instance.logError('BatterySampler failed; halting samples', e);
      debugPrint('BatterySampler error: $e');
    }
  }
}
