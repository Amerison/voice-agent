import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  bool _muted = false;
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
    if (mounted) {
      _transcript.flush();
      setState(() => _state = _VoiceTestState.ended);
    }
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
    _transcript.clear();
    setState(() {
      _error = null;
      _state = _VoiceTestState.preparing;
    });
    await _start();
  }

  @override
  void dispose() {
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

  String get _statusTitle => switch (_state) {
    _VoiceTestState.preparing => 'Connecting',
    _VoiceTestState.connecting => 'Connecting',
    _VoiceTestState.listening => 'Ready to chat',
    _VoiceTestState.speaking =>
      '${widget.controller.data.agent.name} is speaking',
    _VoiceTestState.ended => 'Test complete',
    _VoiceTestState.error => 'Couldn’t start the test',
  };

  String get _statusDetail => switch (_state) {
    _VoiceTestState.preparing => 'Loading the latest voice and training.',
    _VoiceTestState.connecting => 'Starting a secure voice session.',
    _VoiceTestState.listening => 'Your microphone is live.',
    _VoiceTestState.speaking => 'You can interrupt at any time.',
    _VoiceTestState.ended => 'Your live Vapi session has ended.',
    _VoiceTestState.error => _error ?? 'Please try again.',
  };

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
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
                  Expanded(
                    child: _transcript.isEmpty
                        ? _EmptyCallState(
                            animation: _pulse,
                            title: _statusTitle,
                            detail: _statusDetail,
                            state: _state,
                            onRetry: _state == _VoiceTestState.error
                                ? _retry
                                : null,
                          )
                        : _TranscriptView(
                            lines: _transcript.lines,
                            userThinking: _transcript.isUserThinking,
                            agentName: widget.controller.data.agent.name,
                            state: _state,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                    child: Row(
                      children: [
                        const Spacer(),
                        _CircleButton(
                          tooltip: _muted ? 'Unmute' : 'Mute',
                          icon: _muted
                              ? CupertinoIcons.mic_slash_fill
                              : CupertinoIcons.mic_fill,
                          onTap: active ? _toggleMute : null,
                        ),
                        const SizedBox(width: 12),
                        _EndCallButton(
                          animation: _pulse,
                          active: active,
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

class _CallBackdrop extends StatelessWidget {
  const _CallBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HubColors.background,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [.52, .78, 1],
          colors: [
            HubColors.background,
            HubColors.orange.withValues(alpha: dark ? .045 : .07),
            HubColors.magenta.withValues(alpha: dark ? .14 : .17),
          ],
        ),
      ),
    );
  }
}

class _EmptyCallState extends StatelessWidget {
  const _EmptyCallState({
    required this.animation,
    required this.title,
    required this.detail,
    required this.state,
    this.onRetry,
  });

  final Animation<double> animation;
  final String title;
  final String detail;
  final _VoiceTestState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AgentMark(animation: animation, state: state),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: HubColors.textMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(CupertinoIcons.arrow_clockwise),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentMark extends StatelessWidget {
  const _AgentMark({required this.animation, required this.state});

  final Animation<double> animation;
  final _VoiceTestState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final active =
            state == _VoiceTestState.listening ||
            state == _VoiceTestState.speaking ||
            state == _VoiceTestState.connecting;
        final scale = active ? 1 + animation.value * .08 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: HubColors.breeze,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: HubColors.orange.withValues(alpha: .24),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.sparkles, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _TranscriptView extends StatelessWidget {
  const _TranscriptView({
    required this.lines,
    required this.userThinking,
    required this.agentName,
    required this.state,
  });

  final List<TranscriptLine> lines;
  final bool userThinking;
  final String agentName;
  final _VoiceTestState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
      children: [
        if (state == _VoiceTestState.speaking ||
            state == _VoiceTestState.listening)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                const _SmallAgentMark(),
                const SizedBox(width: 10),
                Text(
                  state == _VoiceTestState.speaking
                      ? '$agentName is speaking'
                      : 'Ready to chat',
                  style: TextStyle(color: HubColors.textMuted),
                ),
              ],
            ),
          ),
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Material(
          color: HubColors.surfaceRaised,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(icon, color: HubColors.text, size: 23),
            ),
          ),
        ),
      ),
    );
  }
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({
    required this.animation,
    required this.active,
    required this.onTap,
  });

  final Animation<double> animation;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Close voice test',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: active ? HubColors.breeze : null,
          color: active ? null : HubColors.surfaceRaised,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: 114,
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Waveform(animation: animation, active: active),
                  const SizedBox(width: 14),
                  Icon(CupertinoIcons.xmark, color: HubColors.text, size: 21),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.animation, required this.active});

  final Animation<double> animation;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Row(
        children: [
          for (var index = 0; index < 4; index++)
            Container(
              width: 3,
              height: active
                  ? 8 + ((animation.value + index * .23) % 1) * 14
                  : 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: HubColors.text,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
