import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const DartScoringApp(useDossedartDesign: false));
    expect(find.text('Dart Scorer'), findsOneWidget);
    expect(find.text('301'), findsOneWidget);
  });
}
