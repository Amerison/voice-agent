import 'package:flutter/material.dart';

import 'app.dart';
import 'app_controller.dart';
import 'repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await createRepository();
  final controller = AppController(repository);
  runApp(VoiceAgentApp(controller: controller));
  await controller.initialize();
}
