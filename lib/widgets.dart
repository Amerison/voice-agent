import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Scrollable page with a HubSpot-style monospace eyebrow and serif headline.
class HubPage extends StatelessWidget {
  const HubPage({
    super.key,
    required this.children,
    this.headline,
    this.eyebrow,
    this.headerAction,
  });

  final String? eyebrow;

  /// When null, the page has no in-page header and relies on the app bar
  /// title; give the page a [PageStorageKey] so its scroll offset is kept.
  final String? headline;
  final List<Widget> children;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headline = this.headline;
    return ListView(
      key: headline == null ? null : PageStorageKey(eyebrow ?? headline),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        if (headline != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) ...[
                        Text(eyebrow!, style: textTheme.labelSmall),
                        const SizedBox(height: 10),
                      ],
                      Text(headline, style: textTheme.headlineMedium),
                    ],
                  ),
                ),
                if (headerAction != null) headerAction!,
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
        ...children.expand((child) => [child, const SizedBox(height: 16)]),
      ],
    );
  }
}

/// Card with an icon badge and a "**Bold** regular" header, like HubSpot's
/// suggested-action cards.
class HubCard extends StatelessWidget {
  const HubCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.detail,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: _CardTitle(title: title, detail: detail),
                ),
                ?trailing,
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 16, color: HubColors.text),
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (detail != null)
            TextSpan(
              text: ' $detail',
              style: TextStyle(color: HubColors.textMuted),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 30,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? HubColors.background,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, size: size * .55, color: iconColor ?? HubColors.text),
    );
  }
}

enum PillTone { neutral, accent, success, danger }

class HubPill extends StatelessWidget {
  const HubPill({super.key, required this.label, this.tone = PillTone.neutral});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      PillTone.neutral => HubColors.textMuted,
      PillTone.accent => HubColors.orange,
      PillTone.success => HubColors.success,
      PillTone.danger => HubColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tone == PillTone.neutral ? HubColors.text : color,
        ),
      ),
    );
  }
}

/// Outlined timestamp chip used on HubSpot activity cards.
class DateChip extends StatelessWidget {
  const DateChip({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HubColors.surfaceRaised,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: HubColors.textMuted),
      ),
      child: Text(
        formatTimestamp(date),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Gradient pill modeled on HubSpot's "Ask Breeze Assistant" button.
class BreezeButton extends StatelessWidget {
  const BreezeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = CupertinoIcons.sparkles,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: HubColors.breeze,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular outlined action with a label, like HubSpot's Call / Email / Text row.
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: HubColors.surface,
            shape: CircleBorder(side: BorderSide(color: HubColors.textMuted)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, size: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: HubColors.orange,
        shape: BoxShape.circle,
      ),
      child: Icon(
        CupertinoIcons.waveform,
        color: Colors.white,
        size: size * .58,
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: HubColors.orange,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Empty state with a ringed illustration, bold title, and outlined action.
class HubEmptyState extends StatelessWidget {
  const HubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RingIllustration(icon: icon),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: HubColors.textMuted),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RingIllustration extends StatelessWidget {
  const _RingIllustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (size, color) in const [
            (60.0, HubColors.magenta),
            (44.0, Color(0xFFC23F51)),
            (28.0, HubColors.orange),
          ])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: .8)),
              ),
            ),
          Icon(icon, size: 16, color: HubColors.orange),
        ],
      ),
    );
  }
}

/// Full-screen HubSpot editor: Cancel · serif title · Done, covering the app.
class HubEditorPage extends StatelessWidget {
  const HubEditorPage({
    super.key,
    required this.title,
    required this.onDone,
    required this.body,
    this.doneLabel = 'Done',
  });

  final String title;
  final String doneLabel;
  final VoidCallback? onDone;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.background,
      body: Column(
        children: [
          Material(
            color: HubColors.surface,
            child: SafeArea(
              bottom: false,
              child: HubSheetHeader(
                title: title,
                doneLabel: doneLabel,
                onDone: onDone,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

Future<T?> showHubEditor<T>(BuildContext context, Widget page) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => page));
}

/// "Cancel · Serif title · Done" header used by HubSpot's modal sheets.
class HubSheetHeader extends StatelessWidget {
  const HubSheetHeader({
    super.key,
    required this.title,
    required this.onDone,
    this.doneLabel = 'Done',
    this.showCancel = true,
  });

  final String title;
  final String doneLabel;
  final VoidCallback? onDone;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HubColors.surface,
        border: Border(bottom: BorderSide(color: HubColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: showCancel
                ? TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          SizedBox(
            width: 76,
            child: TextButton(onPressed: onDone, child: Text(doneLabel)),
          ),
        ],
      ),
    );
  }
}

class HubPickerOption<T> {
  const HubPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
}

Future<T?> showHubPicker<T>(
  BuildContext context, {
  required String title,
  required List<HubPickerOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _HubPickerSheet<T>(title: title, options: options, selected: selected),
  );
}

class _HubPickerSheet<T> extends StatefulWidget {
  const _HubPickerSheet({
    required this.title,
    required this.options,
    this.selected,
  });

  final String title;
  final List<HubPickerOption<T>> options;
  final T? selected;

  @override
  State<_HubPickerSheet<T>> createState() => _HubPickerSheetState<T>();
}

class _HubPickerSheetState<T> extends State<_HubPickerSheet<T>> {
  late T? _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .92,
      child: Column(
        children: [
          HubSheetHeader(
            title: widget.title,
            onDone: () => Navigator.pop(context, _selected),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                HubGroup(
                  children: [
                    for (final option in widget.options)
                      _PickerRow(
                        option: option,
                        checked: option.value == _selected,
                        onTap: () => setState(() => _selected = option.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerRow<T> extends StatelessWidget {
  const _PickerRow({
    required this.option,
    required this.checked,
    required this.onTap,
  });

  final HubPickerOption<T> option;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: option.enabled ? 1 : .45,
      child: InkWell(
        onTap: option.enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SquareCheck(checked: checked),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.label, style: const TextStyle(fontSize: 17)),
                    if (option.subtitle != null)
                      Text(
                        option.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: HubColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SquareCheck extends StatelessWidget {
  const SquareCheck({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? HubColors.orange : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: checked ? HubColors.orange : HubColors.border,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(
              CupertinoIcons.checkmark_alt,
              size: 18,
              color: Colors.white,
            )
          : null,
    );
  }
}

/// Rounded group with hairline dividers between rows.
class HubGroup extends StatelessWidget {
  const HubGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HubColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Tappable field that opens a picker, styled to match text inputs.
class HubSelectField extends StatelessWidget {
  const HubSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(CupertinoIcons.chevron_down, size: 16),
        ),
        child: Text(value),
      ),
    );
  }
}

class HubBanner extends StatelessWidget {
  const HubBanner({
    super.key,
    required this.text,
    required this.icon,
    this.color,
    this.onClose,
  });

  final String text;
  final IconData icon;
  final Color? color;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final bannerColor = color ?? HubColors.textMuted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.fromLTRB(14, 8, onClose == null ? 14 : 2, 8),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerColor.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: bannerColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: bannerColor,
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(CupertinoIcons.xmark, size: 16, color: bannerColor),
            ),
        ],
      ),
    );
  }
}

Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  TextInputType? keyboardType,
  int? maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      maxLength: maxLength,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLength,
  });

  final String title;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

void showHubMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Saturday, October 10, 2026"
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}, ${date.year}';

/// "June 2026"
String formatMonth(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// "Jun 23, 2026 at 4:55 PM"
String formatTimestamp(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${_months[date.month - 1].substring(0, 3)} ${date.day}, ${date.year} at $hour:$minute $period';
}

String relativeDate(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.isNegative) return formatTimestamp(date);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}

String formatDuration(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
