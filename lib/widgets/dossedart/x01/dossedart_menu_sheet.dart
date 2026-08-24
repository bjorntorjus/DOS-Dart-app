import 'package:flutter/material.dart';
import '../../../theme/dossedart_tokens.dart';

/// In-game bottom-sheet for the DOSSEDART theme (design A, 2026-08-24):
/// PLAYERS · ADD / REMOVE promoted to a bordered card on top (with active
/// count), the four toggles grouped under AUDIO & FX, meme sub-settings
/// (frequency + offensive) inline while MEMES is on, a SHOT CLOCK toggle,
/// and EXIT MATCH at the bottom.
///
/// State is loaded once on open via the `initial*` flags; changes fire
/// `onXChanged(newValue)` so the host can update both service singletons and
/// persisted prefs.
class DossedartMenuSheet extends StatefulWidget {
  const DossedartMenuSheet({
    super.key,
    required this.initialSound,
    required this.initialVideo,
    required this.initialMemes,
    required this.initialTts,
    required this.initialMemeFrequency,
    required this.initialOffensive,
    required this.initialShotClock,
    required this.shotClockSeconds,
    this.activePlayerCount,
    required this.onSoundChanged,
    required this.onVideoChanged,
    required this.onMemesChanged,
    required this.onTtsChanged,
    required this.onMemeFrequencyChanged,
    required this.onOffensiveChanged,
    required this.onShotClockChanged,
    required this.onPlayerOverview,
    required this.onExit,
  });

  final bool initialSound;
  final bool initialVideo;
  final bool initialMemes;
  final bool initialTts;

  /// Classic 1-10 scale (see the classic slider) — the chips only WRITE the
  /// five representative values, but any stored value selects its bucket.
  final int initialMemeFrequency;
  final bool initialOffensive;
  final bool initialShotClock;
  final int shotClockSeconds;

  /// Shown as "N ACTIVE" on the players card; null hides the counter.
  final int? activePlayerCount;

  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVideoChanged;
  final ValueChanged<bool> onMemesChanged;
  final ValueChanged<bool> onTtsChanged;
  final ValueChanged<int> onMemeFrequencyChanged;
  final ValueChanged<bool> onOffensiveChanged;
  final ValueChanged<bool> onShotClockChanged;
  final VoidCallback onPlayerOverview;
  final VoidCallback onExit;

  @override
  State<DossedartMenuSheet> createState() => _DossedartMenuSheetState();
}

/// The five chips shown for meme frequency, mapped onto the classic 1-10
/// scale so this sheet and the classic slider edit the same setting without
/// rescaling each other's values.
const _frequencyChips = [
  (label: 'RARE', value: 1),
  (label: 'LOW', value: 3),
  (label: 'NORMAL', value: 5),
  (label: 'OFTEN', value: 8),
  (label: 'ALWAYS', value: 10),
];

/// Bucket selection mirrors the classic slider's label mapping exactly.
int _bucketValueFor(int frequency) {
  if (frequency <= 1) return 1;
  if (frequency <= 3) return 3;
  if (frequency <= 6) return 5;
  if (frequency <= 8) return 8;
  return 10;
}

class _DossedartMenuSheetState extends State<DossedartMenuSheet> {
  late bool _sound = widget.initialSound;
  late bool _video = widget.initialVideo;
  late bool _memes = widget.initialMemes;
  late bool _tts = widget.initialTts;
  late int _frequency = widget.initialMemeFrequency;
  late bool _offensive = widget.initialOffensive;
  late bool _shotClock = widget.initialShotClock;

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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _playersCard(),
          _sectionLabel('AUDIO & FX'),
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
            icon: Icons.record_voice_over,
            label: 'VOICE (TTS)',
            value: _tts,
            onChanged: () => _toggle(
              current: _tts,
              onChanged: widget.onTtsChanged,
              localApply: (v) => _tts = v,
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
          if (_memes) ...[
            _frequencyRow(),
            _offensiveRow(),
          ],
          _divider(),
          _shotClockRow(),
          _divider(),
          _ActionRow(
            icon: Icons.exit_to_app,
            iconColor: DossedartTokens.red,
            label: 'EXIT MATCH',
            labelColor: DossedartTokens.red,
            onTap: widget.onExit,
          ),
        ],
      ),
    );
  }

  Widget _playersCard() {
    const green = DossedartTokens.green;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: green, width: 2),
        color: green.withValues(alpha: 0.07),
      ),
      child: InkWell(
        onTap: widget.onPlayerOverview,
        // 12px margin + 2px border + 4px padding = the same x=18 icon column
        // as the plain rows below.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 26,
                child: Icon(Icons.person_add_alt_1, color: green, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'PLAYERS · ADD / REMOVE',
                  style: TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (widget.activePlayerCount != null) ...[
                Text(
                  '${widget.activePlayerCount} ACTIVE',
                  style: TextStyle(
                    fontFamily: 'VT323',
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, color: green, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 8,
          color: Colors.white.withValues(alpha: 0.45),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _frequencyRow() {
    final selected = _bucketValueFor(_frequency);
    return Padding(
      padding: const EdgeInsets.fromLTRB(58, 4, 18, 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              'FREQUENCY',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final chip in _frequencyChips)
                  _FrequencyChip(
                    label: chip.label,
                    selected: chip.value == selected,
                    onTap: () {
                      setState(() => _frequency = chip.value);
                      widget.onMemeFrequencyChanged(chip.value);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offensiveRow() {
    return InkWell(
      onTap: () => _toggle(
        current: _offensive,
        onChanged: widget.onOffensiveChanged,
        localApply: (v) => _offensive = v,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(58, 8, 18, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'OFFENSIVE',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 8,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 1,
                ),
              ),
            ),
            _Pill(on: _offensive),
          ],
        ),
      ),
    );
  }

  Widget _shotClockRow() {
    return InkWell(
      onTap: () => _toggle(
        current: _shotClock,
        onChanged: widget.onShotClockChanged,
        localApply: (v) => _shotClock = v,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 26,
              child: Icon(Icons.timer_outlined,
                  color: DossedartTokens.cyan, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'SHOT CLOCK',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 11,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Text(
              '${widget.shotClockSeconds}S',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 10),
            _Pill(on: _shotClock),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const yellow = DossedartTokens.yellow;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? yellow : Colors.white.withValues(alpha: 0.25),
            width: selected ? 2 : 1,
          ),
          color: selected ? yellow.withValues(alpha: 0.12) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 16,
            height: 1,
            letterSpacing: 1,
            color: selected ? yellow : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
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
