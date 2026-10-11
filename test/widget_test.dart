import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_agent/app.dart';
import 'package:voice_agent/app_controller.dart';
import 'package:voice_agent/repository.dart';

void main() {
  testWidgets('starts with lead qualification onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(LocalWorkspaceRepository(preferences));
    await controller.initialize();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('What should your\nagent do?'), findsOneWidget);
    expect(find.text('Lead qualification'), findsOneWidget);
    expect(find.text('Customer support'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Build my agent'), 300);
    expect(find.text('Build my agent'), findsOneWidget);
  });

  testWidgets('opens a contact with activity and about tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(LocalWorkspaceRepository(preferences));
    await controller.initialize();
    await controller.completeOnboarding();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Test Maya'), findsOneWidget);
    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avery Chen'));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Contact created'), findsOneWidget);
  });

  testWidgets('uses the requested home navigation and drawer routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(LocalWorkspaceRepository(preferences));
    await controller.initialize();
    await controller.completeOnboarding();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Identity'), findsNothing);
    expect(find.textContaining('Here’s what’s happening'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Deploy'), findsOneWidget);
    expect(find.text('Calls'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Identity'));
    await tester.pumpAndSettle();
    expect(
      find.text('Shape who answers the phone and how they sound.'),
      findsOneWidget,
    );
  });

  testWidgets('opens the near-full-screen voice test experience', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppController(LocalWorkspaceRepository(preferences));
    await controller.initialize();
    await controller.completeOnboarding();

    await tester.pumpWidget(VoiceAgentApp(controller: controller));
    await tester.pump();
    await tester.tap(find.text('Test Maya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('LIVE VOICE TEST'), findsOneWidget);
    expect(find.text('Couldn’t start the test'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
