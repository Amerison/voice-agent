import 'dart:io';

import 'package:test/test.dart';
import 'package:voice_agent_server/store.dart';

void main() {
  test('persists numbers and reuses one integration per agent', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voice-agent-store',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/store.json';
    final store = FileStore(path);
    await store.initialize();
    final key = store.keyForToken('a-secure-installation-token-for-testing');
    await store.saveNumber(key, {'number': '+14155550123', 'twilioSid': 'PN1'});

    final first = await store.ensureIntegration(key, 'agent-1');
    final second = await store.ensureIntegration(key, 'agent-1');
    await store.recordAction(
      first['routeId'] as String,
      'call-1',
      'Created contact',
    );

    final reloaded = FileStore(path);
    await reloaded.initialize();
    expect(reloaded.number(key)?['number'], '+14155550123');
    expect(first['routeId'], second['routeId']);
    expect(reloaded.actionsForCall(first['routeId'] as String, 'call-1'), [
      'Created contact',
    ]);
  });

  test('keeps pending records until the app acknowledges them', () async {
    final directory = await Directory.systemTemp.createTemp(
      'voice-agent-store',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileStore('${directory.path}/store.json');
    await store.initialize();
    final routeId =
        (await store.ensureIntegration('workspace', 'agent-1'))['routeId']
            as String;

    await store.addPending(routeId, 'contact', {'id': 'c1'});
    await store.addPending(routeId, 'meeting', {'id': 'm1'});
    await store.acknowledge(routeId, 1);

    expect(store.pending(routeId), [
      {
        'seq': 2,
        'type': 'meeting',
        'record': {'id': 'm1'},
      },
    ]);
  });
}
