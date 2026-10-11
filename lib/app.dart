import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens.dart';
import 'theme.dart';

class VoiceAgentApp extends StatelessWidget {
  const VoiceAgentApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Agent',
      debugShowCheckedModeBanner: false,
      theme: buildHubTheme(),
      themeMode: ThemeMode.dark,
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isReady) {
            return LaunchScreen(
              error: controller.error,
              onRetry: controller.initialize,
            );
          }
          if (!controller.data.onboardingComplete) {
            return OnboardingScreen(controller: controller);
          }
          return WorkspaceScreen(controller: controller);
        },
      ),
    );
  }
}
