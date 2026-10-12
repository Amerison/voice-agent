import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_agent/app.dart';
import 'package:voice_agent/app_controller.dart';
import 'package:voice_agent/models.dart';
import 'package:voice_agent/repository.dart';

Future<AppController> readyController({
  bool onboard = true,
  Contact? contact,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(LocalWorkspaceRepository(preferences));
  await controller.initialize();
  if (onboard) {
    await controller.completeOnboarding(
      agent: controller.data.agent.copyWith(
        name: 'Maya',
        companyName: 'Northstar',
        greeting: 'Hi, you’ve reached Maya at Northstar. How can I help today?',
      ),
    );
  }
  if (contact != null) {
    await controller.saveContact(contact);
  }
  return controller;
}

Contact sampleContact() => Contact(
  id: 'contact-1',
  name: 'Avery Chen',
  phone: '+1 415 555 1000',
  email: 'avery.chen@example.com',
  company: 'Northstar Labs',
  jobTitle: 'Head of Operations',
  leadSource: 'Manual',
  leadStatus: 'New',
  budgetRange: r'$10k–$25k',
  notes: '',
  createdAt: DateTime(2026, 10, 8, 20, 55),
);

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // Onboarding's ambient glow never settles, so step time forward instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('starts with use-case selection and reveals a number', (
    tester,
  ) async {
    usePhoneSize(tester);
    final controller = await readyController(onboard: false);

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await settle(tester);

    expect(find.text('AI receptionist'), findsOneWidget);
    expect(find.text('AI lead qualification'), findsOneWidget);
    expect(find.text('Your agent’s new number'), findsNothing);

    await tester.tap(find.text('AI receptionist'));
    await settle(tester);
    expect(find.text('Your agent’s new number'), findsOneWidget);
  });

  testWidgets('walks through onboarding onto an empty workspace', (
    tester,
  ) async {
    usePhoneSize(tester);
    final controller = await readyController(onboard: false);

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await settle(tester);

    Future<void> tapText(String text) async {
      await tester.tap(find.text(text).last);
      await settle(tester);
    }

    await tapText('AI receptionist');
    await tapText('Continue');
    expect(find.text('Give me a name and a personality'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    await tapText('Professional');
    await tapText('Continue');

    expect(find.text('How should I sound?'), findsOneWidget);
    await tapText('Clara');
    await tapText('Continue');

    expect(find.text('What type of business do you have?'), findsOneWidget);
    await tapText('On-site & home services');

    expect(find.text('Link your website'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'acme-plumbing.com');
    await tester.pump();
    await tester.tap(find.text('Link website'));
    await tester.pump();
    expect(find.text('Website linked'), findsOneWidget);
    await settle(tester);

    expect(find.text('Connect Google Calendar'), findsOneWidget);
    await tapText('Connect Google Calendar');
    await settle(tester);

    expect(find.text('What’s your company called?'), findsOneWidget);
    expect(find.text('Acme Plumbing'), findsOneWidget);
    await tapText('Continue');

    expect(find.text('How should I greet callers?'), findsOneWidget);
    const greeting =
        'Hi, thanks for calling Acme Plumbing! This is Luna, the AI receptionist. I can answer questions, take a message, or book a visit. How can I help today?';
    expect(find.text(greeting), findsOneWidget);
    await tapText('Continue');

    expect(find.text('Want to hear me in action?'), findsOneWidget);
    await tapText('Skip');

    expect(find.text('Which number should I answer calls on?'), findsOneWidget);
    expect(find.text('What is call forwarding?'), findsOneWidget);
    await tapText('Finish setup');
    await tester.pumpAndSettle();

    final agent = controller.data.agent;
    expect(find.text('Test Luna'), findsOneWidget);
    expect(controller.data.onboardingComplete, isTrue);
    expect(agent.type, AgentType.receptionist);
    expect(agent.name, 'Luna');
    expect(agent.friendliness, Friendliness.professional);
    expect(agent.voice, 'Clara');
    expect(agent.companyName, 'Acme Plumbing');
    expect(agent.greeting, greeting);
    expect(agent.calendarConnected, isTrue);
    expect(agent.reservedNumber, matches(RegExp(r'^\+162855501\d\d$')));
    expect(agent.phoneNumber, agent.reservedNumber);
    expect(agent.knowledgeSources.single.content, 'https://acme-plumbing.com');
    expect(controller.data.contacts, isEmpty);
    expect(controller.data.calls, isEmpty);

    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();
    expect(find.text('You have no contacts'), findsOneWidget);
    expect(find.text('Avery Chen'), findsNothing);
  });

  testWidgets('opens a contact with activity and about tabs', (tester) async {
    final controller = await readyController(contact: sampleContact());

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Test Maya'), findsOneWidget);
    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();

    expect(find.text('Contacts'), findsOneWidget);
    expect(find.byTooltip('Add contact'), findsNothing);
    expect(find.text('Search Contacts'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Search Contacts')).dy,
      lessThan(tester.getTopLeft(find.text('Avery Chen')).dy),
    );

    await tester.tap(find.text('Avery Chen'));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Contact created'), findsOneWidget);
  });

  testWidgets('opens create contact as a full-screen HubSpot editor', (
    tester,
  ) async {
    final controller = await readyController();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();

    expect(find.text('New contact'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('uses the requested home navigation and drawer routes', (
    tester,
  ) async {
    final controller = await readyController();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsNWidgets(2));
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Identity'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Home')),
      findsOneWidget,
    );
    expect(find.textContaining('Here’s what’s happening'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Train'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Train')),
      findsOneWidget,
    );
    expect(
      find.text('Give Maya reliable answers and clear boundaries.'),
      findsNothing,
    );
    expect(find.text('Train'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Deploy'), findsOneWidget);
    expect(find.text('Calls'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Agent'), findsNothing);
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('CRM')),
      findsOneWidget,
    );

    await tester.tap(find.text('Identity'));
    await tester.pumpAndSettle();
    expect(
      find.text('Shape who answers the phone and how they sound.'),
      findsOneWidget,
    );
  });

  testWidgets('opens the full-screen voice test experience', (tester) async {
    final controller = await readyController();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pump();
    await tester.tap(find.text('Test Maya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Couldn’t start the test'), findsOneWidget);
    expect(find.byTooltip('Audio settings'), findsNothing);
    expect(find.byTooltip('Close voice test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Test Maya on the right and hides the demo notice', (
    tester,
  ) async {
    final controller = await readyController();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(
      scaffold.floatingActionButtonLocation,
      FloatingActionButtonLocation.endFloat,
    );
    expect(find.textContaining('Demo mode'), findsNothing);
  });

  testWidgets('changes and persists the appearance from Settings', (
    tester,
  ) async {
    final controller = await readyController();
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(controller.isDarkMode, isTrue);
    expect(
      Theme.of(tester.element(find.text('Dark mode'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.isDarkMode, isFalse);
    expect(preferences.getBool('voice_agent_dark_mode'), isFalse);
    expect(
      Theme.of(tester.element(find.text('Dark mode'))).brightness,
      Brightness.light,
    );
  });

  testWidgets('adds and cancels webpage knowledge without errors', (
    tester,
  ) async {
    final controller = await readyController();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Train'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add knowledge'));
    await tester.pumpAndSettle();
    expect(find.text('Add knowledge'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Webpage URL'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'https://example.com');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add knowledge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      controller.data.agent.knowledgeSources.map((source) => source.content),
      contains('https://example.com'),
    );
  });

  test('syncs agent changes automatically', () async {
    final controller = await readyController();
    await controller.syncAgent();
    expect(controller.data.agent.syncStatus, SyncStatus.ready);

    await controller.updateAgent(
      controller.data.agent.copyWith(guidelines: 'Always confirm the address.'),
    );
    await controller.syncAgent();

    expect(controller.data.agent.syncStatus, SyncStatus.ready);
    expect(controller.data.agent.guidelines, 'Always confirm the address.');
  });

  test('keeps edits made while a sync is running', () async {
    final controller = await readyController();
    final firstSync = controller.syncAgent();
    await controller.updateAgent(
      controller.data.agent.copyWith(guidelines: 'Never quote prices.'),
    );
    await firstSync;
    await controller.syncAgent();

    expect(controller.data.agent.guidelines, 'Never quote prices.');
    expect(controller.data.agent.syncStatus, SyncStatus.ready);
  });
}
