import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'call_sheet.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const _leadStatuses = ['New', 'Qualified', 'Nurture', 'Disqualified'];
const _budgetRanges = [
  'Not shared',
  r'Under $10k',
  r'$10k–$25k',
  r'$25k–$50k',
  r'$50k+',
];

PillTone _statusTone(String status) => switch (status) {
  'Qualified' => PillTone.success,
  'Disqualified' => PillTone.danger,
  'New' => PillTone.accent,
  _ => PillTone.neutral,
};

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
    final contacts = data.contacts.where((contact) {
      final haystack = '${contact.name} ${contact.company} ${contact.email}'
          .toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();
    return ListView(
      key: const PageStorageKey('Contacts'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(CupertinoIcons.search, size: 20),
            hintText: 'Search Contacts',
          ),
        ),
        const SizedBox(height: 22),
        if (data.contacts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${data.contacts.length} contacts and ${data.meetings.length} upcoming meetings.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 22),
        ],
        if (data.contacts.isEmpty)
          HubEmptyState(
            icon: CupertinoIcons.person_crop_rectangle,
            title: 'You have no contacts',
            message: 'Add a contact to start your CRM.',
            actionLabel: 'Create contact',
            onAction: () => editContact(context, widget.controller),
          )
        else if (contacts.isEmpty)
          const HubEmptyState(
            icon: CupertinoIcons.search,
            title: 'No contacts found',
            message: 'No contacts match your search.',
          )
        else
          HubGroup(
            children: [
              for (final contact in contacts)
                _ContactRow(
                  contact: contact,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ContactDetailScreen(
                        controller: widget.controller,
                        contactId: contact.id,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final Contact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(name: contact.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${contact.jobTitle} · ${contact.company}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: HubColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HubPill(
              label: contact.leadStatus,
              tone: _statusTone(contact.leadStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({
    super.key,
    required this.controller,
    required this.contactId,
  });

  final AppController controller;
  final String contactId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final contact = controller.data.contacts
            .where((item) => item.id == contactId)
            .firstOrNull;
        if (contact == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.pop(context);
            }
          });
          return const Scaffold();
        }
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.chevron_left),
              ),
              title: _ContactTitle(contact: contact),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(CupertinoIcons.ellipsis_vertical),
                  onSelected: (value) => value == 'edit'
                      ? editContact(context, controller, contact)
                      : controller.deleteContact(contact.id),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit contact')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete contact',
                        style: TextStyle(color: HubColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                const SizedBox(height: 8),
                _ContactActions(
                  contact: contact,
                  onEdit: () => editContact(context, controller, contact),
                ),
                const SizedBox(height: 14),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Activity'),
                    Tab(text: 'About'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ActivityTab(
                        activities: _activitiesFor(contact, controller.data),
                      ),
                      _AboutTab(contact: contact),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactTitle extends StatelessWidget {
  const _ContactTitle({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name: contact.name, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: HubFonts.sans,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: HubFonts.sans,
                    fontSize: 14,
                    color: HubColors.textMuted,
                  ),
                  children: [
                    TextSpan(
                      text: 'Contact',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HubColors.text,
                      ),
                    ),
                    TextSpan(text: ' | ${contact.jobTitle}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.contact, required this.onEdit});

  final Contact contact;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasPhone = contact.phone.trim().isNotEmpty;
    final hasEmail = contact.email.trim().isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CircleAction(
          icon: CupertinoIcons.phone,
          label: 'Call',
          onTap: hasPhone
              ? () => launchUrl(Uri(scheme: 'tel', path: contact.phone))
              : null,
        ),
        CircleAction(
          icon: CupertinoIcons.envelope,
          label: 'Email',
          onTap: hasEmail
              ? () => launchUrl(Uri(scheme: 'mailto', path: contact.email))
              : null,
        ),
        CircleAction(
          icon: CupertinoIcons.chat_bubble_2,
          label: 'Text',
          onTap: hasPhone
              ? () => launchUrl(Uri(scheme: 'sms', path: contact.phone))
              : null,
        ),
        CircleAction(icon: CupertinoIcons.pencil, label: 'Edit', onTap: onEdit),
      ],
    );
  }
}

class _Activity {
  const _Activity({
    required this.title,
    required this.date,
    required this.body,
    this.call,
  });

  final String title;
  final DateTime date;
  final String body;
  final CallRecord? call;
}

List<_Activity> _activitiesFor(Contact contact, WorkspaceData data) {
  final phone = _phoneKey(contact.phone);
  return [
    for (final call in data.calls)
      if (phone.isNotEmpty && _phoneKey(call.callerNumber) == phone)
        _Activity(
          title: 'Inbound call',
          date: call.startedAt,
          body: call.resolutionReason,
          call: call,
        ),
    for (final meeting in data.meetings)
      if (meeting.contactId == contact.id)
        _Activity(
          title: 'Meeting',
          date: meeting.startsAt,
          body: '${meeting.status} discovery meeting with ${contact.name}.',
        ),
    _Activity(
      title: 'Contact created',
      date: contact.createdAt,
      body: 'Added from ${contact.leadSource.toLowerCase()}.',
    ),
  ]..sort((a, b) => b.date.compareTo(a.date));
}

String _phoneKey(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.activities});

  final List<_Activity> activities;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? month;
    for (final activity in activities) {
      final label = formatMonth(activity.date);
      if (label != month) {
        month = label;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Text(label, style: const TextStyle(fontSize: 17)),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ActivityCard(activity: activity),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: children,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    final call = activity.call;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: call == null ? null : () => showCallSheet(context, call),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.title, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              DateChip(date: activity.date),
              const SizedBox(height: 12),
              Text(activity.body, style: const TextStyle(fontSize: 16)),
              if (call != null) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 14, bottom: 8),
                  child: Divider(),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(CupertinoIcons.chevron_right, size: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Email', contact.email),
      ('Phone', contact.phone),
      ('Company', contact.company),
      ('Job title', contact.jobTitle),
      ('Lead status', contact.leadStatus),
      ('Budget range', contact.budgetRange),
      ('Lead source', contact.leadSource),
      ('Notes', contact.notes),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
      children: [
        HubGroup(
          children: [
            for (final (label, value) in fields)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: HubColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.trim().isEmpty ? '—' : value,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> editContact(
  BuildContext context,
  AppController controller, [
  Contact? contact,
]) async {
  final result = await showHubEditor<_ContactResult>(
    context,
    _ContactEditor(contact: contact),
  );
  if (result == null) return;
  if (result.delete && contact != null) {
    await controller.deleteContact(contact.id);
  } else if (result.contact != null) {
    await controller.saveContact(result.contact!);
  }
}

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({this.contact});

  final Contact? contact;

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _company;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late String _status;
  late String _budget;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _name = TextEditingController(text: contact?.name ?? '');
    _phone = TextEditingController(text: contact?.phone ?? '');
    _email = TextEditingController(text: contact?.email ?? '');
    _company = TextEditingController(text: contact?.company ?? '');
    _title = TextEditingController(text: contact?.jobTitle ?? '');
    _notes = TextEditingController(text: contact?.notes ?? '');
    _status = contact?.leadStatus ?? 'New';
    _budget = contact?.budgetRange ?? 'Not shared';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _company.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick({
    required String title,
    required List<String> values,
    required String current,
    required ValueChanged<String> onPicked,
  }) async {
    final value = await showHubPicker<String>(
      context,
      title: title,
      selected: current,
      options: [
        for (final value in values) HubPickerOption(value: value, label: value),
      ],
    );
    if (value != null) setState(() => onPicked(value));
  }

  @override
  Widget build(BuildContext context) {
    return HubEditorPage(
      title: widget.contact == null ? 'New contact' : 'Edit contact',
      doneLabel: 'Save',
      onDone: _save,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _company,
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Job title'),
          ),
          const SizedBox(height: 12),
          HubSelectField(
            label: 'Lead status',
            value: _status,
            onTap: () => _pick(
              title: 'Lead status',
              values: _leadStatuses,
              current: _status,
              onPicked: (value) => _status = value,
            ),
          ),
          const SizedBox(height: 12),
          HubSelectField(
            label: 'Budget range',
            value: _budget,
            onTap: () => _pick(
              title: 'Budget range',
              values: _budgetRanges,
              current: _budget,
              onPicked: (value) => _budget = value,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          if (widget.contact != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: HubColors.danger,
                side: const BorderSide(color: HubColors.danger),
              ),
              onPressed: () =>
                  Navigator.pop(context, const _ContactResult(delete: true)),
              icon: const Icon(CupertinoIcons.trash, size: 18),
              label: const Text('Delete contact'),
            ),
          ],
        ],
      ),
    );
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      showHubMessage(context, 'Name is required.');
      return;
    }
    Navigator.pop(
      context,
      _ContactResult(
        contact: Contact(
          id:
              widget.contact?.id ??
              'contact-${DateTime.now().microsecondsSinceEpoch}',
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          company: _company.text.trim(),
          jobTitle: _title.text.trim(),
          leadSource: widget.contact?.leadSource ?? 'Manual',
          leadStatus: _status,
          budgetRange: _budget,
          notes: _notes.text.trim(),
          createdAt: widget.contact?.createdAt ?? DateTime.now(),
        ),
      ),
    );
  }
}

class _ContactResult {
  const _ContactResult({this.contact, this.delete = false});

  final Contact? contact;
  final bool delete;
}
