import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/screens/season_migration_screen.dart';
import 'package:dart_scoring/services/app_settings.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/season_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('season_migration_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    BackupService.disableShareForTest = false;
    // Best-effort: Windows can still hold a handle on the written file.
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(MaterialApp(home: SeasonMigrationScreen(onDone: () {})));
    await tester.pumpAndSettle();
  }

  testWidgets('without a backup, only the export is offered', (tester) async {
    await open(tester);

    expect(find.text('EXPORT BACKUP'), findsOneWidget);
    expect(find.textContaining('Export a backup first'), findsOneWidget);

    // START SEASONS is rendered but inert.
    await tester.tap(find.text('START SEASONS'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(await SeasonService.needsMigration(), isTrue);
  });

  testWidgets('with a backup, the migration can run', (tester) async {
    await AppSettings.setLastBackupAt(DateTime(2026, 8, 11));
    await open(tester);

    expect(find.textContaining('Export a backup first'), findsNothing);

    await tester.tap(find.text('START SEASONS'));
    await tester.pumpAndSettle();

    expect(await SeasonService.needsMigration(), isFalse);
  });

  testWidgets('exporting from this screen unlocks the migration',
      (tester) async {
    await open(tester);
    expect(find.textContaining('Export a backup first'), findsOneWidget);

    // Real file IO does not complete inside pumpAndSettle's fake-async zone.
    await tester.runAsync(() async {
      await tester.tap(find.text('EXPORT BACKUP'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.textContaining('Export a backup first'), findsNothing);
  });

  testWidgets('the copy says what happens to stats and achievements',
      (tester) async {
    await open(tester);
    expect(
        find.textContaining(
            'Your games, stats and achievements are not affected'),
        findsOneWidget);
  });
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}
