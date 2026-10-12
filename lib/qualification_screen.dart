import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const _startOptions = [0, 1, 3, 6, 12];
const _meetingLengths = [15, 30, 45, 60];

String _startLabel(int months) => switch (months) {
  0 => 'Any time',
  1 => '1 month',
  _ => '$months months',
};

/// Lead qualification settings: who's a fit, what to ask, how to decide, and
/// what to do with each caller.
class QualificationScreen extends StatefulWidget {
  const QualificationScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<QualificationScreen> createState() => _QualificationScreenState();
}

class _QualificationScreenState extends State<QualificationScreen> {
  late LeadQualification _setup;
  late final TextEditingController _idealCustomer;
  late final TextEditingController _minimumBudget;
  late final TextEditingController _notAFitMessage;

  @override
  void initState() {
    super.initState();
    _setup = widget.controller.data.agent.qualification;
    _idealCustomer = TextEditingController(text: _setup.idealCustomer);
    _minimumBudget = TextEditingController(text: _setup.minimumBudget);
    _notAFitMessage = TextEditingController(text: _setup.notAFitMessage);
  }

  @override
  void dispose() {
    _idealCustomer.dispose();
    _minimumBudget.dispose();
    _notAFitMessage.dispose();
    super.dispose();
  }

  void _update(LeadQualification setup) => setState(() => _setup = setup);

  Future<void> _save() async {
    if (_setup.questions.isEmpty) {
      showHubMessage(context, 'Add at least one question to ask leads.');
      return;
    }
    final agent = widget.controller.data.agent;
    await widget.controller.updateAgent(
      agent.copyWith(
        qualification: _setup.copyWith(
          idealCustomer: _idealCustomer.text.trim(),
          minimumBudget: _minimumBudget.text.trim(),
          notAFitMessage: _notAFitMessage.text.trim(),
        ),
      ),
    );
    if (mounted) showHubMessage(context, 'Qualification saved');
  }

  @override
  Widget build(BuildContext context) {
    return HubPage(
      headline: 'Decide who’s a good lead and what happens next.',
      children: [
        _IdealCustomerCard(controller: _idealCustomer),
        _QuestionsCard(
          questions: _setup.questions,
          onChanged: (questions) =>
              _update(_setup.copyWith(questions: questions)),
        ),
        _RulesCard(
          setup: _setup,
          minimumBudget: _minimumBudget,
          onChanged: _update,
        ),
        _NextStepsCard(
          setup: _setup,
          bookingEnabled: widget.controller.data.agent.bookMeetingEnabled,
          notAFitMessage: _notAFitMessage,
          onChanged: _update,
        ),
        _LeadDetailsCard(
          collect: _setup.collect,
          onChanged: (collect) => _update(_setup.copyWith(collect: collect)),
        ),
        FilledButton(onPressed: _save, child: const Text('Save qualification')),
      ],
    );
  }
}

class _IdealCustomerCard extends StatelessWidget {
  const _IdealCustomerCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      icon: CupertinoIcons.scope,
      title: 'Ideal customer',
      detail: 'who’s a good fit',
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText:
              'Homeowners in the Bay Area planning a kitchen or bathroom remodel.',
          helperText: 'Include industries, size, location, and typical needs.',
          helperMaxLines: 2,
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}

class _QuestionsCard extends StatelessWidget {
  const _QuestionsCard({required this.questions, required this.onChanged});

  final List<QualifyingQuestion> questions;
  final ValueChanged<List<QualifyingQuestion>> onChanged;

  Future<void> _add(BuildContext context) async {
    final text = await _askText(
      context,
      title: 'New question',
      hint: 'How many locations do you have?',
    );
    if (text == null) return;
    onChanged([
      ...questions,
      QualifyingQuestion(
        id: 'question-${DateTime.now().microsecondsSinceEpoch}',
        text: text,
      ),
    ]);
  }

  Future<void> _handle(
    BuildContext context,
    int index,
    _QuestionAction action,
  ) async {
    final list = [...questions];
    final question = list[index];
    switch (action) {
      case _QuestionAction.edit:
        final text = await _askText(
          context,
          title: 'Edit question',
          initial: question.text,
        );
        if (text == null) return;
        list[index] = question.copyWith(text: text);
      case _QuestionAction.toggleRequired:
        list[index] = question.copyWith(required: !question.required);
      case _QuestionAction.moveUp:
        list
          ..removeAt(index)
          ..insert(index - 1, question);
      case _QuestionAction.moveDown:
        list
          ..removeAt(index)
          ..insert(index + 1, question);
      case _QuestionAction.remove:
        list.removeAt(index);
    }
    onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return HubCard(
      icon: CupertinoIcons.question_circle,
      title: 'Questions',
      detail: 'I ask every lead',
      trailing: IconButton(
        tooltip: 'Add question',
        onPressed: () => _add(context),
        icon: const Icon(CupertinoIcons.add_circled, size: 26),
      ),
      child: questions.isEmpty
          ? HubEmptyState(
              icon: CupertinoIcons.question_circle,
              title: 'No questions yet',
              message: 'Add what you need to know before booking a meeting.',
              actionLabel: 'Add question',
              onAction: () => _add(context),
            )
          : Column(
              children: [
                for (final (index, question) in questions.indexed) ...[
                  if (index > 0) const Divider(),
                  _QuestionRow(
                    question: question,
                    isFirst: index == 0,
                    isLast: index == questions.length - 1,
                    onAction: (action) => _handle(context, index, action),
                  ),
                ],
              ],
            ),
    );
  }
}

enum _QuestionAction { edit, toggleRequired, moveUp, moveDown, remove }

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.isFirst,
    required this.isLast,
    required this.onAction,
  });

  final QualifyingQuestion question;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<_QuestionAction> onAction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onAction(_QuestionAction.edit),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.text, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  HubPill(
                    label: question.required ? 'Required' : 'Optional',
                    tone: question.required
                        ? PillTone.accent
                        : PillTone.neutral,
                  ),
                ],
              ),
            ),
            PopupMenuButton<_QuestionAction>(
              tooltip: 'Question options',
              icon: const Icon(CupertinoIcons.ellipsis, size: 20),
              onSelected: onAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _QuestionAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: _QuestionAction.toggleRequired,
                  child: Text(
                    question.required ? 'Make optional' : 'Make required',
                  ),
                ),
                if (!isFirst)
                  const PopupMenuItem(
                    value: _QuestionAction.moveUp,
                    child: Text('Move up'),
                  ),
                if (!isLast)
                  const PopupMenuItem(
                    value: _QuestionAction.moveDown,
                    child: Text('Move down'),
                  ),
                PopupMenuItem(
                  value: _QuestionAction.remove,
                  child: Text(
                    'Remove',
                    style: TextStyle(color: HubColors.danger),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({
    required this.setup,
    required this.minimumBudget,
    required this.onChanged,
  });

  final LeadQualification setup;
  final TextEditingController minimumBudget;
  final ValueChanged<LeadQualification> onChanged;

  Future<void> _pickStart(BuildContext context) async {
    final months = await showHubPicker<int>(
      context,
      title: 'Wants to start within',
      selected: setup.startWithinMonths,
      options: [
        for (final months in _startOptions)
          HubPickerOption(value: months, label: _startLabel(months)),
      ],
    );
    if (months != null) onChanged(setup.copyWith(startWithinMonths: months));
  }

  Future<void> _addDisqualifier(BuildContext context) async {
    final text = await _askText(
      context,
      title: 'Not a fit when the caller is…',
      hint: 'Outside our service area',
    );
    if (text == null) return;
    onChanged(setup.copyWith(disqualifiers: [...setup.disqualifiers, text]));
  }

  @override
  Widget build(BuildContext context) {
    return HubCard(
      icon: CupertinoIcons.checkmark_shield,
      title: 'Rules',
      detail: 'for a qualified lead',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: minimumBudget,
            decoration: const InputDecoration(
              labelText: 'Minimum budget',
              hintText: r'$5,000',
              helperText: 'Leave blank to accept any budget.',
            ),
          ),
          const SizedBox(height: 16),
          HubSelectField(
            label: 'Wants to start within',
            value: _startLabel(setup.startWithinMonths),
            onTap: () => _pickStart(context),
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            title: 'Must be the decision-maker',
            subtitle: 'Or able to bring them to the meeting.',
            value: setup.requireDecisionMaker,
            onChanged: (value) =>
                onChanged(setup.copyWith(requireDecisionMaker: value)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Text(
            'Not a fit when the caller is…',
            style: TextStyle(color: HubColors.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, reason) in setup.disqualifiers.indexed)
                InputChip(
                  label: Text(reason),
                  onDeleted: () => onChanged(
                    setup.copyWith(
                      disqualifiers: [...setup.disqualifiers]..removeAt(index),
                    ),
                  ),
                ),
              ActionChip(
                avatar: const Icon(CupertinoIcons.add, size: 16),
                label: const Text('Add'),
                onPressed: () => _addDisqualifier(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({
    required this.setup,
    required this.bookingEnabled,
    required this.notAFitMessage,
    required this.onChanged,
  });

  final LeadQualification setup;
  final bool bookingEnabled;
  final TextEditingController notAFitMessage;
  final ValueChanged<LeadQualification> onChanged;

  Future<void> _pickLength(BuildContext context) async {
    final minutes = await showHubPicker<int>(
      context,
      title: 'Meeting length',
      selected: setup.meetingMinutes,
      options: [
        for (final minutes in _meetingLengths)
          HubPickerOption(value: minutes, label: '$minutes minutes'),
      ],
    );
    if (minutes != null) onChanged(setup.copyWith(meetingMinutes: minutes));
  }

  @override
  Widget build(BuildContext context) {
    return HubCard(
      icon: CupertinoIcons.arrow_turn_down_right,
      title: 'Next steps',
      detail: 'after I decide',
      child: Column(
        children: [
          _OutcomeSection(
            outcome: LeadOutcome.qualified,
            description: bookingEnabled
                ? 'I offer two times and book the meeting.'
                : 'Booking is off in Train, so I take a message and your team schedules the meeting.',
            child: HubSelectField(
              label: 'Meeting length',
              value: '${setup.meetingMinutes} minutes',
              onTap: () => _pickLength(context),
            ),
          ),
          const Divider(),
          _OutcomeSection(
            outcome: LeadOutcome.notAFit,
            description: 'I end the call politely and don’t book a meeting.',
            child: TextField(
              controller: notAFitMessage,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What to tell them (optional)',
                hintText: 'Our free planning guide is at acme.com/guide.',
              ),
            ),
          ),
          const Divider(),
          const _OutcomeSection(
            outcome: LeadOutcome.followUp,
            description:
                'When a required question goes unanswered or I’m unsure, I take a message and mark them Nurture in the CRM.',
          ),
        ],
      ),
    );
  }
}

class _OutcomeSection extends StatelessWidget {
  const _OutcomeSection({
    required this.outcome,
    required this.description,
    this.child,
  });

  final LeadOutcome outcome;
  final String description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadOutcomePill(outcome: outcome),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: HubColors.textMuted)),
          if (child != null) ...[const SizedBox(height: 12), child!],
        ],
      ),
    );
  }
}

class _LeadDetailsCard extends StatelessWidget {
  const _LeadDetailsCard({required this.collect, required this.onChanged});

  final Set<LeadField> collect;
  final ValueChanged<Set<LeadField>> onChanged;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      icon: CupertinoIcons.person_crop_rectangle,
      title: 'Lead details',
      detail: 'I collect',
      child: Column(
        children: [
          const _SwitchRow(
            title: 'Name',
            subtitle: 'Always collected.',
            value: true,
          ),
          for (final field in LeadField.values)
            _SwitchRow(
              title: field.label,
              value: collect.contains(field),
              onChanged: (value) => onChanged(
                value ? {...collect, field} : ({...collect}..remove(field)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    this.subtitle,
    this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: HubColors.textMuted)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Outcome badge shared by settings, call rows, and the call sheet.
class LeadOutcomePill extends StatelessWidget {
  const LeadOutcomePill({super.key, required this.outcome});

  final LeadOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return HubPill(
      label: outcome.label,
      tone: switch (outcome) {
        LeadOutcome.qualified => PillTone.success,
        LeadOutcome.followUp => PillTone.accent,
        LeadOutcome.notAFit => PillTone.danger,
      },
    );
  }
}

/// Returns the trimmed text, or null when cancelled or left empty.
Future<String?> _askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(title: title, initial: initial, hint: hint),
  );
  final trimmed = text?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.initial, this.hint});

  final String title;
  final String initial;
  final String? hint;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
