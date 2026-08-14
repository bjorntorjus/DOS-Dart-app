import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dart_scoring/widgets/continue_prompt_dialog.dart';

void main() {
  Future<bool?> open(WidgetTester tester,
      {required bool dossedart, String verb = 'FINISHED'}) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(
              context,
              finisherName: 'Kristian',
              remainingCount: 2,
              dossedart: dossedart,
              finishVerb: verb,
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('DOSSEDART: shows finisher, count, and both actions',
      (tester) async {
    await open(tester, dossedart: true, verb: 'CHECKED OUT');
    expect(find.text('★ KRISTIAN CHECKED OUT ★'), findsOneWidget);
    expect(find.text('2 PLAYERS CAN STILL PLAY FOR THE PLACES'), findsOneWidget);
    expect(find.text('KEEP PLAYING'), findsOneWidget);
    expect(find.text('END GAME'), findsOneWidget);
  });

  testWidgets('KEEP PLAYING returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 2, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('END GAME returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 2, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('END GAME'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('tapping outside the dialog returns true (safe default)',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 2, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('classic variant renders an AlertDialog with sentence copy',
      (tester) async {
    await open(tester, dossedart: false, verb: 'CHECKED OUT');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Kristian checked out!'), findsOneWidget);
    expect(
        find.text('2 players can still play for the places.'), findsOneWidget);
    expect(find.text('Keep playing'), findsOneWidget);
    expect(find.text('End game'), findsOneWidget);
  });

  testWidgets('singular copy for one remaining player', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showContinuePrompt(context,
                finisherName: 'A', remainingCount: 1, dossedart: true);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 PLAYER CAN STILL PLAY FOR THE PLACES'), findsOneWidget);
    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
