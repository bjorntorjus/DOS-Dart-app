import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class PlayerAvatar extends StatelessWidget {
  final String? avatarPath;
  final String name;
  final double radius;
  final Color? backgroundColor;

  const PlayerAvatar({
    super.key,
    this.avatarPath,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(fontSize: radius * 0.8),
    );

    if (avatarPath != null && avatarPath!.isNotEmpty && !kIsWeb) {
      final file = File(avatarPath!);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
          backgroundImage: FileImage(file),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[700],
      child: initial,
    );
  }
}
