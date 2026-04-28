import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/battery_sampler.dart';

void main() {
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
