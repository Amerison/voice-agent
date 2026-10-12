import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// The area code picked, and the available number previewed for it. The
/// number is null when no preview could be fetched; provisioning then picks
/// one in the area code.
typedef NumberChoice = ({String areaCode, String? number});

/// Full-screen picker for the agent's phone number: choose an area code and
/// see a real available number before committing.
Future<NumberChoice?> showNumberPicker(
  BuildContext context,
  AppController controller, {
  required String doneLabel,
  String initialAreaCode = '628',
}) => showHubEditor<NumberChoice>(
  context,
  NumberPickerPage(
    controller: controller,
    doneLabel: doneLabel,
    initialAreaCode: initialAreaCode,
  ),
);

const _popularAreaCodes = [
  ('628', 'San Francisco'),
  ('510', 'Oakland'),
  ('650', 'Palo Alto'),
  ('310', 'Los Angeles'),
  ('917', 'New York'),
  ('312', 'Chicago'),
];

class NumberPickerPage extends StatefulWidget {
  const NumberPickerPage({
    super.key,
    required this.controller,
    required this.doneLabel,
    required this.initialAreaCode,
  });

  final AppController controller;
  final String doneLabel;
  final String initialAreaCode;

  @override
  State<NumberPickerPage> createState() => _NumberPickerPageState();
}

class _NumberPickerPageState extends State<NumberPickerPage> {
  late final _areaCode = TextEditingController(text: widget.initialAreaCode);
  Timer? _debounce;
  var _lookup = 0;
  var _searching = false;
  String? _number;

  String get _code => _areaCode.text;
  bool get _valid => RegExp(r'^\d{3}$').hasMatch(_code);

  @override
  void initState() {
    super.initState();
    _searching = _valid;
    if (_valid) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _areaCode.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    setState(() {
      _number = null;
      _searching = _valid;
    });
    if (_valid) {
      _debounce = Timer(const Duration(milliseconds: 300), _search);
    }
  }

  void _pick(String code) {
    HapticFeedback.selectionClick();
    _areaCode.text = code;
    FocusManager.instance.primaryFocus?.unfocus();
    _changed();
  }

  Future<void> _search() async {
    if (!_valid) return;
    final code = _code;
    final lookup = ++_lookup;
    final number = await _available(code);
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _number = number;
      _searching = false;
    });
  }

  Future<String?> _available(String code) async => widget.controller.isDemo
      ? '+1${code}5550142'
      : widget.controller.availableNumber(code);

  @override
  Widget build(BuildContext context) {
    return HubEditorPage(
      title: 'New number',
      doneLabel: widget.doneLabel,
      onDone: _valid && !_searching
          ? () => Navigator.pop<NumberChoice>(context, (
              areaCode: _code,
              number: _number,
            ))
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          28,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            'Where are your callers?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Callers are more likely to pick up a local area code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: HubColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          _AreaCodeField(controller: _areaCode, onChanged: (_) => _changed()),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, city) in _popularAreaCodes)
                _AreaChip(
                  code: code,
                  city: city,
                  selected: code == _code,
                  onTap: () => _pick(code),
                ),
            ],
          ),
          const SizedBox(height: 28),
          _NumberPreview(
            areaCode: _code,
            valid: _valid,
            searching: _searching,
            number: _number,
          ),
        ],
      ),
    );
  }
}

class _AreaCodeField extends StatelessWidget {
  const _AreaCodeField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 180,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: '628',
            hintStyle: TextStyle(color: HubColors.textSubtle),
            prefixText: '(',
            suffixText: ')',
            prefixStyle: TextStyle(color: HubColors.textSubtle, fontSize: 32),
            suffixStyle: TextStyle(color: HubColors.textSubtle, fontSize: 32),
          ),
        ),
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.code,
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HubColors.text : HubColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? HubColors.text : HubColors.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$code  ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: city,
                  style: TextStyle(
                    color: selected
                        ? HubColors.background.withValues(alpha: .7)
                        : HubColors.textMuted,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 14,
              color: selected ? HubColors.background : HubColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberPreview extends StatelessWidget {
  const _NumberPreview({
    required this.areaCode,
    required this.valid,
    required this.searching,
    required this.number,
  });

  final String areaCode;
  final bool valid;
  final bool searching;
  final String? number;

  @override
  Widget build(BuildContext context) {
    final (String title, String detail) = switch (number) {
      _ when !valid => ('Enter an area code', 'Three digits, like 628.'),
      _ when searching => (
        'Finding a number…',
        'Checking what’s free in ($areaCode).',
      ),
      null => ('A ($areaCode) number', 'You’ll see it as soon as it’s yours.'),
      final String found when !found.startsWith('+1$areaCode') => (
        formatPhone(found)!,
        'No ($areaCode) numbers are left, so this one is from another area.',
      ),
      final String found => (
        formatPhone(found)!,
        'Available now. It’s yours when you continue.',
      ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HubColors.border),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 30,
            child: searching
                ? const CupertinoActivityIndicator()
                : const IconBadge(icon: CupertinoIcons.phone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(color: HubColors.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
