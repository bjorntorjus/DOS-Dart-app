import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring/widgets/dossedart/dossedart_player_avatar.dart';

void main() {
  testWidgets('shows Icons.person silhouette when avatarPath is null',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartPlayerAvatar(
          name: 'TEST',
          avatarPath: null,
          size: 56,
          borderColor: Color(0xFFFF00AA),
        ),
      ),
    ));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('shows Icons.person silhouette when avatarPath does not exist',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: DossedartPlayerAvatar(
          name: 'TEST',
          avatarPath: '/nonexistent/path/to/file.jpg',
          size: 56,
          borderColor: Color(0xFFFF00AA),
        ),
      ),
    ));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
