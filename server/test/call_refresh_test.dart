import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:voice_agent_server/store.dart';
import 'package:voice_agent_server/vapi_client.dart';

import '../bin/server.dart';

void main() {
  const token = 'a-secure-installation-token-for-testing';

  Future<FileStore> createStore() async {
    final directory = await Directory.systemTemp.createTemp('voice-agent');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileStore('${directory.path}/store.json');
    await store.initialize();
    return store;
  }

  Future<Map<String, dynamic>> refresh(
    ApiServer api,
    Map<String, dynamic> workspace, [
    int cursor = 0,
  ]) async {
    final response = await api.router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/calls/refresh'),
        headers: {'authorization': 'Bearer $token'},
        body: jsonEncode({'workspace': workspace, 'inboxCursor': cursor}),
      ),
    );
    expect(response.statusCode, 200);
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  test('imports ended Vapi calls into the workspace once', () async {
    final store = await createStore();
    final vapi = VapiClient(
      privateKey: 'test',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/call');
        expect(request.url.queryParameters['assistantId'], 'asst-1');
        return http.Response(
          jsonEncode([
            {
              'id': 'call-1',
              'type': 'inboundPhoneCall',
              'status': 'ended',
              'startedAt': '2026-10-11T10:00:00Z',
              'endedAt': '2026-10-11T10:01:30Z',
              'endedReason': 'customer-ended-call',
              'customer': {'number': '+14155550100'},
              'messages': [
                {'role': 'system', 'message': 'prompt'},
                {'role': 'bot', 'message': 'Hi, this is Luna.'},
                {'role': 'user', 'message': 'Do you fix drains?'},
              ],
            },
            {'id': 'call-2', 'status': 'in-progress'},
          ]),
          200,
        );
      }),
    );
    final api = ApiServer(store: store, vapi: vapi, publicBaseUrl: '');
    final workspace = {
      'agent': {'id': 'agent-1', 'name': 'Luna', 'vapiAssistantId': 'asst-1'},
      'calls': <dynamic>[],
    };

    final first = (await refresh(api, workspace))['workspace'];
    final calls = (await refresh(api, first))['workspace']['calls'] as List;

    expect(calls, hasLength(1));
    final call = calls.single as Map<String, dynamic>;
    expect(call['id'], 'call-1');
    expect(call['callerNumber'], '+14155550100');
    expect(call['durationSeconds'], 90);
    expect(call['transcript'], [
      {'role': 'assistant', 'text': 'Hi, this is Luna.'},
      {'role': 'caller', 'text': 'Do you fix drains?'},
    ]);
  });

  test('merges contacts from calls into the app’s CRM', () async {
    final store = await createStore();
    final vapi = VapiClient(
      privateKey: 'test',
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    final api = ApiServer(store: store, vapi: vapi, publicBaseUrl: '');
    final routeId =
        (await store.ensureIntegration(
              store.keyForToken(token),
              'agent-1',
            ))['routeId']
            as String;
    await store.addPending(routeId, 'contact', {
      'id': 'contact-new',
      'name': 'Dana Reyes',
      'phone': '+14155550100',
      'notes': 'Wants a quote.',
      'leadSource': 'Inbound call',
      'createdAt': '2026-10-11T10:00:00Z',
    });
    await store.addPending(routeId, 'meeting', {
      'id': 'meeting-1',
      'contactId': 'contact-new',
      'contactName': 'Dana Reyes',
      'startsAt': '2026-10-12T17:00:00Z',
      'status': 'Scheduled',
    });
    final workspace = {
      'agent': {'id': 'agent-1', 'name': 'Luna', 'vapiAssistantId': 'asst-1'},
      'contacts': [
        {
          'id': 'contact-1',
          'name': 'Dana',
          'phone': '+14155550100',
          'leadSource': 'Referral',
          'leadStatus': 'Qualified',
          'createdAt': '2026-10-01T10:00:00Z',
        },
      ],
    };

    final result = await refresh(api, workspace);
    final contacts = result['workspace']['contacts'] as List;
    final meetings = result['workspace']['meetings'] as List;

    expect(contacts, [
      {
        'id': 'contact-1',
        'name': 'Dana Reyes',
        'phone': '+14155550100',
        'leadSource': 'Referral',
        'leadStatus': 'Qualified',
        'createdAt': '2026-10-01T10:00:00Z',
        'notes': 'Wants a quote.',
      },
    ]);
    expect((meetings.single as Map)['contactId'], 'contact-1');
    expect(result['inboxCursor'], 2);

    await refresh(api, result['workspace'] as Map<String, dynamic>, 2);
    expect(store.pending(routeId), isEmpty);
  });
}
