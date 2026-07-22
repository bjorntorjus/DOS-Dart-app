import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/services/video_service.dart';

/// F18 (audit 2026-07-06): VideoService is enabled by default and its
/// prefs re-read can re-enable it mid-test. The static test flag must
/// short-circuit showing regardless of _enabled.
void main() {
  testWidgets('disableForTest suppresses the overlay even when enabled',
      (tester) async {
    VideoService.instance.setEnabled(true);
    VideoService.disableForTest = true;
    addTearDown(() => VideoService.disableForTest = true);

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    await VideoService.instance.showRandomFromFolder(ctx, 'winner');
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
