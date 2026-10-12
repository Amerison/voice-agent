import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'call_sheet.dart';
import 'contact_screens.dart';
import 'models.dart';
import 'number_picker.dart';
import 'repository.dart';
import 'theme.dart';
import 'voice_test_sheet.dart';
import 'widgets.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key, required this.error, required this.onRetry});

  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 64),
                const SizedBox(height: 24),
                if (error == null)
                  const CircularProgressIndicator()
                else ...[
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);

  final String label;
  final IconData icon;
}

const _bottomDestinations = [
  _Destination('Home', CupertinoIcons.house),
  _Destination('Train', CupertinoIcons.book),
  _Destination('CRM', CupertinoIcons.person_crop_rectangle),
];

enum _WorkspaceRoute { home, train, crm, identity, deploy, calls, settings }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  _WorkspaceRoute _route = _WorkspaceRoute.home;
  int _bottomIndex = 0;

  void _selectBottom(int index) => setState(() {
    _bottomIndex = index;
    _route = switch (index) {
      0 => _WorkspaceRoute.home,
      1 => _WorkspaceRoute.train,
      _ => _WorkspaceRoute.crm,
    };
  });

  void _selectRoute(_WorkspaceRoute route) => setState(() => _route = route);

  String get _routeTitle => switch (_route) {
    _WorkspaceRoute.home => 'Home',
    _WorkspaceRoute.train => 'Train',
    _WorkspaceRoute.crm => 'Contacts',
    _WorkspaceRoute.identity => 'Identity',
    _WorkspaceRoute.deploy => 'Deploy',
    _WorkspaceRoute.calls => 'Calls',
    _WorkspaceRoute.settings => 'Settings',
  };

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final pages = [
      HomeScreen(controller: controller),
      TrainScreen(controller: controller),
      CrmScreen(controller: controller),
      IdentityScreen(controller: controller),
      DeployScreen(controller: controller),
      CallsScreen(controller: controller),
      SettingsScreen(controller: controller),
    ];
    return Scaffold(
      drawer: _WorkspaceDrawer(
        controller: controller,
        selectedRoute: _route,
        onSelect: (route) {
          Navigator.pop(context);
          _selectRoute(route);
        },
      ),
      appBar: AppBar(
        title: Text(_routeTitle),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(CupertinoIcons.line_horizontal_3, size: 26),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create',
            onPressed: () => _showQuickCreate(context, controller),
            icon: const Icon(CupertinoIcons.add, size: 26),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (controller.error != null)
            HubBanner(
              text: controller.error!,
              icon: CupertinoIcons.exclamationmark_circle,
              color: HubColors.danger,
              onClose: controller.clearError,
            ),
          if (controller.isBusy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: IndexedStack(index: _route.index, children: pages),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: BreezeButton(
        label: controller.data.agent.name.trim().isEmpty
            ? 'Test agent'
            : 'Test ${controller.data.agent.name}',
        icon: CupertinoIcons.waveform,
        onPressed: () => showVoiceTestSheet(context, controller),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: HubColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _bottomIndex,
          onDestinationSelected: _selectBottom,
          destinations: [
            for (final destination in _bottomDestinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDrawer extends StatelessWidget {
  const _WorkspaceDrawer({
    required this.controller,
    required this.selectedRoute,
    required this.onSelect,
  });

  final AppController controller;
  final _WorkspaceRoute selectedRoute;
  final ValueChanged<_WorkspaceRoute> onSelect;

  @override
  Widget build(BuildContext context) {
    final agent = controller.data.agent;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            _DrawerAccount(agent: agent),
            const SizedBox(height: 18),
            _ExperienceCard(
              typeLabel: agent.type.label,
              onTap: () => _pickAgentType(context),
            ),
            const SizedBox(height: 10),
            _DrawerItem(
              destination: const _Destination(
                'Identity',
                CupertinoIcons.person_crop_circle,
              ),
              selected: selectedRoute == _WorkspaceRoute.identity,
              onTap: () => onSelect(_WorkspaceRoute.identity),
            ),
            _DrawerItem(
              destination: _bottomDestinations[1],
              selected: selectedRoute == _WorkspaceRoute.train,
              onTap: () => onSelect(_WorkspaceRoute.train),
            ),
            _DrawerItem(
              destination: const _Destination('Deploy', CupertinoIcons.rocket),
              selected: selectedRoute == _WorkspaceRoute.deploy,
              onTap: () => onSelect(_WorkspaceRoute.deploy),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Divider(),
            ),
            _DrawerItem(
              destination: const _Destination('Calls', CupertinoIcons.phone),
              trailing: controller.data.calls.isEmpty
                  ? null
                  : '${controller.data.calls.length}',
              selected: selectedRoute == _WorkspaceRoute.calls,
              onTap: () => onSelect(_WorkspaceRoute.calls),
            ),
            _DrawerItem(
              destination: const _Destination(
                'CRM',
                CupertinoIcons.person_crop_rectangle,
              ),
              trailing: controller.data.contacts.isEmpty
                  ? null
                  : '${controller.data.contacts.length}',
              selected: selectedRoute == _WorkspaceRoute.crm,
              onTap: () => onSelect(_WorkspaceRoute.crm),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Divider(),
            ),
            _DrawerItem(
              destination: const _Destination('Settings', CupertinoIcons.gear),
              selected: selectedRoute == _WorkspaceRoute.settings,
              onTap: () => onSelect(_WorkspaceRoute.settings),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAgentType(BuildContext context) async {
    final value = await showHubPicker<AgentType>(
      context,
      title: 'Agent type',
      selected: controller.data.agent.type,
      options: [
        HubPickerOption(
          value: AgentType.receptionist,
          label: AgentType.receptionist.label,
          subtitle: 'Answer calls, take messages, and book appointments',
        ),
        HubPickerOption(
          value: AgentType.leadQualification,
          label: AgentType.leadQualification.label,
          subtitle: 'Qualify inbound prospects and book meetings',
        ),
        HubPickerOption(
          value: AgentType.customerSupport,
          label: AgentType.customerSupport.label,
          subtitle: 'Coming next',
          enabled: false,
        ),
        HubPickerOption(
          value: AgentType.outboundCalling,
          label: AgentType.outboundCalling.label,
          subtitle: 'Coming soon',
          enabled: false,
        ),
      ],
    );
    if (value == null) return;
    await controller.updateAgent(controller.data.agent.copyWith(type: value));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return HubPage(
      headline: 'Make the workspace feel right for you.',
      children: [
        HubCard(
          icon: controller.isDarkMode
              ? CupertinoIcons.moon_fill
              : CupertinoIcons.sun_max_fill,
          title: 'Appearance',
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use the darker color palette throughout the app.',
                      style: TextStyle(color: HubColors.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: controller.isDarkMode,
                onChanged: controller.setDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerAccount extends StatelessWidget {
  const _DrawerAccount({required this.agent});

  final AgentConfig agent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agent.name.trim().isEmpty ? 'Your agent' : agent.name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  formatPhone(agent.phoneNumber ?? agent.reservedNumber) ??
                      'No phone number yet',
                  style: TextStyle(color: HubColors.textMuted),
                ),
              ),
              if (agent.phoneNumber case final number?)
                IconButton(
                  tooltip: 'Copy number',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => copyPhoneNumber(context, number),
                  icon: Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 16,
                    color: HubColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.typeLabel, required this.onTap});

  final String typeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HubColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HubColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agent type',
                      style: TextStyle(
                        fontSize: 13,
                        color: HubColors.textMuted,
                      ),
                    ),
                    Text(typeLabel, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HubColors.surfaceRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Row(
            children: [
              Icon(destination.icon, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  destination.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: TextStyle(color: HubColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

void _showQuickCreate(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      void run(Future<void> Function() action) {
        Navigator.pop(sheetContext);
        action();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
                child: Text(
                  'Create',
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
              ),
              HubGroup(
                children: [
                  _QuickCreateRow(
                    icon: CupertinoIcons.person_badge_plus,
                    label: 'Contact',
                    onTap: () => run(() => editContact(context, controller)),
                  ),
                  _QuickCreateRow(
                    icon: CupertinoIcons.globe,
                    label: 'Webpage knowledge',
                    onTap: () => run(
                      () => addKnowledgeSource(
                        context,
                        controller,
                        kind: KnowledgeKind.webpage,
                      ),
                    ),
                  ),
                  _QuickCreateRow(
                    icon: CupertinoIcons.question_circle,
                    label: 'Short answer',
                    onTap: () => run(
                      () => addKnowledgeSource(
                        context,
                        controller,
                        kind: KnowledgeKind.shortAnswer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QuickCreateRow extends StatelessWidget {
  const _QuickCreateRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            IconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Icon(CupertinoIcons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}

Future<void> addKnowledgeSource(
  BuildContext context,
  AppController controller, {
  KnowledgeKind? kind,
}) async {
  final draft = await showHubEditor<_KnowledgeDraft>(
    context,
    _AddKnowledgePage(initialKind: kind),
  );
  if (draft == null || !context.mounted) return;
  try {
    if (draft.kind == KnowledgeKind.webpage) {
      await controller.addWebpage(draft.content);
    } else {
      await controller.addShortAnswer(draft.content, draft.answer ?? '');
    }
  } on WorkspaceException catch (error) {
    if (context.mounted) showHubMessage(context, error.message);
  }
}

class _KnowledgeDraft {
  const _KnowledgeDraft({
    required this.kind,
    required this.content,
    this.answer,
  });

  final KnowledgeKind kind;
  final String content;
  final String? answer;
}

class _AddKnowledgePage extends StatefulWidget {
  const _AddKnowledgePage({this.initialKind});

  final KnowledgeKind? initialKind;

  @override
  State<_AddKnowledgePage> createState() => _AddKnowledgePageState();
}

class _AddKnowledgePageState extends State<_AddKnowledgePage> {
  late KnowledgeKind _kind;
  final _url = TextEditingController();
  final _question = TextEditingController();
  final _answer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind ?? KnowledgeKind.webpage;
  }

  @override
  void dispose() {
    _url.dispose();
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _save() {
    if (_kind == KnowledgeKind.webpage) {
      Navigator.pop(context, _KnowledgeDraft(kind: _kind, content: _url.text));
      return;
    }
    Navigator.pop(
      context,
      _KnowledgeDraft(
        kind: _kind,
        content: _question.text,
        answer: _answer.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HubEditorPage(
      title: 'Add knowledge',
      doneLabel: 'Add',
      onDone: _save,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 28,
        ),
        children: [
          Text(
            'Choose a source',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          HubGroup(
            children: [
              _KnowledgeKindRow(
                icon: CupertinoIcons.globe,
                title: 'Webpage URL',
                subtitle: 'The agent can answer from this page.',
                selected: _kind == KnowledgeKind.webpage,
                onTap: () => setState(() => _kind = KnowledgeKind.webpage),
              ),
              _KnowledgeKindRow(
                icon: CupertinoIcons.question_circle,
                title: 'Short answer',
                subtitle: 'A question and the exact reply to use.',
                selected: _kind == KnowledgeKind.shortAnswer,
                onTap: () => setState(() => _kind = KnowledgeKind.shortAnswer),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (_kind == KnowledgeKind.webpage)
            TextField(
              key: const ValueKey('url'),
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Page URL',
                hintText: 'https://example.com/pricing',
              ),
            )
          else ...[
            TextField(
              key: const ValueKey('question'),
              controller: _question,
              autofocus: true,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'What are your opening hours?',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('answer'),
              controller: _answer,
              minLines: 4,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Answer',
                hintText: 'We’re open 9am to 5pm, Monday to Friday.',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeKindRow extends StatelessWidget {
  const _KnowledgeKindRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: HubColors.textMuted),
                  ),
                ],
              ),
            ),
            SquareCheck(checked: selected),
          ],
        ),
      ),
    );
  }
}

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  late final TextEditingController _name;
  late final TextEditingController _persona;
  late final TextEditingController _company;
  late final TextEditingController _description;
  late final TextEditingController _greeting;
  late Friendliness _friendliness;

  @override
  void initState() {
    super.initState();
    final agent = widget.controller.data.agent;
    _name = TextEditingController(text: agent.name);
    _persona = TextEditingController(text: agent.persona);
    _company = TextEditingController(text: agent.companyName);
    _description = TextEditingController(text: agent.companyDescription);
    _greeting = TextEditingController(text: agent.greeting);
    _friendliness = agent.friendliness;
  }

  @override
  void dispose() {
    _name.dispose();
    _persona.dispose();
    _company.dispose();
    _description.dispose();
    _greeting.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _greeting.text.trim().isEmpty) {
      showHubMessage(context, 'Agent name and greeting are required.');
      return;
    }
    await widget.controller.updateAgent(
      widget.controller.data.agent.copyWith(
        name: _name.text.trim(),
        friendliness: _friendliness,
        persona: _persona.text.trim(),
        companyName: _company.text.trim(),
        companyDescription: _description.text.trim(),
        greeting: _greeting.text.trim(),
      ),
    );
    if (mounted) showHubMessage(context, 'Identity saved');
  }

  @override
  Widget build(BuildContext context) {
    return HubPage(
      headline: 'Shape who answers the phone and how they sound.',
      children: [
        HubCard(
          icon: CupertinoIcons.person_crop_circle,
          title: 'Agent',
          detail: 'voice and persona',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Agent name'),
              ),
              const SizedBox(height: 16),
              Text(
                'Friendliness',
                style: TextStyle(color: HubColors.textMuted),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<Friendliness>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: Friendliness.professional,
                      label: Text('Professional'),
                    ),
                    ButtonSegment(
                      value: Friendliness.neutral,
                      label: Text('Neutral'),
                    ),
                    ButtonSegment(
                      value: Friendliness.friendly,
                      label: Text('Friendly'),
                    ),
                  ],
                  selected: {_friendliness},
                  onSelectionChanged: (value) =>
                      setState(() => _friendliness = value.first),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _persona,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Persona',
                  hintText: 'An experienced sales development representative',
                ),
              ),
            ],
          ),
        ),
        HubCard(
          icon: CupertinoIcons.briefcase,
          title: 'Company',
          detail: 'details',
          child: Column(
            children: [
              TextField(
                controller: _company,
                decoration: const InputDecoration(labelText: 'Company name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'What does the company do?',
                ),
              ),
            ],
          ),
        ),
        HubCard(
          icon: CupertinoIcons.quote_bubble,
          title: 'Welcome',
          detail: 'message',
          child: TextField(
            controller: _greeting,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Greeting',
              helperText: 'The first line callers hear.',
            ),
          ),
        ),
        FilledButton(onPressed: _save, child: const Text('Save identity')),
      ],
    );
  }
}

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  late final TextEditingController _guidelines;

  @override
  void initState() {
    super.initState();
    _guidelines = TextEditingController(
      text: widget.controller.data.agent.guidelines,
    );
  }

  @override
  void dispose() {
    _guidelines.dispose();
    super.dispose();
  }

  Future<void> _saveGuidelines() async {
    await widget.controller.updateAgent(
      widget.controller.data.agent.copyWith(
        guidelines: _guidelines.text.trim(),
      ),
    );
    if (mounted) showHubMessage(context, 'Training saved');
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final agent = controller.data.agent;
    return HubPage(
      key: const PageStorageKey('train'),
      children: [
        HubCard(
          icon: CupertinoIcons.book,
          title: 'Knowledge',
          detail: 'sources',
          trailing: IconButton(
            tooltip: 'Add knowledge',
            onPressed: () => addKnowledgeSource(context, controller),
            icon: const Icon(CupertinoIcons.add_circled, size: 26),
          ),
          child: agent.knowledgeSources.isEmpty
              ? HubEmptyState(
                  icon: CupertinoIcons.book,
                  title: 'No knowledge yet',
                  message: 'Add a webpage or a short answer.',
                  actionLabel: 'Add webpage',
                  onAction: () => addKnowledgeSource(
                    context,
                    controller,
                    kind: KnowledgeKind.webpage,
                  ),
                )
              : Column(
                  children: [
                    for (final source in agent.knowledgeSources)
                      _KnowledgeRow(
                        source: source,
                        onRemove: () =>
                            controller.removeKnowledgeSource(source.id),
                      ),
                  ],
                ),
        ),
        HubCard(
          icon: CupertinoIcons.bolt,
          title: 'Actions',
          detail: 'the agent can take',
          child: Column(
            children: [
              _ActionTile(
                icon: CupertinoIcons.calendar,
                title: 'Book a meeting',
                subtitle: 'Offer mock availability and create a meeting.',
                value: agent.bookMeetingEnabled,
                onChanged: (value) => controller.updateAgent(
                  agent.copyWith(bookMeetingEnabled: value),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(),
              ),
              _ActionTile(
                icon: CupertinoIcons.person_badge_plus,
                title: 'Create contact',
                subtitle: 'Save confirmed caller details to the CRM.',
                value: agent.createContactEnabled,
                onChanged: (value) => controller.updateAgent(
                  agent.copyWith(createContactEnabled: value),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(),
              ),
              _ActionTile(
                icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                title: 'Qualify leads',
                subtitle: 'Mark good-fit callers as qualified in reports.',
                value: agent.qualifyLeadsEnabled,
                onChanged: (value) => controller.updateAgent(
                  agent.copyWith(qualifyLeadsEnabled: value),
                ),
              ),
            ],
          ),
        ),
        HubCard(
          icon: CupertinoIcons.list_bullet,
          title: 'Guidelines',
          detail: 'and boundaries',
          child: TextField(
            controller: _guidelines,
            minLines: 7,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'One rule per line…',
              helperText: 'These rules override the starter behavior.',
              alignLabelWithHint: true,
            ),
          ),
        ),
        FilledButton(
          onPressed: _saveGuidelines,
          child: const Text('Save training'),
        ),
      ],
    );
  }
}

class _KnowledgeRow extends StatelessWidget {
  const _KnowledgeRow({required this.source, required this.onRemove});

  final KnowledgeSource source;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isWebpage = source.kind == KnowledgeKind.webpage;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: isWebpage
                ? CupertinoIcons.globe
                : CupertinoIcons.question_circle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  isWebpage ? source.content : source.answer ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HubColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(CupertinoIcons.xmark, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: TextStyle(color: HubColors.textMuted)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final calls = [...controller.data.calls]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final meetings =
        controller.data.meetings
            .where((meeting) => meeting.startsAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final realCalls = calls.where((call) => !call.isTest).toList();
    final resolved = realCalls.where((call) => call.resolved).length;
    final showQualified = controller.data.agent.qualifyLeadsEnabled;
    final qualified = controller.data.contacts
        .where((contact) => contact.leadStatus == 'Qualified')
        .length;
    final number = formatPhone(controller.data.agent.phoneNumber);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: HubPage(
        key: const PageStorageKey('home'),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.phone,
                  value: '${calls.length}',
                  label: 'Calls',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: CupertinoIcons.checkmark_circle,
                  value: realCalls.isEmpty
                      ? '—'
                      : '${(resolved / realCalls.length * 100).round()}%',
                  label: 'Resolved',
                ),
              ),
            ],
          ),
          HubCard(
            icon: CupertinoIcons.chart_bar,
            title: 'Report',
            detail: 'latest performance',
            child: Column(
              children: [
                if (showQualified) ...[
                  _OverviewRow(
                    icon: CupertinoIcons.person_2,
                    label: 'Qualified leads',
                    value: '$qualified',
                  ),
                  const Divider(),
                ],
                _OverviewRow(
                  icon: CupertinoIcons.calendar,
                  label: 'Upcoming meetings',
                  value: '${meetings.length}',
                ),
                const Divider(),
                _OverviewRow(
                  icon: CupertinoIcons.person_badge_plus,
                  label: 'CRM contacts',
                  value: '${controller.data.contacts.length}',
                ),
              ],
            ),
          ),
          HubCard(
            icon: CupertinoIcons.phone,
            title: 'Incoming calls',
            detail: 'recent activity',
            child: calls.isEmpty
                ? HubEmptyState(
                    icon: CupertinoIcons.phone,
                    title: 'You have no calls',
                    message: number == null
                        ? 'Calls will appear here after they end.'
                        : 'Call $number to try it. Calls appear here after they end.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < calls.take(3).length; i++) ...[
                        if (i > 0) const Divider(),
                        _CallRow(call: calls[i]),
                      ],
                    ],
                  ),
          ),
          HubCard(
            icon: CupertinoIcons.calendar,
            title: 'Meetings',
            detail: 'coming up',
            child: meetings.isEmpty
                ? const HubEmptyState(
                    icon: CupertinoIcons.calendar,
                    title: 'Nothing scheduled',
                    message: 'Meetings booked by the agent will appear here.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < meetings.take(3).length; i++) ...[
                        if (i > 0) const Divider(),
                        _MeetingRow(meeting: meetings[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final calls = [...controller.data.calls]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: HubPage(
        headline: 'Review every conversation and its outcome.',
        children: [
          HubCard(
            icon: CupertinoIcons.phone,
            title: 'Call history',
            detail: '${calls.length} total',
            child: calls.isEmpty
                ? const HubEmptyState(
                    icon: CupertinoIcons.phone,
                    title: 'You have no calls',
                    message: 'Calls will appear here after they end.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < calls.length; i++) ...[
                        if (i > 0) const Divider(),
                        _CallRow(call: calls[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: HubColors.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const IconBadge(icon: CupertinoIcons.calendar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.contactName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatTimestamp(meeting.startsAt),
                  style: TextStyle(color: HubColors.textMuted),
                ),
              ],
            ),
          ),
          HubPill(label: meeting.status, tone: PillTone.accent),
        ],
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.call});

  final CallRecord call;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showCallSheet(context, call),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            call.isTest
                ? const IconBadge(icon: CupertinoIcons.waveform)
                : IconBadge(
                    icon: call.resolved
                        ? CupertinoIcons.checkmark_alt
                        : CupertinoIcons.xmark,
                    iconColor: call.resolved
                        ? HubColors.success
                        : HubColors.danger,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.callerNumber,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${relativeDate(call.startedAt)} · ${formatDuration(call.durationSeconds)}',
                    style: TextStyle(color: HubColors.textMuted),
                  ),
                ],
              ),
            ),
            call.isTest
                ? const HubPill(label: 'Test call')
                : HubPill(
                    label: call.resolved ? 'Resolved' : 'Unresolved',
                    tone: call.resolved ? PillTone.success : PillTone.danger,
                  ),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: HubColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class DeployScreen extends StatelessWidget {
  const DeployScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final agent = controller.data.agent;
    return HubPage(
      headline: 'Turn your configuration into a live phone agent.',
      children: [
        HubCard(
          icon: CupertinoIcons.square_list,
          title: 'Readiness',
          detail: 'checklist',
          child: Column(
            children: [
              _ChecklistItem(
                done: agent.name.trim().isNotEmpty,
                text: 'Identity complete',
              ),
              _ChecklistItem(
                done: agent.guidelines.trim().isNotEmpty,
                text: 'Guidelines added',
              ),
              _ChecklistItem(
                done: agent.knowledgeSources.isNotEmpty,
                text: 'Knowledge added',
              ),
              _ChecklistItem(
                done:
                    agent.bookMeetingEnabled ||
                    agent.createContactEnabled ||
                    agent.qualifyLeadsEnabled,
                text: 'At least one action enabled',
              ),
            ],
          ),
        ),
        if (agent.phoneNumber == null)
          HubCard(
            icon: CupertinoIcons.phone,
            title: 'Phone',
            detail: 'number',
            child: HubEmptyState(
              icon: CupertinoIcons.phone,
              title: 'Get a phone number',
              message: 'Choose a US area code for one inbound number.',
              actionLabel: 'Get number',
              onAction: controller.isBusy ? null : () => _provision(context),
            ),
          )
        else
          _LiveNumberCard(agent: agent),
      ],
    );
  }

  Future<void> _provision(BuildContext context) async {
    final choice = await showNumberPicker(
      context,
      controller,
      doneLabel: 'Get',
    );
    if (choice == null || !context.mounted) return;
    try {
      await controller.provisionNumber(choice.areaCode, number: choice.number);
    } on WorkspaceException catch (error) {
      if (context.mounted) showHubMessage(context, error.message);
    }
  }
}

class _LiveNumberCard extends StatelessWidget {
  const _LiveNumberCard({required this.agent});

  final AgentConfig agent;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: HubColors.breeze,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE NUMBER',
            style: TextStyle(
              fontFamily: HubFonts.mono,
              fontSize: 12,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatPhone(agent.phoneNumber)!,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Inbound calls route to ${agent.name}.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                style: style,
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: agent.phoneNumber)),
                icon: const Icon(CupertinoIcons.phone, size: 18),
                label: const Text('Call agent'),
              ),
              OutlinedButton.icon(
                style: style,
                onPressed: () => copyPhoneNumber(context, agent.phoneNumber!),
                icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.done, required this.text});

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
            color: done ? HubColors.success : HubColors.textSubtle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: done ? HubColors.text : HubColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
