import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import '../../services/achievement_service.dart';
import '../../theme/dossedart_tokens.dart';
import 'achievement_medal.dart';

/// Passive top-dropdown banner content for a single unlock. Non-interactive.
class AchievementBanner extends StatelessWidget {
  const AchievementBanner({super.key, required this.unlock});
  final AchievementUnlock unlock;

  @override
  Widget build(BuildContext context) {
    final a = unlock.achievement;
    final tier = AchievementMedal.tierColor(a.tier);
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: DossedartTokens.surface.withValues(alpha: 0.95),
          border: Border.all(color: tier, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementMedal(achievement: a, size: 40),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${unlock.player.name} unlocked',
                    style: const TextStyle(
                      color: DossedartTokens.phosphor,
                      fontSize: 9,
                      fontFamily: 'PressStart2P',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    a.name,
                    style: TextStyle(
                      color: tier,
                      fontSize: 12,
                      fontFamily: 'PressStart2P',
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App-wide host that shows queued unlock banners at the top, ~[display] each,
/// never blocking input. Wrap the app (via MaterialApp `builder`) with this.
class AchievementOverlayHost extends StatefulWidget {
  const AchievementOverlayHost({
    super.key,
    required this.child,
    this.stream,
    this.display = const Duration(seconds: 3),
  });

  final Widget child;

  /// Defaults to `AchievementService.instance.unlocks`. Injectable for tests.
  final Stream<AchievementUnlock>? stream;
  final Duration display;

  @override
  State<AchievementOverlayHost> createState() => _AchievementOverlayHostState();
}

class _AchievementOverlayHostState extends State<AchievementOverlayHost> {
  final _queue = <AchievementUnlock>[];
  AchievementUnlock? _current;
  StreamSubscription<AchievementUnlock>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final stream = widget.stream ?? AchievementService.instance.unlocks;
    _sub = stream.listen(_enqueue);
  }

  void _enqueue(AchievementUnlock u) {
    _queue.add(u);
    if (_current == null) _showNext();
  }

  void _showNext() {
    _timer?.cancel();
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    setState(() => _current = _queue.removeAt(0));
    _timer = Timer(widget.display, _showNext);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AchievementBanner(unlock: _current!),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
