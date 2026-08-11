import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/backup_service.dart';

/// Settings entry point for the full-data export.
///
/// Owns its own "last exported" state rather than having the Settings screen
/// thread it through: the date is read and written in one place, and the tile
/// can be pumped on its own without booting a screen whose `_load()` waits on
/// TTS platform channels.
///
/// Showing the date matters as much as the button — a backup you cannot date
/// is a backup you cannot trust.
class BackupTile extends StatefulWidget {
  const BackupTile({super.key});

  @override
  State<BackupTile> createState() => _BackupTileState();
}

class _BackupTileState extends State<BackupTile> {
  DateTime? _lastBackupAt;
  bool _busy = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    AppSettings.getLastBackupAt().then((v) {
      if (mounted) setState(() => _lastBackupAt = v);
    });
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _export() async {
    // Guard against a double tap kicking off two share sheets.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await BackupService.exportAndShare();
      final stamped = await AppSettings.getLastBackupAt();
      if (mounted) setState(() => _lastBackupAt = stamped);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final at = _lastBackupAt;
    return ListTile(
      leading: const Icon(Icons.save_alt),
      title: const Text('Export backup'),
      subtitle: Text(
        at == null
            ? 'Players, game history and settings as one file'
            : 'Last exported ${_formatDate(at)}',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _busy ? null : _export,
    );
  }
}
