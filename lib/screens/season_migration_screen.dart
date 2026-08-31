import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/backup_service.dart';
import '../services/season_service.dart';
import '../theme/dossedart_tokens.dart';
import '../widgets/dossedart/dossedart_crt_frame.dart';

/// One-time gate shown at app start before seasons exist.
///
/// The migration rewrites every player's rating and there is no import to
/// undo it, so the screen offers only "EXPORT BACKUP" until a backup has
/// actually been taken. That friction is the point, and the copy says why
/// rather than hiding it behind a disabled button with no explanation.
class SeasonMigrationScreen extends StatefulWidget {
  const SeasonMigrationScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SeasonMigrationScreen> createState() => _SeasonMigrationScreenState();
}

class _SeasonMigrationScreenState extends State<SeasonMigrationScreen> {
  DateTime? _lastBackupAt;
  bool _busy = false;

  bool get _canMigrate => _lastBackupAt != null;

  @override
  void initState() {
    super.initState();
    AppSettings.getLastBackupAt().then((v) {
      if (mounted) setState(() => _lastBackupAt = v);
    });
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BackupService.exportAndShare();
      final at = await AppSettings.getLastBackupAt();
      if (mounted) setState(() => _lastBackupAt = at);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _migrate() async {
    if (_busy || !_canMigrate) return;
    setState(() => _busy = true);
    try {
      await SeasonService.migrate();
      widget.onDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DossedartCrtFrame(
      child: Scaffold(
        backgroundColor: DossedartTokens.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Text('SEASONS',
                    textAlign: TextAlign.center,
                    style: _ps(20, DossedartTokens.yellow, 4)),
                const SizedBox(height: 26),
                Text(
                  'Ratings become quarterly. Everything played so far becomes '
                  'Season 1, and this quarter becomes Season 2. Your games, '
                  'stats and achievements are not affected.',
                  textAlign: TextAlign.center,
                  style: _vt(20, Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 22),
                if (!_canMigrate)
                  Text(
                    'Export a backup first — this rewrites every rating and '
                    'cannot be undone.',
                    textAlign: TextAlign.center,
                    style: _vt(19, DossedartTokens.orange),
                  ),
                const Spacer(),
                _button(
                  label: 'EXPORT BACKUP',
                  color: DossedartTokens.cyan,
                  enabled: !_busy,
                  onTap: _export,
                ),
                const SizedBox(height: 12),
                _button(
                  label: 'START SEASONS',
                  color: DossedartTokens.lime,
                  enabled: _canMigrate && !_busy,
                  primary: true,
                  onTap: _migrate,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dimmed rather than removed, matching the post-game action bar: a control
  /// that vanishes moves everything below it, and a user who looked away
  /// loses their place.
  Widget _button({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final body = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: primary ? color : Colors.transparent,
        border: Border.all(color: primary ? Colors.white : color, width: 2),
      ),
      child: Text(label,
          style: _ps(12, primary ? DossedartTokens.bg : color, 2)),
    );
    if (!enabled) return Opacity(opacity: 0.28, child: body);
    return GestureDetector(onTap: onTap, child: body);
  }
}

TextStyle _ps(double size, Color color, [double letterSpacing = 1]) =>
    TextStyle(
      fontFamily: 'PressStart2P',
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.5,
    );

TextStyle _vt(double size, Color color) => TextStyle(
      fontFamily: 'VT323',
      fontSize: size,
      color: color,
      letterSpacing: 1,
      height: 1.25,
    );
