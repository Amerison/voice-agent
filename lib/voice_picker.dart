import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// Active Vapi voices. Previews are Vapi's published samples
/// (github.com/VapiAI/docs, MIT), bundled in assets/voices/ by lowercase id.
const agentVoices = [
  (id: 'Elliot', tone: 'Calm, professional'),
  (id: 'Clara', tone: 'Clear, professional'),
  (id: 'Savannah', tone: 'Bright, friendly'),
  (id: 'Kai', tone: 'Relaxed, helpful'),
];

/// Inline list of [agentVoices]; tapping a row selects it and plays its
/// sample, tapping the playing voice stops it.
class VoicePicker extends StatefulWidget {
  const VoicePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  State<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<VoicePicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  AudioPlayer? _player;
  String? _playing;

  @override
  void dispose() {
    _wave.dispose();
    _player?.dispose();
    super.dispose();
  }

  void _setPlaying(String? id) {
    setState(() => _playing = id);
    if (id != null && !MediaQuery.of(context).disableAnimations) {
      _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  Future<void> _toggle(String id) async {
    final start = _playing != id;
    widget.onChanged(id);
    _setPlaying(start ? id : null);
    try {
      final player = _player ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          if (mounted) _setPlaying(null);
        });
      await player.stop();
      if (start) {
        await player.play(AssetSource('voices/${id.toLowerCase()}.m4a'));
      }
    } catch (error) {
      debugPrint('Voice preview failed: $error');
      if (mounted && _playing == id) _setPlaying(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HubGroup(
      children: [
        for (final voice in agentVoices)
          _VoiceRow(
            id: voice.id,
            tone: voice.tone,
            animation: _wave,
            selected: voice.id == widget.selected,
            playing: voice.id == _playing,
            onTap: () => _toggle(voice.id),
          ),
      ],
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.id,
    required this.tone,
    required this.animation,
    required this.selected,
    required this.playing,
    required this.onTap,
  });

  final String id;
  final String tone;
  final Animation<double> animation;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$id voice, $tone',
      hint: playing ? 'Stops the sample' : 'Selects and plays a sample',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              VoiceGlyph(
                animation: animation,
                selected: selected,
                playing: playing,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(id, style: const TextStyle(fontSize: 16)),
                    Text(
                      tone,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: HubColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                playing
                    ? CupertinoIcons.stop_circle
                    : CupertinoIcons.play_circle,
                size: 22,
                color: HubColors.textMuted,
              ),
              const SizedBox(width: 10),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 20,
                  color: HubColors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four-bar waveform badge; the bars move while [playing].
class VoiceGlyph extends StatelessWidget {
  const VoiceGlyph({
    super.key,
    required this.animation,
    required this.selected,
    required this.playing,
  });

  final Animation<double> animation;
  final bool selected;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: selected ? HubColors.orange : HubColors.background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var bar = 0; bar < 4; bar++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 3,
                height: playing
                    ? 7 +
                          (math.sin(
                                    animation.value * math.pi * 24 + bar * 1.3,
                                  ) +
                                  1) *
                              6
                    : const [8.0, 14.0, 10.0, 6.0][bar],
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : HubColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
