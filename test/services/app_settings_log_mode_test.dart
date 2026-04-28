import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_scoring/services/app_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default log mode is full', () async {
    expect(await AppSettings.getLogMode(), LogMode.full);
  });

  test('persists log mode across reads', () async {
    await AppSettings.setLogMode(LogMode.minimal);
    expect(await AppSettings.getLogMode(), LogMode.minimal);

    await AppSettings.setLogMode(LogMode.off);
    expect(await AppSettings.getLogMode(), LogMode.off);
  });
}
