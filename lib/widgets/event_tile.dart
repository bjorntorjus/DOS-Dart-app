import 'package:flutter/material.dart';

import '../models/event.dart';
import '../services/backup_service.dart';
import '../services/event_service.dart';

/// Settings entry point for rating events (party nights on their own table).
///
/// Owns its own state like BackupTile: reads EventService.active, starts and
/// ends events, and re-renders itself — the Settings screen just places it.
class EventTile extends StatefulWidget {
  const EventTile({super.key});

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _busy = false;
  int? _games;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _refreshGames();
  }

  Future<void> _refreshGames() async {
    final live = await EventService.livePreview();
    if (!mounted) return;
    setState(
        () => _games = live?.rows.fold<int>(0, (n, r) => n + r.games));
  }

  String _started(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _start() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Start event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Event name'),
                onChanged: (_) => setLocal(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Everyone starts at 1200. Games count for stats and '
                'achievements but not for the season. A backup is written first.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;
    await _run(() => EventService.start(name));
  }

  Future<void> _end(EventRecord open) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End ${open.name}?'),
        content: const Text(
            'Season ratings are restored and the table is archived under '
            'Stats › Seasons.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(EventService.end);
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() => _busy = true);
    try {
      await op();
      await _refreshGames();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Event failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final open = EventService.active;

    if (open == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A party night on its own rating table. Everyone starts at '
                '1200; the season is not affected.',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.celebration),
                label: const Text('Start event'),
              ),
            ],
          ),
        ),
      );
    }

    final openFor = DateTime.now().difference(open.start);
    final stale = openFor.inHours >= 24;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(open.name.toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'started ${_started(open.start)}'
              '${_games == null ? '' : ' · $_games games'}'
              '${stale ? ' · open for ${openFor.inDays} days' : ''}',
              style: TextStyle(
                  fontSize: 13,
                  color: stale
                      ? cs.secondary
                      : cs.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _end(open),
                  icon: const Icon(Icons.flag),
                  label: const Text('End event'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _run(BackupService.exportAndShare),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share backup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
