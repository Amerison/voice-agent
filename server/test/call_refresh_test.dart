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
  test('imports ended Vapi calls into the workspace once', () async {
    final directory = await Directory.systemTemp.createTemp('voice-agent');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileStore('${directory.path}/store.json');
    await store.initialize();
    const token = 'a-secure-installation-token-for-testing';
    final key = store.keyForToken(token);
    await store.saveWorkspace(key, {
      'agent': {'id': 'agent-1', 'name': 'Luna', 'vapiAssistantId': 'asst-1'},
      'calls': <dynamic>[],
    });

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

    Future<Map<String, dynamic>> refresh() async {
      final response = await api.router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/calls/refresh'),
          headers: {'authorization': 'Bearer $token'},
        ),
      );
      expect(response.statusCode, 200);
      return jsonDecode(await response.readAsString())['workspace']
          as Map<String, dynamic>;
    }

    await refresh();
    final calls = (await refresh())['calls'] as List;

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
}
