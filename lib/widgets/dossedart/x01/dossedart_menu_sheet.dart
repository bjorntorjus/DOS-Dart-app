import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// In-game bottom-sheet for the DOSSEDART theme: toggles for sound/video/
/// memes/TTS plus player-overview and exit actions.
///
/// Toggle state is loaded once on open via the four `initial*` flags; flips
/// fire `onXChanged(newValue)` so the host can update both service singletons
/// and persisted prefs.
class DossedartMenuSheet extends StatefulWidget {
  const DossedartMenuSheet({
    super.key,
    required this.initialSound,
    required this.initialVideo,
    required this.initialMemes,
    required this.initialTts,
    required this.onSoundChanged,
    required this.onVideoChanged,
    required this.onMemesChanged,
    required this.onTtsChanged,
    required this.onPlayerOverview,
    required this.onExit,
  });

  final bool initialSound;
  final bool initialVideo;
  final bool initialMemes;
  final bool initialTts;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVideoChanged;
  final ValueChanged<bool> onMemesChanged;
  final ValueChanged<bool> onTtsChanged;
  final VoidCallback onPlayerOverview;
  final VoidCallback onExit;

  @override
  State<DossedartMenuSheet> createState() => _DossedartMenuSheetState();
}

class _DossedartMenuSheetState extends State<DossedartMenuSheet> {
  late bool _sound = widget.initialSound;
  late bool _video = widget.initialVideo;
  late bool _memes = widget.initialMemes;
  late bool _tts = widget.initialTts;

  void _toggle({
    required bool current,
    required ValueChanged<bool> onChanged,
    required void Function(bool) localApply,
  }) {
    final next = !current;
    localApply(next);
    setState(() {});
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _ToggleRow(
          icon: Icons.volume_up,
          label: 'SOUND',
          value: _sound,
          onChanged: () => _toggle(
            current: _sound,
            onChanged: widget.onSoundChanged,
            localApply: (v) => _sound = v,
          ),
        ),
        _ToggleRow(
          icon: Icons.movie,
          label: 'VIDEO EVENTS',
          value: _video,
          onChanged: () => _toggle(
            current: _video,
            onChanged: widget.onVideoChanged,
            localApply: (v) => _video = v,
          ),
        ),
        _ToggleRow(
          icon: Icons.emoji_emotions,
          label: 'MEMES',
          value: _memes,
          onChanged: () => _toggle(
            current: _memes,
            onChanged: widget.onMemesChanged,
            localApply: (v) => _memes = v,
          ),
        ),
        _ToggleRow(
          icon: Icons.record_voice_over,
          label: 'VOICE (TTS)',
          value: _tts,
          onChanged: () => _toggle(
            current: _tts,
            onChanged: widget.onTtsChanged,
            localApply: (v) => _tts = v,
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.fromLTRB(18, 4, 18, 4),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        _ActionRow(
          icon: Icons.scoreboard,
          iconColor: DossedartTokens.cyan,
          label: 'PLAYER OVERVIEW',
          labelColor: Colors.white,
          onTap: widget.onPlayerOverview,
        ),
        _ActionRow(
          icon: Icons.exit_to_app,
          iconColor: DossedartTokens.red,
          label: 'EXIT MATCH',
          labelColor: DossedartTokens.red,
          onTap: widget.onExit,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Icon(icon, color: DossedartTokens.cyan, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            _Pill(on: value),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: on
              ? DossedartTokens.green
              : Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
        color: on
            ? DossedartTokens.green.withValues(alpha: 0.18)
            : Colors.transparent,
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            left: on ? null : 2,
            right: on ? 2 : null,
            top: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on
                    ? DossedartTokens.green
                    : Colors.white.withValues(alpha: 0.5),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: DossedartTokens.green.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: labelColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: labelColor.withValues(alpha: 0.6), size: 18),
          ],
        ),
      ),
    );
  }
}
