import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_controller.dart';
import 'call_sheet.dart';
import 'contact_screens.dart';
import 'models.dart';
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

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
          children: [
            const Align(alignment: Alignment.centerLeft, child: BrandMark()),
            const SizedBox(height: 32),
            Text(formatLongDate(DateTime.now()), style: textTheme.labelSmall),
            const SizedBox(height: 10),
            Text('What should your\nagent do?', style: textTheme.displaySmall),
            const SizedBox(height: 12),
            Text(
              'Start with a proven playbook. You can shape the voice, knowledge, and behavior next.',
              style: textTheme.bodyLarge?.copyWith(color: HubColors.textMuted),
            ),
            const SizedBox(height: 28),
            const _AgentTypeCard(
              icon: CupertinoIcons.person_crop_circle_badge_checkmark,
              title: 'Lead qualification',
              description:
                  'Qualify inbound prospects and book the right next step.',
              selected: true,
              badge: 'Available',
            ),
            const SizedBox(height: 12),
            const _AgentTypeCard(
              icon: CupertinoIcons.headphones,
              title: 'Customer support',
              description: 'Answer questions and resolve customer issues.',
              badge: 'Next',
              disabled: true,
            ),
            const SizedBox(height: 12),
            const _AgentTypeCard(
              icon: CupertinoIcons.phone_arrow_up_right,
              title: 'Outbound calling',
              description: 'Reach leads and customers proactively.',
              badge: 'Coming soon',
              disabled: true,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : controller.completeOnboarding,
              icon: const Icon(CupertinoIcons.arrow_right, size: 20),
              label: const Text('Build my agent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentTypeCard extends StatelessWidget {
  const _AgentTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    this.selected = false,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final bool selected;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? .5 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HubColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? HubColors.orange : HubColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: icon,
              size: 44,
              color: selected ? HubColors.orange : HubColors.background,
              iconColor: selected ? Colors.white : HubColors.text,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      HubPill(
                        label: badge,
                        tone: selected ? PillTone.accent : PillTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(color: HubColors.textMuted),
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
        actions: _route == _WorkspaceRoute.crm
            ? null
            : [
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
        label: 'Test ${controller.data.agent.name}',
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
            _ExperienceCard(onTap: () => _pickAgentType(context)),
            const SizedBox(height: 10),
            const _DrawerSectionLabel('Agent'),
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
            const _DrawerSectionLabel('CRM'),
            _DrawerItem(
              destination: const _Destination('Calls', CupertinoIcons.phone),
              trailing: '${controller.data.calls.length}',
              selected: selectedRoute == _WorkspaceRoute.calls,
              onTap: () => onSelect(_WorkspaceRoute.calls),
            ),
            _DrawerItem(
              destination: const _Destination(
                'CRM',
                CupertinoIcons.person_crop_rectangle,
              ),
              trailing: '${controller.data.contacts.length}',
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

  Future<void> _pickAgentType(BuildContext context) {
    return showHubPicker<String>(
      context,
      title: 'Agent type',
      selected: 'lead',
      options: const [
        HubPickerOption(
          value: 'lead',
          label: 'Lead qualification',
          subtitle: 'Qualify inbound prospects and book meetings',
        ),
        HubPickerOption(
          value: 'support',
          label: 'Customer support',
          subtitle: 'Coming next',
          enabled: false,
        ),
        HubPickerOption(
          value: 'outbound',
          label: 'Outbound calling',
          subtitle: 'Coming soon',
          enabled: false,
        ),
      ],
    );
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
    return Row(
      children: [
        const BrandMark(size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${agent.name} · ${agent.companyName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                agent.phoneNumber ?? 'No phone number yet',
                style: TextStyle(color: HubColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.onTap});

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
                    Text('Lead qualification', style: TextStyle(fontSize: 16)),
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

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
      child: Text(
        label,
        style: TextStyle(fontSize: 14, color: HubColors.textMuted),
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
                    onTap: () => run(() => _addWebpage(context, controller)),
                  ),
                  _QuickCreateRow(
                    icon: CupertinoIcons.question_circle,
                    label: 'Short answer',
                    onTap: () =>
                        run(() => _addShortAnswer(context, controller)),
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

Future<void> _addWebpage(BuildContext context, AppController controller) async {
  final value = await showTextPrompt(
    context,
    title: 'Add webpage',
    label: 'Page URL',
    hint: 'https://example.com/pricing',
    keyboardType: TextInputType.url,
  );
  if (value == null || !context.mounted) return;
  try {
    await controller.addWebpage(value);
  } on WorkspaceException catch (error) {
    if (context.mounted) showHubMessage(context, error.message);
  }
}

Future<void> _addShortAnswer(
  BuildContext context,
  AppController controller,
) async {
  final result = await showDialog<List<String>>(
    context: context,
    builder: (context) => const _ShortAnswerDialog(),
  );
  if (result == null || !context.mounted) return;
  try {
    await controller.addShortAnswer(result[0], result[1]);
  } on WorkspaceException catch (error) {
    if (context.mounted) showHubMessage(context, error.message);
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
          title: 'First',
          detail: 'impression',
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
      headline: 'Give ${agent.name} reliable answers and clear boundaries.',
      children: [
        HubCard(
          icon: CupertinoIcons.book,
          title: 'Knowledge',
          detail: 'sources',
          trailing: PopupMenuButton<String>(
            tooltip: 'Add knowledge',
            onSelected: (value) => value == 'url'
                ? _addWebpage(context, controller)
                : _addShortAnswer(context, controller),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'url',
                child: ListTile(
                  leading: Icon(CupertinoIcons.globe),
                  title: Text('Webpage URL'),
                ),
              ),
              PopupMenuItem(
                value: 'qa',
                child: ListTile(
                  leading: Icon(CupertinoIcons.question_circle),
                  title: Text('Short answer'),
                ),
              ),
            ],
            child: const Icon(CupertinoIcons.add_circled, size: 26),
          ),
          child: agent.knowledgeSources.isEmpty
              ? HubEmptyState(
                  icon: CupertinoIcons.book,
                  title: 'No knowledge yet',
                  message: 'Add a webpage or a short answer.',
                  actionLabel: 'Add webpage',
                  onAction: () => _addWebpage(context, controller),
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
    final resolved = calls.where((call) => call.resolved).length;
    final qualified = controller.data.contacts
        .where((contact) => contact.leadStatus == 'Qualified')
        .length;
    return HubPage(
      eyebrow: formatLongDate(now),
      headline:
          '${greetingFor(now)}. Here’s what’s happening with ${controller.data.agent.name}.',
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
                value: calls.isEmpty
                    ? '—'
                    : '${(resolved / calls.length * 100).round()}%',
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
              _OverviewRow(
                icon: CupertinoIcons.person_2,
                label: 'Qualified leads',
                value: '$qualified',
              ),
              const Divider(),
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
              ? const HubEmptyState(
                  icon: CupertinoIcons.phone,
                  title: 'You have no calls',
                  message: 'Calls will appear here after they end.',
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
    return HubPage(
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
            IconBadge(
              icon: call.resolved
                  ? CupertinoIcons.checkmark_alt
                  : CupertinoIcons.xmark,
              iconColor: call.resolved ? HubColors.success : HubColors.danger,
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
            HubPill(
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
    final ready = agent.syncStatus == SyncStatus.ready;
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
                done: agent.bookMeetingEnabled || agent.createContactEnabled,
                text: 'At least one action enabled',
              ),
            ],
          ),
        ),
        HubCard(
          icon: CupertinoIcons.arrow_2_circlepath,
          title: 'Sync',
          detail: 'assistant',
          trailing: _StatusPill(status: agent.syncStatus),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ready
                    ? '${agent.name} is synced and ready for calls.'
                    : 'Sync your latest identity, training, and actions to Vapi.',
              ),
              if (agent.lastSyncedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Last synced ${relativeDate(agent.lastSyncedAt!)}',
                  style: TextStyle(color: HubColors.textMuted),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton(
                  onPressed: controller.isBusy ? null : controller.syncAgent,
                  child: Text(ready ? 'Sync changes' : 'Sync agent'),
                ),
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
              message: ready
                  ? 'Choose a US area code for one inbound number.'
                  : 'Sync the agent first, then choose a US area code.',
              actionLabel: 'Get number',
              onAction: ready && !controller.isBusy
                  ? () => _provision(context)
                  : null,
            ),
          )
        else
          _LiveNumberCard(agent: agent),
        Text(
          'Inbound only · English · No human handoff',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: HubFonts.mono,
            fontSize: 12,
            color: HubColors.textSubtle,
          ),
        ),
      ],
    );
  }

  Future<void> _provision(BuildContext context) async {
    final value = await showTextPrompt(
      context,
      title: 'Choose area code',
      label: 'US area code',
      hint: '415',
      keyboardType: TextInputType.number,
      maxLength: 3,
    );
    if (value == null || !context.mounted) return;
    try {
      await controller.provisionNumber(value.trim());
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
            agent.phoneNumber!,
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
            onPressed: () =>
                launchUrl(Uri(scheme: 'tel', path: agent.phoneNumber)),
            icon: const Icon(CupertinoIcons.phone, size: 18),
            label: const Text('Call agent'),
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
          Text(
            text,
            style: TextStyle(
              color: done ? HubColors.text : HubColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SyncStatus.draft => const HubPill(label: 'Draft'),
      SyncStatus.syncing => const HubPill(
        label: 'Syncing',
        tone: PillTone.accent,
      ),
      SyncStatus.ready => const HubPill(label: 'Ready', tone: PillTone.success),
      SyncStatus.failed => const HubPill(
        label: 'Failed',
        tone: PillTone.danger,
      ),
    };
  }
}

class _ShortAnswerDialog extends StatefulWidget {
  const _ShortAnswerDialog();

  @override
  State<_ShortAnswerDialog> createState() => _ShortAnswerDialogState();
}

class _ShortAnswerDialogState extends State<_ShortAnswerDialog> {
  final question = TextEditingController();
  final answer = TextEditingController();

  @override
  void dispose() {
    question.dispose();
    answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add short answer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: question,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Question'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: answer,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Answer'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          onPressed: () => Navigator.pop(context, [question.text, answer.text]),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
