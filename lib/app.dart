import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'screens.dart';
import 'theme.dart';

class VoiceAgentApp extends StatelessWidget {
  const VoiceAgentApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        HubColors.useDarkMode(controller.isDarkMode);
        return MaterialApp(
          title: 'Voice Agent',
          debugShowCheckedModeBanner: false,
          theme: buildHubTheme(Brightness.light),
          darkTheme: buildHubTheme(Brightness.dark),
          themeMode: controller.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: Builder(
            builder: (context) {
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
      },
    );
  }
}
