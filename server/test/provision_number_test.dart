import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:voice_agent_server/store.dart';
import 'package:voice_agent_server/twilio_client.dart';
import 'package:voice_agent_server/vapi_client.dart';

import '../bin/server.dart';

void main() {
  test('buys one Twilio number per workspace and retries the Vapi import '
      'without buying again', () async {
    final directory = await Directory.systemTemp.createTemp('voice-agent');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileStore('${directory.path}/store.json');
    await store.initialize();

    final purchases = <Map<String, String>>[];
    final twilio = TwilioClient(
      accountSid: 'AC123',
      authToken: 'secret',
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/2010-04-01/Accounts/AC123/IncomingPhoneNumbers.json',
        );
        purchases.add(Uri.splitQueryString(request.body));
        return http.Response(
          jsonEncode({'sid': 'PN1', 'phone_number': '+14155550123'}),
          201,
        );
      }),
    );
    final imports = <Map<String, dynamic>>[];
    var failImport = true;
    final vapi = VapiClient(
      privateKey: 'test',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/phone-number');
        if (request.method == 'GET') return http.Response('[]', 200);
        imports.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (failImport) {
          failImport = false;
          return http.Response(jsonEncode({'message': 'Try again.'}), 503);
        }
        return http.Response(jsonEncode({'id': 'vapi-number-1'}), 201);
      }),
    );
    final api = ApiServer(
      store: store,
      vapi: vapi,
      twilio: twilio,
      publicBaseUrl: '',
    );

    Future<Response> provision() => api.router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/agent/provision-number'),
        headers: {
          'authorization': 'Bearer a-secure-installation-token-for-testing',
        },
        body: jsonEncode({
          'areaCode': '415',
          'number': '+14155550123',
          'workspace': {
            'agent': {
              'id': 'agent-1',
              'name': 'Luna',
              'companyName': 'Acme Plumbing',
              'vapiAssistantId': 'asst-1',
            },
          },
        }),
      ),
    );

    expect((await provision()).statusCode, 502);
    final response = await provision();
    expect(response.statusCode, 200);
    final agent = jsonDecode(
      await response.readAsString(),
    )['workspace']['agent'];

    expect(agent['phoneNumber'], '+14155550123');
    expect(agent['vapiPhoneNumberId'], 'vapi-number-1');
    expect(purchases, [
      {'PhoneNumber': '+14155550123', 'FriendlyName': 'Luna – Acme Plumbing'},
    ]);
    expect(imports, hasLength(2));
    expect(imports.last, {
      'provider': 'twilio',
      'number': '+14155550123',
      'twilioAccountSid': 'AC123',
      'twilioAuthToken': 'secret',
      'assistantId': 'asst-1',
      'name': 'Luna – Acme Plumbing',
      'smsEnabled': false,
    });
  });
}
