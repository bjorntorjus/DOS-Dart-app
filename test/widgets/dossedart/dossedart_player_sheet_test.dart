import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/models/saved_player.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_player_sheet.dart';

SavedPlayer _saved(String id, String name) =>
    SavedPlayer(id: id, name: name, createdAt: DateTime(2020));

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  List<DossedartStandingRow> threeActive() => const [
        DossedartStandingRow(
            playerIndex: 0,
            name: 'Ada',
            avatarPath: null,
            isActive: true,
            isRemoved: false,
            primary: '251'),
        DossedartStandingRow(
            playerIndex: 1,
            name: 'Bo',
            avatarPath: null,
            isActive: false,
            isRemoved: false,
            primary: '300'),
        DossedartStandingRow(
            playerIndex: 2,
            name: 'Cy',
            avatarPath: null,
            isActive: false,
            isRemoved: false,
            primary: '180'),
      ];

  testWidgets('renders title, each row name + primary', (tester) async {
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: threeActive(),
      gameOver: false,
      available: const [],
      onAdd: (_) {},
      onRemove: (_) {},
    )));
    expect(find.text('PLAYER OVERVIEW'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('251'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
  });

  testWidgets('REMOVE fires onRemove with playerIndex when >2 active',
      (tester) async {
    int? removed;
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: threeActive(),
      gameOver: false,
      available: const [],
      onAdd: (_) {},
      onRemove: (i) => removed = i,
    )));
    await tester.tap(find.text('REMOVE').first);
    expect(removed, 0);
  });

  testWidgets('REMOVE disabled when only 2 active', (tester) async {
    int? removed;
    final rows = const [
      DossedartStandingRow(
          playerIndex: 0,
          name: 'Ada',
          avatarPath: null,
          isActive: true,
          isRemoved: false,
          primary: '1'),
      DossedartStandingRow(
          playerIndex: 1,
          name: 'Bo',
          avatarPath: null,
          isActive: false,
          isRemoved: false,
          primary: '2'),
    ];
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: rows,
      gameOver: false,
      available: const [],
      onAdd: (_) {},
      onRemove: (i) => removed = i,
    )));
    await tester.tap(find.text('REMOVE').first);
    expect(removed, isNull);
  });

  testWidgets('removed row shows REMOVED tag and no REMOVE action',
      (tester) async {
    final rows = const [
      DossedartStandingRow(
          playerIndex: 0,
          name: 'Ada',
          avatarPath: null,
          isActive: true,
          isRemoved: false,
          primary: '1'),
      DossedartStandingRow(
          playerIndex: 1,
          name: 'Bo',
          avatarPath: null,
          isActive: false,
          isRemoved: false,
          primary: '2'),
      DossedartStandingRow(
          playerIndex: 2,
          name: 'Cy',
          avatarPath: null,
          isActive: false,
          isRemoved: true,
          primary: '0'),
    ];
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: rows,
      gameOver: false,
      available: const [],
      onAdd: (_) {},
      onRemove: (_) {},
    )));
    expect(find.text('REMOVED'), findsOneWidget);
    // 2 active rows -> 2 REMOVE buttons (removed row has none)
    expect(find.text('REMOVE'), findsNWidgets(2));
  });

  testWidgets('empty available shows empty-state; populated fires onAdd',
      (tester) async {
    SavedPlayer? added;
    await tester.pumpWidget(_host(DossedartPlayerSheet(
      rows: threeActive(),
      gameOver: false,
      available: [_saved('x', 'Zed')],
      onAdd: (sp) => added = sp,
      onRemove: (_) {},
    )));
    expect(find.text('Zed'), findsOneWidget);
    await tester.tap(find.text('Zed'));
    expect(added?.id, 'x');
  });
}
