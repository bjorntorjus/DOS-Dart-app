import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/arcade_frame.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_crt_frame.dart';

void main() {
  setUp(() {
    ArcadeFrame.disableBeamForTest = true;
  });
  tearDown(() {
    // Reset to the new global baseline (set by test/flutter_test_config.dart),
    // not the pre-F18 default, so we don't leak an active beam timer into
    // later tests in this file's run.
    ArcadeFrame.disableBeamForTest = true;
  });

  testWidgets('renders child without throwing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DossedartCrtFrame(
        child: Text('inner'),
      ),
    ));
    expect(find.text('inner'), findsOneWidget);
    expect(find.byType(ArcadeFrame), findsOneWidget);
  });
}
