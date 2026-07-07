import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/active_player_highlight.dart';

/// F23 (audit 2026-07-06): the color spec mandates a 2px primary border for
/// the active player; the shared ring silently defaulted to 3px.
void main() {
  group('ActivePlayerHighlight', () {
    testWidgets('active ring defaults to a 2px border', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ActivePlayerHighlight(isActive: true, child: SizedBox()),
      ));
      final container = tester.widget<Container>(find.byType(Container).first);
      final border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.width, 2);
    });

    testWidgets('renders the child unchanged when isActive=false', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivePlayerHighlight(
            isActive: false,
            child: const Text('hello'),
          ),
        ),
      ));
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('renders a bordered container when isActive=true', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActivePlayerHighlight(
            isActive: true,
            child: const Text('hello'),
          ),
        ),
      ));
      expect(find.text('hello'), findsOneWidget);
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasBordered = containers.any((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.border != null;
      });
      expect(hasBordered, isTrue,
          reason: 'expected an active-state Container with a border');
    });

    testWidgets('does not shift layout between active and inactive', (tester) async {
      Future<Size> renderSize(bool active) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: ActivePlayerHighlight(
                isActive: active,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ));
        return tester.getSize(find.byType(ActivePlayerHighlight));
      }
      final inactive = await renderSize(false);
      final active = await renderSize(true);
      expect(active, inactive,
          reason: 'wrapper must reserve same size in both states '
              'so layout does not shift when active player changes');
    });
  });
}
