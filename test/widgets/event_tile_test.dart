import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/services/backup_service.dart';
import 'package:dart_scoring/services/event_service.dart';
import 'package:dart_scoring/services/player_storage.dart';
import 'package:dart_scoring/widgets/event_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EventService.resetForTest();
    BackupService.disableShareForTest = true;
    tempDir = await Directory.systemTemp.createTemp('event_tile');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await PlayerStorage.savePlayers([
      SavedPlayer(id: 'a', name: 'Ada', createdAt: DateTime(2026), rating: 1310),
    ]);
  });
  tearDown(() async {
    EventService.resetForTest();
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: EventTile())));
    await t.pumpAndSettle();
  }

  testWidgets(
      'idle: Start event opens a dialog; blank name keeps Start disabled',
      (tester) async {
    await pump(tester);
    expect(find.text('Start event'), findsOneWidget);
    expect(find.text('End event'), findsNothing);

    // The whole dialog flow runs under runAsync: EventService.start writes a
    // backup file — real I/O that never completes under the test binding's
    // fake async — and the continuation after `await showDialog` inherits the
    // zone the dialog was opened in.
    await tester.runAsync(() async {
      await tester.tap(find.text('Start event'));
      await tester.pump();
      final start = find.widgetWithText(FilledButton, 'Start');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Jobbfest 2026');
      await tester.pump();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

      await tester.tap(start);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(EventService.active?.name, 'Jobbfest 2026');
    expect(find.text('JOBBFEST 2026'), findsOneWidget);
    expect(find.text('End event'), findsOneWidget);
    expect((await PlayerStorage.loadPlayers()).single.rating, 1200);
  });

  testWidgets(
      'open: End event confirms, then restores ratings and returns to idle',
      (tester) async {
    await tester.runAsync(() => EventService.start('Jobbfest 2026'));
    await pump(tester);
    expect(find.text('JOBBFEST 2026'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('End event'));
      await tester.pump();
      expect(find.textContaining('End Jobbfest 2026?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'End'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(EventService.active, isNull);
    expect(find.text('Start event'), findsOneWidget);
    expect((await PlayerStorage.loadPlayers()).single.rating, 1310);
  });

  testWidgets('open for more than a day shows the reminder', (tester) async {
    await tester.runAsync(() => EventService.start('Jobbfest 2026',
        now: DateTime.now().subtract(const Duration(days: 2))));
    await pump(tester);
    expect(find.textContaining('open for 2 days'), findsOneWidget);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
