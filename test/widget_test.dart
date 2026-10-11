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

    expect(find.text('Deploy Maya'), findsOneWidget);
    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avery Chen'));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Contact created'), findsOneWidget);
  });
}
