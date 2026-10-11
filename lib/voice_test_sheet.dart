import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vapi/vapi.dart';

import 'app_controller.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const _vapiPublicKey = String.fromEnvironment('VAPI_PUBLIC_KEY');

Future<void> showVoiceTestSheet(
  BuildContext context,
  AppController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VoiceTestSheet(controller: controller),
  );
}

enum _VoiceTestState {
  preparing,
  connecting,
  listening,
  speaking,
  ended,
  error,
}

class _TranscriptLine {
  const _TranscriptLine({required this.role, required this.text});

  final String role;
  final String text;
}

class _VoiceTestSheet extends StatefulWidget {
  const _VoiceTestSheet({required this.controller});

  final AppController controller;

  @override
  State<_VoiceTestSheet> createState() => _VoiceTestSheetState();
}

class _VoiceTestSheetState extends State<_VoiceTestSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  VapiClient? _client;
  VapiCall? _call;
  StreamSubscription<VapiEvent>? _events;
  _VoiceTestState _state = _VoiceTestState.preparing;
  String? _error;
  bool _muted = false;
  bool _stopping = false;
  final List<_TranscriptLine> _transcript = [];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_vapiPublicKey.trim().isEmpty) {
      _fail(
        'Vapi’s public key is missing. Add VAPI_PUBLIC_KEY to the app run configuration.',
      );
      return;
    }
    try {
      final agent = widget.controller.data.agent;
      final useSavedAssistant =
          agent.syncStatus == SyncStatus.ready &&
          agent.vapiAssistantId != null &&
          agent.vapiAssistantId!.isNotEmpty;
      if (mounted) setState(() => _state = _VoiceTestState.connecting);
      await VapiClient.platformInitialized.future;
      _client = VapiClient(_vapiPublicKey.trim());
      final call = await _client!.start(
        assistantId: useSavedAssistant ? agent.vapiAssistantId : null,
        assistant: useSavedAssistant ? null : _transientAssistant(agent),
        assistantOverrides: const {'recordingEnabled': false},
      );
      if (!mounted) {
        await call.stop();
        call.dispose();
        return;
      }

      _call = call;
      _events = call.onEvent.listen(_handleEvent);
      try {
        call.setAudioDevice(device: VapiAudioDevice.speakerphone);
      } on Object {
        // Keep the system-selected route when speakerphone is unavailable.
      }
      setState(() {
        _state = call.status == VapiCallStatus.active
            ? _VoiceTestState.listening
            : _VoiceTestState.connecting;
      });
    } on Object catch (error) {
      _fail(_friendlyError(error));
    }
  }

  void _handleEvent(VapiEvent event) {
    if (!mounted) return;
    switch (event.label) {
      case 'call-start':
        setState(() => _state = _VoiceTestState.listening);
      case 'call-end':
        setState(() => _state = _VoiceTestState.ended);
      case 'speech-start':
        setState(() => _state = _VoiceTestState.speaking);
      case 'speech-end':
        setState(() => _state = _VoiceTestState.listening);
      case 'error':
      case 'call-error':
        _fail('The voice test ended because Vapi reported an error.');
      case 'message':
        _handleMessage(event.value);
    }
  }

  void _handleMessage(dynamic value) {
    if (value is! Map) return;
    final message = Map<String, dynamic>.from(value);
    if (message['type'] == 'speech-update') {
      setState(() {
        _state = message['status'] == 'started'
            ? _VoiceTestState.speaking
            : _VoiceTestState.listening;
      });
      return;
    }
    if (message['type'] != 'transcript' ||
        message['transcriptType'] == 'partial') {
      return;
    }
    final text = message['transcript'] as String?;
    if (text == null || text.trim().isEmpty) return;
    final role = message['role'] == 'assistant'
        ? widget.controller.data.agent.name
        : 'You';
    setState(() {
      _transcript.add(_TranscriptLine(role: role, text: text.trim()));
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _state = _VoiceTestState.error;
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    if (message.isEmpty) return 'The voice test could not be started.';
    return message;
  }

  Map<String, dynamic> _transientAssistant(AgentConfig agent) {
    final shortAnswers = agent.knowledgeSources
        .where((source) => source.kind == KnowledgeKind.shortAnswer)
        .map((source) => 'Q: ${source.content}\nA: ${source.answer ?? ''}')
        .join('\n\n');
    return {
      'name': '${agent.name} voice test',
      'firstMessage': agent.greeting,
      'model': {
        'provider': 'openai',
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content':
                '''
You are ${agent.name}, ${agent.persona} for ${agent.companyName}.

COMPANY
${agent.companyDescription}

VOICE AND STYLE
- Sound ${agent.friendliness.name}, calm, concise, and conversational.
- Keep turns short, ask one question at a time, and allow interruptions.
- If asked whether you are a bot, say yes plainly.

USER GUIDELINES
${agent.guidelines}

VERIFIED SHORT ANSWERS
$shortAnswers

This is a voice test. Do not claim to create contacts or book meetings. Only answer business-specific questions from the verified material above.
'''
                    .trim(),
          },
        ],
      },
      'artifactPlan': {
        'recordingEnabled': false,
        'loggingEnabled': true,
        'transcriptPlan': {'enabled': true},
      },
      'maxDurationSeconds': 600,
    };
  }

  Future<void> _toggleMute() async {
    final call = _call;
    if (call == null || _state == _VoiceTestState.ended) return;
    final next = !_muted;
    try {
      call.setMuted(next);
      setState(() => _muted = next);
    } on Object catch (error) {
      _fail(_friendlyError(error));
    }
  }

  Future<void> _stop() async {
    if (_stopping) return;
    _stopping = true;
    final call = _call;
    if (call != null && call.status != VapiCallStatus.ended) {
      try {
        await call.stop();
      } on Object {
        // The call may already have been ended remotely.
      }
    }
    if (mounted) setState(() => _state = _VoiceTestState.ended);
    _stopping = false;
  }

  Future<void> _close() async {
    await _stop();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _retry() async {
    await _events?.cancel();
    _call?.dispose();
    _client?.dispose();
    _events = null;
    _call = null;
    _client = null;
    setState(() {
      _error = null;
      _transcript.clear();
      _state = _VoiceTestState.preparing;
    });
    await _start();
  }

  @override
  void dispose() {
    _pulse.dispose();
    unawaited(_events?.cancel());
    final call = _call;
    if (call != null && call.status != VapiCallStatus.ended) {
      unawaited(call.stop().catchError((_) {}));
    }
    call?.dispose();
    _client?.dispose();
    super.dispose();
  }

  String get _statusTitle => switch (_state) {
    _VoiceTestState.preparing => 'Preparing your agent',
    _VoiceTestState.connecting => 'Connecting…',
    _VoiceTestState.listening =>
      '${widget.controller.data.agent.name} is listening',
    _VoiceTestState.speaking =>
      '${widget.controller.data.agent.name} is speaking',
    _VoiceTestState.ended => 'Test complete',
    _VoiceTestState.error => 'Couldn’t start the test',
  };

  String get _statusDetail => switch (_state) {
    _VoiceTestState.preparing => 'Loading the latest identity and training.',
    _VoiceTestState.connecting => 'This usually takes a few seconds.',
    _VoiceTestState.listening => 'Speak naturally. Your microphone is live.',
    _VoiceTestState.speaking => 'You can interrupt at any time.',
    _VoiceTestState.ended => 'Your live Vapi session has ended.',
    _VoiceTestState.error => _error ?? 'Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    final active =
        _state == _VoiceTestState.listening ||
        _state == _VoiceTestState.speaking;
    return FractionallySizedBox(
      heightFactor: .96,
      child: Column(
        children: [
          HubSheetHeader(
            title: 'Test ${widget.controller.data.agent.name}',
            showCancel: false,
            doneLabel: 'Close',
            onDone: _close,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  const HubPill(
                    label: 'LIVE VOICE TEST',
                    tone: PillTone.accent,
                  ),
                  const Spacer(),
                  _VoicePulse(
                    animation: _pulse,
                    active: active,
                    speaking: _state == _VoiceTestState.speaking,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _statusTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusDetail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: HubColors.textMuted),
                  ),
                  const Spacer(),
                  if (_transcript.isNotEmpty)
                    _TranscriptPreview(lines: _transcript.takeLast(3).toList()),
                  if (_state == _VoiceTestState.error) ...[
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(CupertinoIcons.arrow_clockwise),
                      label: const Text('Try again'),
                    ),
                  ] else if (_state == _VoiceTestState.ended) ...[
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(CupertinoIcons.phone),
                      label: const Text('Test again'),
                    ),
                  ] else ...[
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundControl(
                          icon: _muted
                              ? CupertinoIcons.mic_slash
                              : CupertinoIcons.mic,
                          label: _muted ? 'Unmute' : 'Mute',
                          onTap: active ? _toggleMute : null,
                        ),
                        const SizedBox(width: 28),
                        _RoundControl(
                          icon: CupertinoIcons.phone_down_fill,
                          label: 'End test',
                          color: HubColors.danger,
                          onTap: _call == null ? null : _stop,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList();
    return values.skip(values.length > count ? values.length - count : 0);
  }
}

class _VoicePulse extends StatelessWidget {
  const _VoicePulse({
    required this.animation,
    required this.active,
    required this.speaking,
  });

  final Animation<double> animation;
  final bool active;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = active ? animation.value : 0.0;
        return SizedBox(
          width: 210,
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final (baseSize, opacity) in const [
                (202.0, .10),
                (166.0, .16),
                (132.0, .22),
              ])
                Container(
                  width: baseSize + progress * (speaking ? 10 : 5),
                  height: baseSize + progress * (speaking ? 10 : 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 1.5,
                      color: HubColors.orange.withValues(alpha: opacity),
                    ),
                  ),
                ),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: HubColors.breeze,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HubColors.orange.withValues(
                        alpha: active ? .24 + progress * .14 : .12,
                      ),
                      blurRadius: active ? 30 + progress * 16 : 20,
                      spreadRadius: active ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  speaking ? CupertinoIcons.waveform : CupertinoIcons.mic_fill,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TranscriptPreview extends StatelessWidget {
  const _TranscriptPreview({required this.lines});

  final List<_TranscriptLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 156),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HubColors.border),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines) ...[
              Text(
                line.role,
                style: const TextStyle(
                  fontFamily: HubFonts.mono,
                  fontSize: 11,
                  color: HubColors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(line.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (line != lines.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = HubColors.surfaceRaised,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .42 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 62,
                height: 62,
                child: Icon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
