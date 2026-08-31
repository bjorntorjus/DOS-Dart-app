import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/widgets/backup_tile.dart';

/// The tile is tested on its own rather than through SettingsScreen: that
/// screen's `_load()` awaits TTS platform channels that never resolve under
/// `flutter_test`, so pumping the whole screen hangs in pumpAndSettle. The
/// tile owning its own state is what makes this possible.
void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('settings_backup_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    BackupService.disableShareForTest = false;
    // Best-effort: Windows keeps a handle on the just-written file long
    // enough that the delete can fail, and a failed cleanup must not fail
    // the test that already passed.
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BackupTile())));
    await tester.pumpAndSettle();
  }

  testWidgets('offers an export, and says it has never run', (tester) async {
    await open(tester);

    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Players, game history and settings as one file'),
        findsOneWidget);
  });

  /// The export does real file IO, which does not complete inside
  /// `pumpAndSettle`'s fake-async zone — hence `runAsync`. Without it the
  /// busy spinner animates forever and the settle times out.
  Future<void> tapExport(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Export backup'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  testWidgets('exporting records the date and shows it', (tester) async {
    await open(tester);

    await tapExport(tester);

    expect(await AppSettings.getLastBackupAt(), isNotNull);
    expect(find.textContaining('Last exported'), findsOneWidget);
    expect(find.text('Players, game history and settings as one file'),
        findsNothing);
  });

  testWidgets('an existing backup date is shown on first build',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'last_backup_at': DateTime(2026, 3, 9).toIso8601String()});

    await open(tester);

    expect(find.text('Last exported 9 Mar 2026'), findsOneWidget);
  });

  testWidgets('a double tap does not start two exports', (tester) async {
    await open(tester);

    // Tap twice without letting the first finish: the second must find the
    // tile disabled rather than opening a second share sheet.
    await tester.runAsync(() async {
      await tester.tap(find.text('Export backup'));
      await tester.pump();
      await tester.tap(find.text('Export backup'), warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.textContaining('Last exported'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}
