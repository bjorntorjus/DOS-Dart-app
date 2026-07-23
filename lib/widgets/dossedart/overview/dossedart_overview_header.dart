import 'dart:math';
import 'package:flutter/material.dart';
import '../dossedart_player_avatar.dart';

/// Grammar rule 4 header, shared by every DOSSEDART overview card:
/// 56px photo avatar (silhouette fallback) · name on the X01 length→size
/// curve · three 9px dart pips + `DART n/3` where n is the dart being
/// thrown (grammar decision 2026-07-22 — 0 thrown reads "DART 1/3").
/// [trailing] is the mode's primary-number block, right-aligned.
class DossedartOverviewHeader extends StatelessWidget {
  const DossedartOverviewHeader({
    super.key,
    required this.playerName,
    required this.avatarPath,
    required this.accent,
    required this.dartsThrown,
    this.trailing,
    this.besideName,
  });

  final String playerName;
  final String? avatarPath;
  final Color accent;
  final int dartsThrown; // 0..3
  final Widget? trailing;
  final Widget? besideName;

  double _nameFontSize() {
    final len = playerName.length;
    if (len <= 6) return 18;
    if (len <= 10) return 15;
    if (len <= 16) return 12;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final nameSize = _nameFontSize();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DossedartPlayerAvatar(
          avatarPath: avatarPath,
          size: 56,
          borderColor: accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: nameSize,
                        color: Colors.white,
                        letterSpacing: nameSize >= 15 ? 2 : 1.5,
                      ),
                    ),
                  ),
                  if (besideName != null) ...[
                    const SizedBox(width: 12),
                    besideName!,
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: i < dartsThrown ? accent : Colors.transparent,
                        border: Border.all(color: accent, width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      'DART ${min(dartsThrown + 1, 3)}/3',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'VT323',
                        fontSize: 13,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (trailing case final t?) ...[t],
      ],
    );
  }
}
