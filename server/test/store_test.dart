import 'dart:io';

import 'package:test/test.dart';
import 'package:voice_agent_server/store.dart';

void main() {
  test('persists workspaces and reuses one integration per agent', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voice-agent-store',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/store.json';
    final store = FileStore(path);
    await store.initialize();
    final key = store.keyForToken('a-secure-installation-token-for-testing');
    await store.saveWorkspace(key, {
      'agent': {'id': 'agent-1', 'name': 'Maya'},
    });

    final first = store.ensureIntegration(key, 'agent-1');
    final second = store.ensureIntegration(key, 'agent-1');
    await store.recordAction(
      first['routeId'] as String,
      'call-1',
      'Created contact',
    );

    final reloaded = FileStore(path);
    await reloaded.initialize();
    expect(reloaded.workspace(key)?['agent']['name'], 'Maya');
    expect(first['routeId'], second['routeId']);
    expect(reloaded.actionsForCall(first['routeId'] as String, 'call-1'), [
      'Created contact',
    ]);
  });
}
