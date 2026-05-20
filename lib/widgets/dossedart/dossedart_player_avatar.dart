import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Square avatar with a 2-3px player-color border. Shows the photo
/// when available, falls back to an Icons.person silhouette.
///
/// Used by the DOSSEDART cockpit active card and Player Overview rows.
/// Square shape and the per-player border colour are the DOSSEDART
/// look — different from the round CircleAvatar that `PlayerAvatar` uses.
class DossedartPlayerAvatar extends StatelessWidget {
  const DossedartPlayerAvatar({
    super.key,
    required this.name,
    required this.size,
    required this.borderColor,
    this.avatarPath,
    this.borderWidth = 3,
  });

  final String name;
  final double size;
  final Color borderColor;
  final String? avatarPath;
  final double borderWidth;

  bool _hasPhoto() {
    if (avatarPath == null || avatarPath!.isEmpty || kIsWeb) return false;
    return File(avatarPath!).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2A0050),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.5),
            blurRadius: 8,
          ),
        ],
      ),
      child: _hasPhoto()
          ? Image.file(File(avatarPath!), fit: BoxFit.cover)
          : Center(
              child: Icon(
                Icons.person,
                size: size * 0.6,
                color: Colors.white,
              ),
            ),
    );
  }
}
