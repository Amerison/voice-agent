import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vapi/vapi.dart';

import 'app_controller.dart';
import 'models.dart';
import 'theme.dart';
import 'voice_transcript.dart';

const _vapiPublicKey = String.fromEnvironment('VAPI_PUBLIC_KEY');

Future<void> showVoiceTestSheet(
  BuildContext context,
  AppController controller,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _VoiceTestSheet(controller: controller),
    ),
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
  bool _speaker = true;
  Timer? _clock;
  int _seconds = 0;
  bool _stopping = false;
  final _transcript = VoiceTranscript();

  bool get _isActive =>
      _state == _VoiceTestState.listening || _state == _VoiceTestState.speaking;

  @override
  void initState() {
    super.initState();
    _transcript.addListener(_onTranscriptChanged);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
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
      final controller = widget.controller;
      // Live mode tests the synced assistant so the call lands in Calls.
      if (!controller.isDemo &&
          controller.data.agent.syncStatus != SyncStatus.ready) {
        if (mounted) setState(() => _state = _VoiceTestState.preparing);
        await controller.syncAgent();
      }
      final agent = controller.data.agent;
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
      if (call.status == VapiCallStatus.active) _startClock();
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
        _startClock();
        setState(() => _state = _VoiceTestState.listening);
      case 'call-end':
        _stopClock();
        _transcript.flush();
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
    if (message['type'] != 'transcript') return;
    final fromAgent = message['role'] == 'assistant';
    if (message['transcriptType'] == 'partial') {
      if (!fromAgent) _transcript.userStillSpeaking();
      return;
    }
    final text = message['transcript'] as String?;
    if (text == null) return;
    if (fromAgent) {
      _transcript.addAgent(text);
    } else {
      _transcript.addUser(text);
    }
  }

  void _onTranscriptChanged() {
    if (mounted) setState(() {});
  }

  void _startClock() {
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  void _fail(String message) {
    _stopClock();
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
      'voice': {'provider': 'vapi', 'voiceId': agent.voice},
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

  void _toggleSpeaker() {
    final next = !_speaker;
    try {
      _call?.setAudioDevice(
        device: next ? VapiAudioDevice.speakerphone : VapiAudioDevice.earpiece,
      );
      setState(() => _speaker = next);
    } on Object {
      // Keep the current route when the device can't switch.
    }
  }

  Future<void> _stop() async {
    if (_stopping) return;
    _stopping = true;
    _stopClock();
    final call = _call;
    if (call != null && call.status != VapiCallStatus.ended) {
      try {
        await call.stop();
      } on Object {
        // The call may already have been ended remotely.
      }
    }
    if (mounted) {
      _transcript.flush();
      setState(() => _state = _VoiceTestState.ended);
    }
    _stopping = false;
  }

  Future<void> _close() async {
    final controller = widget.controller;
    final hadCall = _call != null;
    await _stop();
    if (mounted) Navigator.pop(context);
    // Vapi finalizes the call record shortly after hang-up.
    if (hadCall && !controller.isDemo) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 5), controller.refresh),
      );
    }
  }

  Future<void> _retry() async {
    await _events?.cancel();
    _call?.dispose();
    _client?.dispose();
    _events = null;
    _call = null;
    _client = null;
    _transcript.clear();
    setState(() {
      _error = null;
      _seconds = 0;
      _state = _VoiceTestState.preparing;
    });
    await _start();
  }

  @override
  void dispose() {
    _stopClock();
    _transcript.dispose();
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

  String get _elapsed =>
      '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

  String get _statusLine => switch (_state) {
    _VoiceTestState.preparing || _VoiceTestState.connecting => 'Calling…',
    _VoiceTestState.listening || _VoiceTestState.speaking => _elapsed,
    _VoiceTestState.ended => 'Call ended · $_elapsed',
    _VoiceTestState.error => 'Call failed',
  };

  Widget _middle() {
    if (_state == _VoiceTestState.error) {
      return _CallMessage(
        key: const ValueKey('error'),
        title: 'Couldn’t start the test',
        detail: _error ?? 'Please try again.',
      );
    }
    if (_transcript.isEmpty) return const SizedBox.shrink();
    return ShaderMask(
      key: const ValueKey('transcript'),
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, .18],
        colors: [Colors.transparent, Colors.black],
      ).createShader(bounds),
      child: _TranscriptView(
        lines: _transcript.lines,
        userThinking: _transcript.isUserThinking,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final over =
        _state == _VoiceTestState.ended || _state == _VoiceTestState.error;
    final name = widget.controller.data.agent.name;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: _CallBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  _CallerAvatar(
                    name: name,
                    animation: _pulse,
                    speaking: _state == _VoiceTestState.speaking,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _statusLine,
                      key: ValueKey(_statusLine),
                      style: TextStyle(
                        color: HubColors.textMuted,
                        fontSize: 17,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _middle(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 8, 36, 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: over
                          ? [
                              _DialButton(
                                icon: CupertinoIcons.phone_fill,
                                label: 'Call again',
                                color: _callGreen,
                                onTap: _retry,
                              ),
                              const SizedBox(width: 56),
                              _DialButton(
                                icon: CupertinoIcons.xmark,
                                label: 'Done',
                                tooltip: 'Close voice test',
                                onTap: _close,
                              ),
                            ]
                          : [
                              _DialButton(
                                icon: CupertinoIcons.speaker_3_fill,
                                label: 'Speaker',
                                selected: _speaker,
                                onTap: active ? _toggleSpeaker : null,
                              ),
                              const SizedBox(width: 56),
                              _DialButton(
                                icon: CupertinoIcons.phone_down_fill,
                                label: 'End',
                                color: HubColors.danger,
                                tooltip: 'Close voice test',
                                onTap: _close,
                              ),
                            ],
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

const _callGreen = Color(0xFF30C85E);

class _CallBackdrop extends StatelessWidget {
  const _CallBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HubColors.background,
        gradient: RadialGradient(
          center: const Alignment(0, -.62),
          radius: .9,
          colors: [
            HubColors.magenta.withValues(alpha: dark ? .2 : .1),
            HubColors.background,
          ],
        ),
      ),
    );
  }
}

class _CallerAvatar extends StatelessWidget {
  const _CallerAvatar({
    required this.name,
    required this.animation,
    required this.speaking,
  });

  final String name;
  final Animation<double> animation;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (speaking)
            for (final offset in const [0.0, .5])
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = (animation.value + offset) % 1;
                  return Container(
                    width: 88 + 44 * t,
                    height: 88 + 44 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: HubColors.orange.withValues(alpha: (1 - t) * .6),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: HubColors.breeze,
              shape: BoxShape.circle,
            ),
            child: Text(
              name.isEmpty ? '' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallMessage extends StatelessWidget {
  const _CallMessage({super.key, required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: HubColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptView extends StatelessWidget {
  const _TranscriptView({required this.lines, required this.userThinking});

  final List<TranscriptLine> lines;
  final bool userThinking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 12),
      children: [
        if (userThinking)
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: _UserBubble(child: _ThinkingDots()),
          ),
        for (final line in lines.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: switch (line.speaker) {
              TranscriptSpeaker.user => _UserBubble(child: Text(line.text)),
              TranscriptSpeaker.agent => _AgentTurn(text: line.text),
            },
          ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: HubColors.surfaceRaised,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      ),
    );
  }
}

class _AgentTurn extends StatelessWidget {
  const _AgentTurn({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallAgentMark(),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              text,
              style: const TextStyle(fontSize: 17, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Thinking',
      child: SizedBox(
        height: 20,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < 3; index++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: HubColors.textMuted.withValues(
                      alpha: _dotOpacity(index),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value - index * .18) % 1;
    final wave = phase < .5 ? phase * 2 : (1 - phase) * 2;
    return .3 + wave * .7;
  }
}

class _SmallAgentMark extends StatelessWidget {
  const _SmallAgentMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: HubColors.breeze,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 17),
    );
  }
}

class _DialButton extends StatelessWidget {
  const _DialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background =
        color ??
        (selected ? HubColors.text : HubColors.text.withValues(alpha: .12));
    final foreground = color != null
        ? Colors.white
        : selected
        ? HubColors.background
        : HubColors.text;
    final button = AnimatedOpacity(
      opacity: enabled ? 1 : .35,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onTap!();
                      }
                    : null,
                child: Icon(icon, color: foreground, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: HubColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
