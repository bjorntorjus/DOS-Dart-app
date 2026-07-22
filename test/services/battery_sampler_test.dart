import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/battery_sampler.dart';

void main() {
  // This file tests start()/isRunning behavior directly, so it must opt out
  // of the F18 global test-config flag (which disables start() everywhere
  // else to prevent the 30s periodic timer from blocking pumpAndSettle).
  setUp(() {
    BatterySampler.disableForTest = false;
  });
  tearDown(() {
    BatterySampler.instance.stop();
    BatterySampler.disableForTest = true;
  });

  test('start sets running, stop clears it', () {
    final sampler = BatterySampler.instance;
    expect(sampler.isRunning, isFalse);

    sampler.start('Cricket');
    expect(sampler.isRunning, isTrue);

    sampler.stop();
    expect(sampler.isRunning, isFalse);
  });

  test('stop is idempotent when not running', () {
    final sampler = BatterySampler.instance;
    sampler.stop();
    sampler.stop();
    expect(sampler.isRunning, isFalse);
  });

  test('start while running is a no-op (no double timer)', () {
    final sampler = BatterySampler.instance;
    sampler.start('Cricket');
    sampler.start('X01');
    expect(sampler.isRunning, isTrue);
    sampler.stop();
  });
}
