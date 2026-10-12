import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'models.dart';
import 'number_picker.dart';
import 'repository.dart';
import 'theme.dart';
import 'voice_test_sheet.dart';
import 'widgets.dart';

enum _Step {
  useCase,
  identity,
  voice,
  business,
  website,
  calendar,
  company,
  greeting,
  test,
  number,
}

enum _Business {
  store(
    'In-person store',
    'Boutiques, salons, repair shops',
    CupertinoIcons.bag_fill,
    'help you plan a visit',
  ),
  homeServices(
    'On-site & home services',
    'Plumbers, electricians, cleaners',
    CupertinoIcons.wrench_fill,
    'book a visit',
  ),
  professional(
    'Professional services',
    'Lawyers, accountants, therapists',
    CupertinoIcons.briefcase_fill,
    'schedule a consultation',
  ),
  sales(
    'Sales & lead-based business',
    'Real estate, agencies, coaching',
    CupertinoIcons.chart_bar_alt_fill,
    'set up a time with our team',
  ),
  hospitality(
    'Hospitality & events',
    'Restaurants, venues, hotels',
    CupertinoIcons.star_fill,
    'make a reservation',
  ),
  other(
    'Something else',
    'I’ll learn the details as we go',
    CupertinoIcons.ellipsis,
    'book a time to connect',
  );

  const _Business(this.label, this.examples, this.icon, this.bookingPhrase);

  final String label;
  final String examples;
  final IconData icon;
  final String bookingPhrase;
}

/// Active Vapi voices. Previews are Vapi's published samples
/// (github.com/VapiAI/docs, MIT), bundled in assets/voices/ by lowercase id.
const _voices = [
  (id: 'Elliot', tone: 'Calm, professional'),
  (id: 'Clara', tone: 'Clear, professional'),
  (id: 'Savannah', tone: 'Bright, friendly'),
  (id: 'Kai', tone: 'Relaxed, helpful'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _defaultName = 'Luna';

  // San Francisco's overlay code; Twilio has no 415 numbers left.
  var _areaCode = '628';

  // Demo mode's fictional 555-01xx number.
  var _demoNumber = '+162855501${10 + math.Random().nextInt(90)}';

  /// A real number Twilio has free in [_areaCode]; Finish buys it if it's
  /// still available, or another in the same area code.
  String? _available;

  late final AnimationController _ambient;

  var _step = _Step.useCase;
  var _forward = true;
  AgentType? _type;
  var _friendliness = Friendliness.friendly;
  var _voice = _voices.first.id;
  AudioPlayer? _preview;
  String? _playing;
  _Business? _business;
  late final TextEditingController _name;
  late final TextEditingController _company;
  final _website = TextEditingController();
  final _greeting = TextEditingController();
  var _greetingEdited = false;
  String? _linkedSite;
  var _calendarConnected = false;
  var _tested = false;
  var _useExistingNumber = true;
  final _numberKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    final agent = widget.controller.data.agent;
    _name = TextEditingController(
      text: agent.name.trim().isEmpty ? _defaultName : agent.name,
    );
    _company = TextEditingController(text: agent.companyName);
    _friendliness = agent.friendliness;
    if (_voices.any((voice) => voice.id == agent.voice)) _voice = agent.voice;
    for (final field in [_name, _company, _website, _greeting]) {
      field.addListener(_refresh);
    }
    _lookUpNumber();
  }

  String get _number => formatPhone(
    widget.controller.isDemo
        ? _demoNumber
        : _available ?? '($_areaCode) number',
  )!;

  Future<void> _lookUpNumber() async {
    final areaCode = _areaCode;
    final number = await widget.controller.availableNumber(areaCode);
    if (mounted && areaCode == _areaCode) setState(() => _available = number);
  }

  Future<void> _changeAreaCode() async {
    final choice = await showNumberPicker(
      context,
      widget.controller,
      doneLabel: 'Use',
      initialAreaCode: _areaCode,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _areaCode = choice.areaCode;
      if (widget.controller.isDemo) {
        _demoNumber = choice.number ?? _demoNumber;
      } else {
        _available = choice.number;
      }
    });
    if (choice.number == null) await _lookUpNumber();
  }

  @override
  void dispose() {
    _ambient.dispose();
    _preview?.dispose();
    for (final field in [_name, _company, _website, _greeting]) {
      field.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  String get _agentName =>
      _name.text.trim().isEmpty ? _defaultName : _name.text.trim();

  String get _suggestedGreeting {
    final company = _company.text.trim();
    final calling = company.isEmpty ? 'calling' : 'calling $company';
    final action = _business?.bookingPhrase ?? 'book a time';
    return _type == AgentType.leadQualification
        ? 'Hi, thanks for $calling! This is $_agentName. I’d love to hear what you’re looking for and $action. What brings you in today?'
        : 'Hi, thanks for $calling! This is $_agentName, the AI receptionist. I can answer questions, take a message, or $action. How can I help today?';
  }

  AgentConfig get _draft {
    final type = _type ?? AgentType.receptionist;
    final greeting = _greeting.text.trim();
    return widget.controller.data.agent.copyWith(
      type: type,
      name: _agentName,
      friendliness: _friendliness,
      voice: _voice,
      persona: type == AgentType.receptionist
          ? 'the AI receptionist'
          : 'an AI lead qualification assistant',
      companyName: _company.text.trim(),
      companyDescription: _business == null
          ? null
          : '${_business!.label} business (${_business!.examples}).',
      greeting: greeting.isEmpty ? _suggestedGreeting : greeting,
      calendarConnected: _calendarConnected,
      reservedNumber: widget.controller.isDemo ? _demoNumber : _available,
    );
  }

  void _go(int delta) {
    final index = _step.index + delta;
    if (index < 0 || index >= _Step.values.length) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_playing != null) _preview?.stop().ignore();
    setState(() {
      _playing = null;
      _forward = delta > 0;
      _step = _Step.values[index];
      if (_step == _Step.greeting && !_greetingEdited) {
        _greeting.text = _suggestedGreeting;
      }
    });
  }

  void _next() => _go(1);

  /// Selects [id] and plays its sample; tapping the playing voice stops it.
  Future<void> _togglePreview(String id) async {
    final start = _playing != id;
    setState(() {
      _voice = id;
      _playing = start ? id : null;
    });
    try {
      final player = _preview ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = null);
        });
      await player.stop();
      if (start) {
        await player.play(AssetSource('voices/${id.toLowerCase()}.m4a'));
      }
    } catch (error) {
      debugPrint('Voice preview failed: $error');
      if (mounted && _playing == id) setState(() => _playing = null);
    }
  }

  void _advanceFrom(_Step step, Duration delay) {
    Future.delayed(delay, () {
      if (mounted && _step == step) _next();
    });
  }

  void _chooseType(AgentType type) {
    final first = _type == null;
    setState(() => _type = type);
    if (!first) return;
    // Bring the number reveal into view on short screens once it has grown.
    Future.delayed(const Duration(milliseconds: 400), () {
      final card = _numberKey.currentContext;
      if (card != null && card.mounted) {
        Scrollable.ensureVisible(
          card,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _linkWebsite() {
    var raw = _website.text.trim();
    if (!raw.contains('://')) raw = 'https://$raw';
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.host.contains('.')) {
      showHubMessage(context, 'Enter a website like yourcompany.com.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _linkedSite = uri.toString());
    if (_company.text.trim().isEmpty) {
      final stem = uri.host.replaceFirst('www.', '').split('.').first;
      _company.text = stem
          .split(RegExp(r'[-_]'))
          .where((word) => word.isNotEmpty)
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }
    _advanceFrom(_Step.website, const Duration(milliseconds: 900));
  }

  // ponytail: records the choice only. Real booking needs Google OAuth
  // (calendar.events scope) on the server to replace its mock meeting slots.
  void _connectCalendar() {
    HapticFeedback.mediumImpact();
    setState(() => _calendarConnected = true);
    _advanceFrom(_Step.calendar, const Duration(milliseconds: 1100));
  }

  Future<void> _testCall() async {
    await widget.controller.updateAgent(_draft);
    if (!mounted) return;
    await showVoiceTestSheet(context, widget.controller);
    if (mounted) setState(() => _tested = true);
  }

  Future<void> _finish() async {
    final controller = widget.controller;
    final site = _linkedSite;
    if (site != null &&
        !controller.data.agent.knowledgeSources.any(
          (source) => source.content == site,
        )) {
      await controller.addWebpage(site);
    }
    // ponytail: forwarding/porting an existing line is deferred to Deploy.
    // Either way the agent needs its own number: forwarded calls go to it.
    final draft = _draft;
    await controller.completeOnboarding(agent: draft);
    if (controller.data.agent.phoneNumber != null) return;
    try {
      await controller.provisionNumber(_areaCode, number: draft.reservedNumber);
    } on WorkspaceException {
      // Already in controller.error; Deploy offers a retry.
    }
  }

  ({String label, VoidCallback? onTap, bool call}) get _primary {
    ({String label, VoidCallback? onTap, bool call}) next(bool ready) =>
        (label: 'Continue', onTap: ready ? _next : null, call: false);
    return switch (_step) {
      _Step.useCase => next(_type != null),
      _Step.identity => next(_name.text.trim().isNotEmpty),
      _Step.voice => next(true),
      _Step.business => next(_business != null),
      _Step.website when _linkedSite == null => (
        label: 'Link website',
        onTap: _website.text.trim().isEmpty ? null : _linkWebsite,
        call: false,
      ),
      _Step.website => next(true),
      _Step.calendar when !_calendarConnected => (
        label: 'Connect Google Calendar',
        onTap: _connectCalendar,
        call: false,
      ),
      _Step.calendar => next(true),
      _Step.company => next(_company.text.trim().isNotEmpty),
      _Step.greeting => next(_greeting.text.trim().isNotEmpty),
      _Step.test when !_tested => (
        label: 'Call $_agentName',
        onTap: _testCall,
        call: true,
      ),
      _Step.test => next(true),
      _Step.number => (
        label: 'Finish setup',
        onTap: widget.controller.isBusy ? null : _finish,
        call: false,
      ),
    };
  }

  bool get _canSkip => switch (_step) {
    _Step.website => _linkedSite == null,
    _Step.calendar => !_calendarConnected,
    _Step.test => !_tested,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _ambient.isAnimating) _ambient.stop();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              progress: (_step.index + 1) / _Step.values.length,
              onBack: _step.index > 0 ? () => _go(-1) : null,
              onSkip: _canSkip ? _next : null,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_step);
                  final dx = incoming == _forward ? .08 : -.08;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(dx, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: _body()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _PillButton(
                label: primary.label,
                onPressed: primary.onTap,
                call: primary.call,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_step) {
      _Step.useCase => _page(
        hero: const BrandMark(size: 120),
        heading: const _TypingTitle(),
        subtitle: 'What should I focus on?',
        children: [
          _OptionTile(
            icon: CupertinoIcons.phone_fill,
            title: AgentType.receptionist.label,
            subtitle:
                'Answer questions, take messages, and book appointments for every caller.',
            selected: _type == AgentType.receptionist,
            onTap: () => _chooseType(AgentType.receptionist),
          ),
          _OptionTile(
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            title: AgentType.leadQualification.label,
            subtitle:
                'Qualify inbound leads and book meetings with the ones who fit.',
            selected: _type == AgentType.leadQualification,
            onTap: () => _chooseType(AgentType.leadQualification),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _type == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _Rise(
                      order: 1,
                      child: _NumberCard(key: _numberKey, number: _number),
                    ),
                  ),
          ),
        ],
      ),
      _Step.identity => _page(
        title: 'Give me a name and a personality',
        subtitle: 'Callers hear my name first. You can change both anytime.',
        children: [
          _BigField(controller: _name, hint: 'Agent name'),
          const SizedBox(height: 20),
          _Segmented(
            value: _friendliness,
            onChanged: (value) => setState(() => _friendliness = value),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              switch (_friendliness) {
                Friendliness.friendly =>
                  'Warm and upbeat, like your best front-desk hire.',
                Friendliness.professional =>
                  'Polished, precise, and to the point.',
                Friendliness.neutral => 'Calm, even, and straightforward.',
              },
              key: ValueKey(_friendliness),
              textAlign: TextAlign.center,
              style: TextStyle(color: HubColors.textMuted, fontSize: 14),
            ),
          ),
        ],
      ),
      _Step.voice => _page(
        title: 'How should I sound?',
        subtitle: 'Tap a voice to hear it. You can switch it later.',
        children: [
          for (final voice in _voices)
            _OptionTile(
              leading: _VoiceGlyph(
                animation: _ambient,
                selected: voice.id == _voice,
                playing: voice.id == _playing,
              ),
              title: voice.id,
              subtitle: voice.tone,
              selected: voice.id == _voice,
              onTap: () => _togglePreview(voice.id),
            ),
        ],
      ),
      _Step.business => _page(
        title: 'What type of business do you have?',
        subtitle: 'I’ll use this to shape how I welcome callers.',
        children: [
          for (final business in _Business.values)
            _OptionTile(
              icon: business.icon,
              title: business.label,
              subtitle: business.examples,
              selected: business == _business,
              trailing: CupertinoIcons.chevron_right,
              onTap: () {
                setState(() => _business = business);
                _advanceFrom(_Step.business, const Duration(milliseconds: 260));
              },
            ),
        ],
      ),
      _Step.website => _page(
        title: 'Link your website',
        subtitle:
            'I’ll learn your services, prices, and FAQs so I can answer questions automatically.',
        children: [
          _BigField(
            controller: _website,
            hint: 'yourcompany.com',
            autofocus: true,
            fontSize: 24,
            keyboardType: TextInputType.url,
            capitalization: TextCapitalization.none,
            onChanged: (_) {
              if (_linkedSite != null) setState(() => _linkedSite = null);
            },
            onSubmitted: _linkWebsite,
          ),
          _Confirmation(visible: _linkedSite != null, label: 'Website linked'),
        ],
      ),
      _Step.calendar => _page(
        title: 'Now, let me book meetings on your calendar',
        subtitle:
            'Businesses that let me handle bookings see more appointments and fewer no-shows.',
        children: [
          const _FeatureCard(
            features: [
              (CupertinoIcons.clock, 'Real-time availability checks'),
              (
                CupertinoIcons.chat_bubble_text,
                'Instant confirmation for callers',
              ),
              (
                CupertinoIcons.lock_shield,
                'Secure access you can revoke anytime',
              ),
            ],
          ),
          _Confirmation(
            visible: _calendarConnected,
            label: 'Google Calendar connected',
          ),
        ],
      ),
      _Step.company => _page(
        title: 'What’s your company called?',
        subtitle: 'I’ll use it to represent you when I answer calls.',
        children: [
          _BigField(
            controller: _company,
            hint: 'Company name',
            autofocus: true,
            onSubmitted: _company.text.trim().isEmpty ? null : _next,
          ),
        ],
      ),
      _Step.greeting => _page(
        title: 'How should I greet callers?',
        subtitle:
            'This is the first thing I’ll say when I pick up. Set the right tone.',
        children: [
          TextField(
            controller: _greeting,
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16, height: 1.5),
            onChanged: (_) => _greetingEdited = true,
            decoration: InputDecoration(
              fillColor: HubColors.surface,
              contentPadding: const EdgeInsets.all(16),
              border: _roundBorder(HubColors.border),
              enabledBorder: _roundBorder(HubColors.border),
              focusedBorder: _roundBorder(HubColors.textMuted),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _greeting.text == _suggestedGreeting
                ? const SizedBox(height: 8)
                : TextButton.icon(
                    onPressed: () => setState(() {
                      _greeting.text = _suggestedGreeting;
                      _greetingEdited = false;
                    }),
                    icon: const Icon(
                      CupertinoIcons.arrow_counterclockwise,
                      size: 16,
                    ),
                    label: const Text('Use suggested greeting'),
                  ),
          ),
        ],
      ),
      _Step.test => _page(
        hero: _AgentInitial(name: _agentName),
        title: 'Want to hear me in action?',
        subtitle:
            'Call $_agentName and play a customer. It’s a real conversation using everything you just set up.',
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in [
                (_type ?? AgentType.receptionist).label,
                '$_voice voice',
                switch (_friendliness) {
                  Friendliness.friendly => 'Friendly',
                  Friendliness.professional => 'Professional',
                  Friendliness.neutral => 'Neutral',
                },
                if (_calendarConnected) 'Books on Google Calendar',
                if (_linkedSite != null) 'Knows your website',
              ])
                HubPill(label: label),
            ],
          ),
          _Confirmation(visible: _tested, label: 'Test call complete'),
        ],
      ),
      _Step.number => _page(
        title: 'Which number should I answer calls on?',
        subtitle:
            'This is the number your callers dial. I’ll answer, help, and book for you.',
        children: [
          _OptionTile(
            icon: CupertinoIcons.arrow_right_arrow_left,
            title: 'Use my existing number',
            subtitle: 'Forward calls from your current line',
            badge: 'Most popular',
            selected: _useExistingNumber,
            onTap: () => setState(() => _useExistingNumber = true),
          ),
          _OptionTile(
            icon: CupertinoIcons.plus_circle_fill,
            title: 'Get a new number',
            subtitle: _number,
            selected: !_useExistingNumber,
            onTap: () => setState(() => _useExistingNumber = false),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: _useExistingNumber
                ? _InfoCard(
                    key: const ValueKey('forward'),
                    title: 'What is call forwarding?',
                    body:
                        'A standard carrier feature that sends calls you don’t pick up to me at $_number. Callers never notice. We’ll set it up together when you go live.',
                  )
                : _InfoCard(
                    key: const ValueKey('new'),
                    title: 'Your new number',
                    body:
                        '$_number becomes yours when you finish setup, and I answer it right away. You can port your own number later.',
                  ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _changeAreaCode,
              icon: const Icon(CupertinoIcons.location, size: 16),
              label: const Text('Change area code'),
            ),
          ),
        ],
      ),
    };
  }

  Widget _page({
    Widget? hero,
    String? title,
    Widget? heading,
    required String subtitle,
    required List<Widget> children,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (hero != null) _Hero(child: hero) else const SizedBox(height: 36),
        _Rise(
          order: 1,
          child:
              heading ??
              Text(title!, textAlign: TextAlign.center, style: _titleStyle),
        ),
        const SizedBox(height: 10),
        _Rise(
          order: 2,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HubColors.textMuted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (final (index, child) in children.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Rise(order: 3 + index, child: child),
          ),
      ],
    );
  }
}

OutlineInputBorder _roundBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(16),
  borderSide: BorderSide(color: color),
);

/// Fades and lifts its child in, staggered by [order].
const _titleStyle = TextStyle(
  fontSize: 24,
  height: 1.2,
  fontWeight: FontWeight.w700,
  letterSpacing: -.3,
);

/// "Hi, I’m your new AI" with the role typed out, erased, and retyped on its
/// own line so the heading never reflows. Screen readers hear one sentence.
class _TypingTitle extends StatefulWidget {
  const _TypingTitle();

  @override
  State<_TypingTitle> createState() => _TypingTitleState();
}

class _TypingTitleState extends State<_TypingTitle>
    with SingleTickerProviderStateMixin {
  static const _roles = [
    'agent',
    'receptionist',
    'sales rep',
    'appointment setter',
    'lead qualifier',
  ];

  late final AnimationController _caret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  final _random = math.Random();
  Timer? _timer;
  var _role = 0;
  var _shown = _roles.first.length;
  var _deleting = true;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _timer?.cancel();
      _timer = null;
      _caret.stop();
      _role = 0;
      _shown = _roles.first.length;
      _deleting = true;
    } else if (_timer == null) {
      _caret.repeat();
      _timer = Timer(const Duration(milliseconds: 2200), _tick);
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      if (!_deleting) {
        _shown++;
      } else if (--_shown == 0) {
        _deleting = false;
        _role = (_role + 1) % _roles.length;
      }
    });
    final full = _shown == _roles[_role].length;
    if (full) _deleting = true;
    final ms = full
        ? 1800
        : _shown == 0
        ? 280
        : _deleting
        ? 38
        : 65 + _random.nextInt(60);
    _timer = Timer(Duration(milliseconds: ms), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _caret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = _roles[_role];
    final holding = _shown == word.length;
    return Semantics(
      label: 'Hi, I’m your new AI agent',
      excludeSemantics: true,
      child: Column(
        children: [
          const Text(
            'Hi, I’m your new AI',
            textAlign: TextAlign.center,
            style: _titleStyle,
          ),
          SizedBox(
            height: 31,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: HubColors.breeze.createShader,
                  child: Text(word.substring(0, _shown), style: _titleStyle),
                ),
                if (!_reduceMotion)
                  AnimatedBuilder(
                    animation: _caret,
                    builder: (context, _) => Opacity(
                      opacity: !holding || _caret.value < .55 ? 1 : 0,
                      child: Container(
                        width: 2.5,
                        height: 26,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          color: HubColors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = order * 60;
    final total = 480 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.progress, this.onBack, this.onSkip});

  final double progress;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            AnimatedOpacity(
              opacity: onBack == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: HubColors.surfaceRaised,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBack,
                  child: Tooltip(
                    message: 'Back',
                    child: SizedBox.square(
                      dimension: 34,
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: 16,
                        color: HubColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Container(
                  height: 6,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: HubColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Container(
                      width: box.maxWidth * value,
                      decoration: BoxDecoration(
                        gradient: HubColors.breeze,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: AnimatedOpacity(
                opacity: onSkip == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: HubColors.textMuted,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft glow behind the hero mark that wanders at random.
class _Hero extends StatefulWidget {
  const _Hero({required this.child});

  final Widget child;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero>
    with SingleTickerProviderStateMixin, DriftClock {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const blobs = [
      (color: HubColors.magenta, seed: 11, size: 140.0),
      (color: HubColors.orange, seed: 29, size: 120.0),
      (color: Color(0xFFF3D3B8), seed: 47, size: 100.0),
    ];
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 38, sigmaY: 38),
                child: ValueListenableBuilder<double>(
                  valueListenable: clock,
                  builder: (context, t, _) {
                    return Stack(
                      children: [
                        for (final blob in blobs)
                          Align(
                            alignment: Alignment(
                              drift(t * .2, blob.seed) * .5,
                              drift(t * .2, blob.seed + 5) * .35 - .05,
                            ),
                            child: Container(
                              width:
                                  blob.size *
                                  (1 + .25 * drift(t * .3, blob.seed + 9)),
                              height:
                                  blob.size *
                                  (1 + .25 * drift(t * .3, blob.seed + 11)),
                              decoration: ShapeDecoration(
                                shape: const OvalBorder(),
                                color: blob.color.withValues(
                                  alpha: dark ? .24 : .16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          _Rise(order: 0, child: widget.child),
        ],
      ),
    );
  }
}

class _AgentInitial extends StatelessWidget {
  const _AgentInitial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: HubColors.breeze,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.call = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool call;

  static const _green = Color(0xFF30C85E);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = !enabled
        ? HubColors.surfaceRaised
        : call
        ? _green
        : HubColors.text;
    final foreground = !enabled
        ? HubColors.textSubtle
        : call
        ? Colors.white
        : HubColors.background;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      height: 54,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(27),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Row(
                key: ValueKey(label),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (call) ...[
                    Icon(
                      CupertinoIcons.phone_fill,
                      color: foreground,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
    this.trailing,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? HubColors.surfaceRaised : HubColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? HubColors.text.withValues(alpha: .55)
              : HubColors.border,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                leading ??
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: HubColors.background,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, size: 19, color: HubColors.text),
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: HubColors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: HubColors.textMuted,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (trailing != null)
                  Icon(trailing, size: 16, color: HubColors.textSubtle)
                else
                  _Check(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? HubColors.text : Colors.transparent,
        border: Border.all(
          color: selected ? HubColors.text : HubColors.textSubtle,
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Icon(
          CupertinoIcons.checkmark,
          size: 14,
          color: HubColors.background,
        ),
      ),
    );
  }
}

class _VoiceGlyph extends StatelessWidget {
  const _VoiceGlyph({
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

class _BigField extends StatelessWidget {
  const _BigField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.fontSize = 30,
    this.keyboardType,
    this.capitalization = TextCapitalization.words,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final double fontSize;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    const none = InputBorder.none;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      autocorrect: keyboardType != TextInputType.url,
      textCapitalization: capitalization,
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: HubColors.textSubtle.withValues(alpha: .55),
          fontWeight: FontWeight.w600,
        ),
        filled: false,
        border: none,
        enabledBorder: none,
        focusedBorder: none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});

  final Friendliness value;
  final ValueChanged<Friendliness> onChanged;

  static const _order = [
    (Friendliness.friendly, 'Friendly'),
    (Friendliness.professional, 'Professional'),
    (Friendliness.neutral, 'Neutral'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _order.indexWhere((option) => option.$1 == value);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HubColors.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + index.toDouble(), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _order.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: HubColors.text,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (option, label) in _order)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(option);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: HubFonts.sans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: option == value
                              ? HubColors.background
                              : HubColors.textMuted,
                        ),
                        child: Text(label),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: HubColors.text,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.device_phone_portrait,
                color: HubColors.background,
                size: 26,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        color: HubColors.background,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Your agent’s new number',
                      style: TextStyle(
                        color: HubColors.background.withValues(alpha: .6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 15,
              color: HubColors.textSubtle,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Keep or port your own number later',
                style: TextStyle(color: HubColors.textSubtle, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.visible, required this.label});

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .9, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: child,
        ),
      ),
      child: !visible
          ? const SizedBox(height: 44)
          : Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: HubColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: HubColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.features});

  final List<(IconData, String)> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HubColors.border),
      ),
      child: Column(
        children: [
          for (final (icon, label) in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: HubColors.textMuted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HubColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info_circle,
            size: 18,
            color: HubColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: HubColors.textMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
