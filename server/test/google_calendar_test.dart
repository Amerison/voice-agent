import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:voice_agent_server/google_calendar.dart';
import 'package:voice_agent_server/store.dart';
import 'package:voice_agent_server/vapi_client.dart';

import '../bin/server.dart';

void main() {
  const token = 'a-secure-installation-token-for-testing';
  const auth = {'authorization': 'Bearer $token'};

  late FileStore store;
  late List<http.Request> googleRequests;
  late http.Response Function(http.Request request) google;

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('voice-agent');
    addTearDown(() => directory.delete(recursive: true));
    store = FileStore('${directory.path}/store.json');
    await store.initialize();
    googleRequests = [];
    google = (_) => http.Response('{}', 404);
  });

  ApiServer createApi() => ApiServer(
    store: store,
    vapi: VapiClient(
      privateKey: 'test',
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    ),
    publicBaseUrl: 'https://agent.example',
    google: GoogleCalendarClient(
      clientId: 'client-id',
      clientSecret: 'client-secret',
      redirectUri: 'https://agent.example/v1/google/callback',
      httpClient: MockClient((request) async {
        googleRequests.add(request);
        return google(request);
      }),
    ),
  );

  String idToken(String email) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'email': email})))}.sig';

  Future<Map<String, dynamic>> call(
    ApiServer api,
    String method,
    String path, {
    Map<String, String> headers = auth,
    Object? body,
  }) async {
    final response = await api.router.call(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
    final text = await response.readAsString();
    return {
      'status': response.statusCode,
      'body': response.headers['content-type']!.startsWith('application/json')
          ? jsonDecode(text)
          : text,
    };
  }

  Future<String> connect(ApiServer api) async {
    final started = await call(api, 'POST', '/v1/google/connect', body: {});
    final consent = Uri.parse(started['body']['url'] as String);
    expect(consent.host, 'accounts.google.com');
    expect(consent.queryParameters['access_type'], 'offline');
    google = (request) {
      expect(request.url.path, '/token');
      expect(request.bodyFields['code'], 'auth-code');
      return http.Response(
        jsonEncode({
          'access_token': 'access-1',
          'expires_in': 3600,
          'refresh_token': 'refresh-1',
          'scope': GoogleCalendarClient.scopes.join(' '),
          'id_token': idToken('owner@example.com'),
        }),
        200,
      );
    };
    final state = consent.queryParameters['state'];
    final page = await call(
      api,
      'GET',
      '/v1/google/callback?code=auth-code&state=$state',
      headers: const {},
    );
    expect(page['status'], 200);
    expect(page['body'], contains('Google Calendar connected'));
    final integration = await store.ensureIntegration(
      store.keyForToken(token),
      'agent-1',
    );
    return integration['routeId'] as String;
  }

  Future<Map<String, dynamic>> tool(
    ApiServer api,
    String routeId,
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final secret = store.integration(routeId)!['secret'] as String;
    final response = await call(
      api,
      'POST',
      '/v1/vapi/webhook/$routeId',
      headers: {'x-webhook-secret': secret},
      body: {
        'message': {
          'type': 'tool-calls',
          'call': {'id': 'call-1'},
          'toolCallList': [
            {
              'id': 'tool-1',
              'function': {'name': name, 'arguments': arguments},
            },
          ],
        },
      },
    );
    return (response['body']['results'] as List).single as Map<String, dynamic>;
  }

  test('connects a calendar and reports it to the app', () async {
    final api = createApi();
    await connect(api);

    final status = await call(api, 'GET', '/v1/google/status');
    expect(status['body'], {
      'configured': true,
      'connected': true,
      'email': 'owner@example.com',
    });
    final refreshed = await call(
      api,
      'POST',
      '/v1/calls/refresh',
      body: {
        'workspace': {
          'agent': {'id': 'agent-1', 'name': 'Luna'},
        },
      },
    );
    final agent = refreshed['body']['workspace']['agent'] as Map;
    expect(agent['calendarConnected'], isTrue);
    expect(agent['calendarEmail'], 'owner@example.com');
  });

  test('rejects a callback without a known state', () async {
    final api = createApi();
    final page = await call(
      api,
      'GET',
      '/v1/google/callback?code=auth-code&state=forged',
      headers: const {},
    );
    expect(page['status'], 400);
    expect(store.calendar(store.keyForToken(token)), isNull);
  });

  test('offers only free times and books on Google Calendar', () async {
    final api = createApi();
    final routeId = await connect(api);

    Map<String, dynamic>? busyQuery;
    google = (request) {
      expect(request.headers['Authorization'], 'Bearer access-1');
      busyQuery = jsonDecode(request.body) as Map<String, dynamic>;
      final first = DateTime.parse(busyQuery!['timeMin'] as String);
      return http.Response(
        jsonEncode({
          'calendars': {
            'primary': {
              'busy': [
                {
                  'start': first.toIso8601String(),
                  'end': first.add(const Duration(hours: 1)).toIso8601String(),
                },
              ],
            },
          },
        }),
        200,
      );
    };
    final slots = await tool(api, routeId, 'get_meeting_slots', {});
    final offered = (jsonDecode(slots['result'] as String)['slots'] as List)
        .cast<String>();
    expect(offered, hasLength(6));
    expect(offered, isNot(contains(busyQuery!['timeMin'])));

    Map<String, dynamic>? event;
    google = (request) {
      expect(request.url.path, '/calendar/v3/calendars/primary/events');
      event = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': 'event-1',
          'htmlLink': 'https://calendar.google.com/event?eid=1',
        }),
        200,
      );
    };
    final booked = await tool(api, routeId, 'book_meeting', {
      'contactName': 'Dana Reyes',
      'phone': '+14155550100',
      'startsAt': offered.first,
    });

    expect(jsonDecode(booked['result'] as String)['success'], isTrue);
    expect(event!['summary'], 'Meeting with Dana Reyes');
    expect(event!['description'], contains('+14155550100'));
    expect(
      DateTime.parse(
        event!['end']['dateTime'] as String,
      ).difference(DateTime.parse(event!['start']['dateTime'] as String)),
      const Duration(minutes: 30),
    );
    final meeting = store
        .pending(routeId)
        .singleWhere((item) => item['type'] == 'meeting')['record'];
    expect(meeting['googleEventId'], 'event-1');
  });

  test('a revoked grant fails the booking and disconnects', () async {
    final api = createApi();
    final routeId = await connect(api);
    // Forces a token refresh, which Google refuses once access is revoked.
    final restarted = createApi();
    google = (_) => http.Response(jsonEncode({'error': 'invalid_grant'}), 400);

    final booked = await tool(restarted, routeId, 'book_meeting', {
      'contactName': 'Dana Reyes',
      'startsAt': '2026-10-13T17:00:00Z',
    });

    expect(booked['error'], isNotNull);
    expect(store.calendar(store.keyForToken(token)), isNull);
    expect(
      store.pending(routeId).where((item) => item['type'] == 'meeting'),
      isEmpty,
    );
  });
}
