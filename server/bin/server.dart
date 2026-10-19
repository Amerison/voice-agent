import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:voice_agent_server/prompt_builder.dart';
import 'package:voice_agent_server/store.dart';
import 'package:voice_agent_server/vapi_client.dart';

Future<void> main() async {
  final privateKey = Platform.environment['VAPI_PRIVATE_KEY']?.trim() ?? '';
  if (privateKey.isEmpty) {
    stderr.writeln('VAPI_PRIVATE_KEY is required.');
    exitCode = 64;
    return;
  }
  final publicBaseUrl =
      Platform.environment['PUBLIC_BASE_URL']?.replaceFirst(
        RegExp(r'/$'),
        '',
      ) ??
      '';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dataPath = Platform.environment['DATA_FILE'] ?? '.data/store.json';

  final openAiKey = Platform.environment['OPENAI_API_KEY']?.trim() ?? '';

  final store = FileStore(dataPath);
  await store.initialize();
  final api = ApiServer(
    store: store,
    vapi: VapiClient(privateKey: privateKey),
    publicBaseUrl: publicBaseUrl,
    openAiKey: openAiKey,
  );
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addHandler(api.router.call);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Voice Agent API listening on port ${server.port}');
}

class ApiServer {
  ApiServer({
    required this.store,
    required this.vapi,
    required this.publicBaseUrl,
    required this.openAiKey,
  }) {
    router
      ..get('/health', _health)
      ..get('/v1/workspace', _getWorkspace)
      ..put('/v1/workspace', _putWorkspace)
      ..post('/v1/agent/sync', _syncAgent)
      ..post('/v1/agent/provision-number', _provisionNumber)
      ..get('/v1/vapi/number', _accountNumber)
      ..post('/v1/calls/refresh', _refreshCalls)
      ..post('/v1/chat', _chat)
      ..post('/v1/vapi/webhook/<routeId>', _vapiWebhook)
      ..options('/<ignored|.*>', (_) => Response.ok(''));
  }

  final FileStore store;
  final VapiClient vapi;
  final String publicBaseUrl;
  final String openAiKey;
  final Router router = Router();

  Response _health(Request request) => _json(200, {
    'ok': true,
    'vapiConfigured': true,
    'publicUrlConfigured': publicBaseUrl.isNotEmpty,
  });

  Future<Response> _getWorkspace(Request request) async {
    try {
      final key = _workspaceKey(request);
      final workspace = store.workspace(key);
      if (workspace == null) {
        return _json(404, {'error': 'Workspace not found.'});
      }
      return _json(200, {'workspace': workspace});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    }
  }

  Future<Response> _putWorkspace(Request request) async {
    try {
      final key = _workspaceKey(request);
      final workspace = await _readObject(request);
      _validateWorkspace(workspace);
      await store.saveWorkspace(key, workspace);
      return _json(200, {'workspace': workspace});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    }
  }

  Future<Response> _syncAgent(Request request) async {
    try {
      final key = _workspaceKey(request);
      final body = await _readObject(request);
      final workspace = _object(body['workspace']);
      _validateWorkspace(workspace);
      final agent = _object(workspace['agent']);
      final integration = store.ensureIntegration(key, agent['id'] as String);
      final routeId = integration['routeId'] as String;
      final secret = integration['secret'] as String;
      // Without a public URL, Vapi can't reach our webhooks: the assistant
      // still syncs, tools are skipped, and calls arrive via /v1/calls/refresh.
      final webhookUrl = publicBaseUrl.isEmpty
          ? null
          : '$publicBaseUrl/v1/vapi/webhook/$routeId';
      final webpages = await _fetchWebpages(agent);

      var assistantId = agent['vapiAssistantId'] as String?;
      var outputId = agent['vapiStructuredOutputId'] as String?;
      var payload = _assistantPayload(
        agent,
        webhookUrl: webhookUrl,
        webhookSecret: secret,
        webpageContents: webpages,
        structuredOutputId: outputId,
      );
      if (assistantId == null || assistantId.isEmpty) {
        final created = await vapi.createAssistant(payload);
        assistantId = created['id'] as String;
      }
      if (outputId == null || outputId.isEmpty) {
        final created = await vapi.createStructuredOutput(assistantId);
        outputId = created['id'] as String;
      }
      payload = _assistantPayload(
        agent,
        webhookUrl: webhookUrl,
        webhookSecret: secret,
        webpageContents: webpages,
        structuredOutputId: outputId,
      );
      await vapi.updateAssistant(assistantId, payload);

      agent
        ..['vapiAssistantId'] = assistantId
        ..['vapiStructuredOutputId'] = outputId
        ..['syncStatus'] = 'ready'
        ..['syncError'] = null
        ..['lastSyncedAt'] = DateTime.now().toUtc().toIso8601String();
      workspace['agent'] = agent;
      await store.saveWorkspace(key, workspace);
      return _json(200, {'workspace': workspace});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on VapiException catch (error) {
      return _json(502, {'error': 'Vapi: ${error.message}'});
    } on Object catch (error, stack) {
      stderr.writeln('Sync failed: $error\n$stack');
      return _json(500, {'error': 'The agent could not be synced.'});
    }
  }

  Future<Response> _provisionNumber(Request request) async {
    try {
      final key = _workspaceKey(request);
      final body = await _readObject(request);
      final workspace = _object(body['workspace']);
      _validateWorkspace(workspace);
      final areaCode = body['areaCode'] as String? ?? '';
      if (!RegExp(r'^\d{3}$').hasMatch(areaCode)) {
        throw const ApiException(400, 'Enter a three-digit US area code.');
      }
      final agent = _object(workspace['agent']);
      final assistantId = agent['vapiAssistantId'] as String?;
      if (assistantId == null || assistantId.isEmpty) {
        throw const ApiException(
          409,
          'Sync the agent before provisioning a number.',
        );
      }
      if (agent['phoneNumber'] != null) {
        return _json(200, {'workspace': workspace});
      }
      // The account's Vapi number is the single source of truth: reuse it and
      // point it at this assistant; only buy one if the account has none.
      final existing = await vapi.listNumbers();
      final phone = existing.isNotEmpty
          ? await vapi.assignNumber(existing.first['id'] as String, assistantId)
          : await vapi.provisionNumber(
              assistantId: assistantId,
              areaCode: areaCode,
            );
      agent
        ..['phoneNumber'] = phone['number'] as String?
        ..['vapiPhoneNumberId'] = phone['id'] as String?;
      workspace['agent'] = agent;
      await store.saveWorkspace(key, workspace);
      return _json(200, {'workspace': workspace});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on VapiException catch (error) {
      return _json(502, {'error': 'Vapi: ${error.message}'});
    } on Object catch (error, stack) {
      stderr.writeln('Provisioning failed: $error\n$stack');
      return _json(500, {
        'error': 'The phone number could not be provisioned.',
      });
    }
  }

  Future<Response> _vapiWebhook(Request request, String routeId) async {
    final integration = store.integration(routeId);
    if (integration == null) return _json(404, {'error': 'Unknown webhook.'});
    final provided = request.headers['x-webhook-secret'];
    if (provided == null || provided != integration['secret']) {
      return _json(401, {'error': 'Invalid webhook credential.'});
    }
    try {
      final payload = await _readObject(request);
      final message = _object(payload['message']);
      final type = message['type'] as String? ?? '';
      if (type == 'tool-calls' || type == 'function-call') {
        return await _handleTools(routeId, integration, message);
      }
      if (type == 'end-of-call-report') {
        await _handleEndOfCall(routeId, integration, message);
      }
      return _json(200, {'received': true});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on Object catch (error, stack) {
      stderr.writeln('Webhook failed: $error\n$stack');
      return _json(200, {'received': true});
    }
  }

  Future<Response> _handleTools(
    String routeId,
    Map<String, dynamic> integration,
    Map<String, dynamic> message,
  ) async {
    final workspaceKey = integration['workspaceKey'] as String;
    final workspace = store.workspace(workspaceKey);
    if (workspace == null) return _toolError(message, 'Workspace not found.');
    final call = _objectOrEmpty(message['call']);
    final callId = call['id'] as String? ?? 'unknown-call';
    final calls = (message['toolCallList'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final results = <Map<String, dynamic>>[];
    for (final toolCall in calls) {
      final id = toolCall['id'] as String? ?? '';
      try {
        final function = _object(toolCall['function']);
        final name = function['name'] as String? ?? '';
        final arguments = _arguments(function['arguments']);
        final result = await _executeTool(
          routeId,
          callId,
          workspace,
          name,
          arguments,
        );
        results.add({'toolCallId': id, 'result': jsonEncode(result)});
      } on Object catch (error) {
        results.add({'toolCallId': id, 'error': error.toString()});
      }
    }
    await store.saveWorkspace(workspaceKey, workspace);
    return _json(200, {'results': results});
  }

  Future<Map<String, dynamic>> _executeTool(
    String routeId,
    String callId,
    Map<String, dynamic> workspace,
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final contacts = (workspace['contacts'] as List? ?? <dynamic>[]);
    final meetings = (workspace['meetings'] as List? ?? <dynamic>[]);
    switch (name) {
      case 'create_contact':
        final contactName = _requiredString(arguments, 'name');
        final email = arguments['email'] as String? ?? '';
        final phone = arguments['phone'] as String? ?? '';
        if (email.isEmpty && phone.isEmpty) {
          throw const ApiException(400, 'Email or phone is required.');
        }
        final existingIndex = contacts.indexWhere((item) {
          final contact = item as Map<String, dynamic>;
          return (email.isNotEmpty && contact['email'] == email) ||
              (phone.isNotEmpty && contact['phone'] == phone);
        });
        final contact = <String, dynamic>{
          'id': existingIndex == -1
              ? 'contact-${DateTime.now().microsecondsSinceEpoch}'
              : (contacts[existingIndex] as Map<String, dynamic>)['id'],
          'name': contactName,
          'phone': phone,
          'email': email,
          'company': arguments['company'] as String? ?? '',
          'jobTitle': arguments['jobTitle'] as String? ?? '',
          'leadSource': 'Inbound call',
          'leadStatus': arguments['leadStatus'] as String? ?? 'New',
          'budgetRange': arguments['budgetRange'] as String? ?? 'Not shared',
          'notes': arguments['notes'] as String? ?? '',
          'createdAt': existingIndex == -1
              ? DateTime.now().toUtc().toIso8601String()
              : (contacts[existingIndex] as Map<String, dynamic>)['createdAt'],
        };
        if (existingIndex == -1) {
          contacts.insert(0, contact);
        } else {
          contacts[existingIndex] = contact;
        }
        workspace['contacts'] = contacts;
        await store.recordAction(routeId, callId, 'Created contact');
        return {
          'success': true,
          'contactId': contact['id'],
          'message': 'Contact saved.',
        };
      case 'get_meeting_slots':
        return {'timezone': 'America/Los_Angeles', 'slots': _meetingSlots()};
      case 'book_meeting':
        final contactName = _requiredString(arguments, 'contactName');
        final startsAt = DateTime.tryParse(
          _requiredString(arguments, 'startsAt'),
        );
        if (startsAt == null) {
          throw const ApiException(400, 'Invalid meeting time.');
        }
        var contactId = arguments['contactId'] as String?;
        if (contactId == null || contactId.isEmpty) {
          final match = contacts.cast<Map<String, dynamic>>().where(
            (item) =>
                item['name'].toString().toLowerCase() ==
                contactName.toLowerCase(),
          );
          contactId = match.isEmpty
              ? 'contact-${DateTime.now().microsecondsSinceEpoch}'
              : match.first['id'] as String;
          if (match.isEmpty) {
            contacts.insert(0, {
              'id': contactId,
              'name': contactName,
              'phone': arguments['phone'] as String? ?? '',
              'email': arguments['email'] as String? ?? '',
              'company': '',
              'jobTitle': '',
              'leadSource': 'Inbound call',
              'leadStatus': 'Qualified',
              'budgetRange': 'Not shared',
              'notes': 'Created while booking a meeting.',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            });
          }
        }
        final duplicate = meetings.cast<Map<String, dynamic>>().any(
          (item) =>
              item['contactId'] == contactId &&
              item['startsAt'] == startsAt.toUtc().toIso8601String(),
        );
        if (!duplicate) {
          meetings.insert(0, {
            'id': 'meeting-${DateTime.now().microsecondsSinceEpoch}',
            'contactId': contactId,
            'contactName': contactName,
            'startsAt': startsAt.toUtc().toIso8601String(),
            'status': 'Scheduled',
          });
        }
        workspace
          ..['contacts'] = contacts
          ..['meetings'] = meetings;
        await store.recordAction(routeId, callId, 'Booked meeting');
        return {
          'success': true,
          'startsAt': startsAt.toIso8601String(),
          'message': 'Meeting booked.',
        };
      default:
        throw ApiException(400, 'Unknown tool: $name');
    }
  }

  Future<Response> _accountNumber(Request request) async {
    try {
      _workspaceKey(request);
      final numbers = await vapi.listNumbers();
      if (numbers.isEmpty) return _json(200, {'number': null});
      final number = numbers.first;
      return _json(200, {'number': number['number'], 'id': number['id']});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on VapiException catch (error) {
      return _json(502, {'error': 'Vapi: ${error.message}'});
    }
  }

  Future<Response> _chat(Request request) async {
    try {
      _workspaceKey(request);
      final body = await _readObject(request);
      final workspace = _object(body['workspace']);
      _validateWorkspace(workspace);
      final messages = (body['messages'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      final agent = _object(workspace['agent']);
      if (openAiKey.isEmpty) {
        return _json(503, {'error': 'OpenAI is not configured on this server.'});
      }
      final systemPrompt = buildLeadQualificationPrompt(agent);
      final chatMessages = [
        {'role': 'system', 'content': systemPrompt},
        for (final msg in messages)
          {
            'role': msg['role'] as String? ?? 'user',
            'content': msg['content'] as String? ?? '',
          },
      ];
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $openAiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': chatMessages,
          'max_tokens': 500,
        }),
      );
      if (response.statusCode != 200) {
        return _json(502, {'error': 'The AI service returned an error.'});
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = payload['choices'] as List?;
      final reply = choices != null && choices.isNotEmpty
          ? (choices.first as Map)['message']?['content'] as String? ?? ''
          : '';
      return _json(200, {'reply': reply});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on Object catch (error, stack) {
      stderr.writeln('Chat failed: $error\n$stack');
      return _json(500, {'error': 'Chat could not be completed.'});
    }
  }

  /// Pulls ended calls for this agent's assistant from Vapi so they show up
  /// even when webhooks can't reach this server.
  Future<Response> _refreshCalls(Request request) async {
    try {
      final key = _workspaceKey(request);
      final workspace = store.workspace(key);
      if (workspace == null) {
        return _json(404, {'error': 'Workspace not found.'});
      }
      final agent = _object(workspace['agent']);
      final assistantId = agent['vapiAssistantId'] as String?;
      if (assistantId == null || assistantId.isEmpty) {
        return _json(200, {'workspace': workspace});
      }
      final integration = store.ensureIntegration(key, agent['id'] as String);
      final routeId = integration['routeId'] as String;
      final records = (workspace['calls'] as List? ?? <dynamic>[]);
      final known = records
          .cast<Map<String, dynamic>>()
          .map((item) => item['id'])
          .toSet();
      final calls = await vapi.listCalls(assistantId);
      final fresh = calls
          .where((call) => call['status'] == 'ended')
          .where((call) => !known.contains(call['id']))
          .map(
            (call) => _callRecord(
              call,
              store.actionsForCall(routeId, call['id'] as String),
            ),
          )
          .toList();
      if (fresh.isNotEmpty) {
        records
          ..addAll(fresh)
          ..sort(
            (a, b) =>
                (b['startedAt'] as String).compareTo(a['startedAt'] as String),
          );
        workspace['calls'] = records;
        await store.saveWorkspace(key, workspace);
      }
      return _json(200, {'workspace': workspace});
    } on ApiException catch (error) {
      return _json(error.statusCode, {'error': error.message});
    } on VapiException catch (error) {
      return _json(502, {'error': 'Vapi: ${error.message}'});
    }
  }

  Map<String, dynamic> _callRecord(
    Map<String, dynamic> call,
    List<String> actions,
  ) {
    final artifact = _objectOrEmpty(call['artifact']);
    final transcriptText =
        artifact['transcript']?.toString() ??
        call['transcript']?.toString() ??
        '';
    final transcript = _transcript({
      'messages': artifact['messages'] ?? call['messages'],
    }, transcriptText);
    final resolution = _resolution(artifact, transcriptText, actions);
    final startedAt = _date(call['startedAt']) ?? DateTime.now().toUtc();
    final endedAt = _date(call['endedAt']) ?? startedAt;
    final customer = _objectOrEmpty(call['customer']);
    return {
      'id': call['id'],
      'startedAt': startedAt.toIso8601String(),
      'durationSeconds': endedAt
          .difference(startedAt)
          .inSeconds
          .clamp(0, 43200),
      'callerNumber':
          customer['number'] as String? ??
          (call['type'] == 'webCall' ? 'Web test call' : 'Unknown caller'),
      'resolved': resolution.$1,
      'resolutionReason': resolution.$2,
      'transcript': transcript,
      'actions': actions,
      'endedReason': call['endedReason'] as String? ?? 'unknown',
    };
  }

  Future<void> _handleEndOfCall(
    String routeId,
    Map<String, dynamic> integration,
    Map<String, dynamic> message,
  ) async {
    final workspaceKey = integration['workspaceKey'] as String;
    final workspace = store.workspace(workspaceKey);
    if (workspace == null) return;
    final call = _objectOrEmpty(message['call']);
    final callId = call['id'] as String? ?? message['callId'] as String?;
    if (callId == null) return;
    final records = (workspace['calls'] as List? ?? <dynamic>[]);
    if (records.cast<Map<String, dynamic>>().any(
      (item) => item['id'] == callId,
    )) {
      return;
    }
    records.insert(
      0,
      _callRecord({
        ...call,
        'id': callId,
        'artifact': message['artifact'] ?? call['artifact'],
        'transcript': message['transcript'] ?? call['transcript'],
        'startedAt': message['startedAt'] ?? call['startedAt'],
        'endedAt': message['endedAt'] ?? call['endedAt'],
        'customer': call['customer'] ?? message['customer'],
        'endedReason': message['endedReason'] ?? call['endedReason'],
      }, store.actionsForCall(routeId, callId)),
    );
    workspace['calls'] = records;
    await store.saveWorkspace(workspaceKey, workspace);
  }

  Map<String, dynamic> _assistantPayload(
    Map<String, dynamic> agent, {
    required String? webhookUrl,
    required String webhookSecret,
    required List<String> webpageContents,
    String? structuredOutputId,
  }) {
    if (webhookUrl == null) {
      agent = {
        ...agent,
        'createContactEnabled': false,
        'bookMeetingEnabled': false,
      };
    }
    final tools = <Map<String, dynamic>>[];
    if (agent['createContactEnabled'] == true) {
      tools.add(
        _functionTool(
          name: 'create_contact',
          description:
              'Create or update a CRM contact after confirming their details aloud.',
          webhookUrl: webhookUrl!,
          webhookSecret: webhookSecret,
          properties: {
            'name': {'type': 'string'},
            'phone': {'type': 'string'},
            'email': {'type': 'string'},
            'company': {'type': 'string'},
            'jobTitle': {'type': 'string'},
            'leadStatus': {
              'type': 'string',
              'enum': ['New', 'Qualified', 'Nurture', 'Disqualified'],
            },
            'budgetRange': {'type': 'string'},
            'notes': {'type': 'string'},
          },
          required: ['name'],
        ),
      );
    }
    if (agent['bookMeetingEnabled'] == true) {
      tools
        ..add(
          _functionTool(
            name: 'get_meeting_slots',
            description:
                'Get available meeting times before offering times to the caller.',
            webhookUrl: webhookUrl!,
            webhookSecret: webhookSecret,
            properties: const {},
            required: const [],
          ),
        )
        ..add(
          _functionTool(
            name: 'book_meeting',
            description:
                'Book the meeting time the caller explicitly selected.',
            webhookUrl: webhookUrl,
            webhookSecret: webhookSecret,
            properties: {
              'contactName': {'type': 'string'},
              'contactId': {'type': 'string'},
              'email': {'type': 'string'},
              'phone': {'type': 'string'},
              'startsAt': {
                'type': 'string',
                'description': 'ISO 8601 date and time including offset',
              },
            },
            required: ['contactName', 'startsAt'],
          ),
        );
    }
    return {
      'name': agent['name'],
      'firstMessage': agent['greeting'],
      'voice': {'provider': 'vapi', 'voiceId': agent['voice'] ?? 'Elliot'},
      'model': {
        'provider': 'openai',
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': buildLeadQualificationPrompt(
              agent,
              webpageContents: webpageContents,
            ),
          },
        ],
        'tools': tools,
      },
      if (webhookUrl != null) ...{
        'server': {
          'url': webhookUrl,
          'headers': {'X-Webhook-Secret': webhookSecret},
          'timeoutSeconds': 20,
        },
        'serverMessages': ['end-of-call-report', 'tool-calls'],
      },
      'artifactPlan': {
        'recordingEnabled': false,
        'loggingEnabled': true,
        'transcriptPlan': {'enabled': true},
        if (structuredOutputId != null)
          'structuredOutputIds': [structuredOutputId],
      },
      'maxDurationSeconds': 600,
    };
  }

  Map<String, dynamic> _functionTool({
    required String name,
    required String description,
    required String webhookUrl,
    required String webhookSecret,
    required Map<String, dynamic> properties,
    required List<String> required,
  }) => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': properties,
        'required': required,
      },
    },
    'server': {
      'url': webhookUrl,
      'headers': {'X-Webhook-Secret': webhookSecret},
    },
  };

  Future<List<String>> _fetchWebpages(Map<String, dynamic> agent) async {
    final sources = (agent['knowledgeSources'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((source) => source['kind'] == 'webpage')
        .take(4);
    final pages = <String>[];
    for (final source in sources) {
      final uri = Uri.tryParse(source['content'] as String? ?? '');
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) continue;
      try {
        final response = await _safeFetch(uri);
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        var text = response.body
            .replaceAll(
              RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
              ' ',
            )
            .replaceAll(
              RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
              ' ',
            )
            .replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.length > 6000) text = text.substring(0, 6000);
        if (text.isNotEmpty) pages.add('Source: $uri\n$text');
      } on Object {
        // One unavailable page should not prevent the rest of the agent syncing.
      }
    }
    return pages;
  }

  Future<http.Response> _safeFetch(Uri initial) async {
    var uri = initial;
    final client = http.Client();
    try {
      for (var redirects = 0; redirects <= 3; redirects++) {
        if (!await _isPublicWebUri(uri)) {
          throw const ApiException(
            400,
            'Private network URLs are not allowed.',
          );
        }
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers['User-Agent'] = 'VoiceAgentKnowledgeBot/1.0';
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 8));
        final response = await http.Response.fromStream(streamed);
        if (response.isRedirect) {
          final location = response.headers['location'];
          if (location == null || redirects == 3) return response;
          uri = uri.resolve(location);
          continue;
        }
        return response;
      }
      throw const ApiException(400, 'Too many webpage redirects.');
    } finally {
      client.close();
    }
  }

  Future<bool> _isPublicWebUri(Uri uri) async {
    if (!{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      return false;
    }
    if (uri.userInfo.isNotEmpty) return false;
    final addresses = await InternetAddress.lookup(uri.host);
    return addresses.isNotEmpty && addresses.every(_isPublicAddress);
  }

  bool _isPublicAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal) return false;
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      final first = bytes[0];
      final second = bytes[1];
      return first != 0 &&
          first != 10 &&
          first != 127 &&
          first < 224 &&
          !(first == 169 && second == 254) &&
          !(first == 172 && second >= 16 && second <= 31) &&
          !(first == 192 && second == 168);
    }
    if (bytes.every((byte) => byte == 0)) return false;
    return !(bytes[0] == 0xfc ||
        bytes[0] == 0xfd ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80));
  }

  (bool, String) _resolution(
    Map<String, dynamic> artifact,
    String transcript,
    List<String> actions,
  ) {
    final lowered = transcript.toLowerCase();
    if (lowered.contains('speak to a human') ||
        lowered.contains('speak with a person') ||
        lowered.contains('talk to a person')) {
      return (false, 'Caller requested a human and no handoff is available.');
    }
    final found = _findResolution(artifact['structuredOutputs']);
    if (found != null) return found;
    if (actions.isNotEmpty) {
      return (true, '${actions.join(' and ')} completed successfully.');
    }
    return (false, 'No caller goal was confirmed as completed.');
  }

  (bool, String)? _findResolution(dynamic value) {
    if (value is Map) {
      if (value['resolved'] is bool) {
        return (
          value['resolved'] as bool,
          value['reason']?.toString() ?? 'Post-call analysis completed.',
        );
      }
      for (final nested in value.values) {
        final found = _findResolution(nested);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final nested in value) {
        final found = _findResolution(nested);
        if (found != null) return found;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _transcript(
    Map<String, dynamic> artifact,
    String fallback,
  ) {
    final messages = artifact['messages'] as List?;
    if (messages != null) {
      return messages
          .whereType<Map<String, dynamic>>()
          .where((item) {
            return const {'assistant', 'bot', 'user'}.contains(item['role']);
          })
          .map((item) {
            return {
              'role': item['role'] == 'user' ? 'caller' : 'assistant',
              'text':
                  item['message']?.toString() ??
                  item['content']?.toString() ??
                  '',
            };
          })
          .where((item) => (item['text'] as String).isNotEmpty)
          .toList();
    }
    return fallback
        .split(RegExp(r'(?=(?:AI|User|Assistant|Caller):)'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final assistant =
              line.startsWith('AI:') || line.startsWith('Assistant:');
          return {
            'role': assistant ? 'assistant' : 'caller',
            'text': line.replaceFirst(
              RegExp(r'^(AI|User|Assistant|Caller):\s*'),
              '',
            ),
          };
        })
        .toList();
  }

  List<String> _meetingSlots() {
    final slots = <String>[];
    var day = DateTime.now().toUtc().add(const Duration(days: 1));
    while (slots.length < 4) {
      if (day.weekday <= DateTime.friday) {
        slots
          ..add(
            DateTime.utc(day.year, day.month, day.day, 18).toIso8601String(),
          )
          ..add(
            DateTime.utc(day.year, day.month, day.day, 22).toIso8601String(),
          );
      }
      day = day.add(const Duration(days: 1));
    }
    return slots;
  }

  Response _toolError(Map<String, dynamic> message, String error) {
    final calls = (message['toolCallList'] as List? ?? const []);
    return _json(200, {
      'results': calls
          .map((item) => {'toolCallId': (item as Map)['id'], 'error': error})
          .toList(),
    });
  }

  String _workspaceKey(Request request) {
    final authorization = request.headers['authorization'] ?? '';
    if (!authorization.startsWith('Bearer ')) {
      throw const ApiException(401, 'Missing installation credential.');
    }
    final token = authorization.substring(7).trim();
    if (token.length < 32 || token.length > 128) {
      throw const ApiException(401, 'Invalid installation credential.');
    }
    return store.keyForToken(token);
  }

  Future<Map<String, dynamic>> _readObject(Request request) async {
    try {
      final body = await request.readAsString();
      if (body.length > 2000000) {
        throw const ApiException(413, 'Request is too large.');
      }
      return _object(jsonDecode(body));
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException(400, 'Invalid JSON body.');
    }
  }

  void _validateWorkspace(Map<String, dynamic> workspace) {
    final agent = workspace['agent'];
    if (agent is! Map || agent['id'] is! String || agent['name'] is! String) {
      throw const ApiException(400, 'Workspace agent is invalid.');
    }
  }
}

Middleware _cors() =>
    (inner) => (request) async {
      final response = await inner(request);
      return response.change(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers':
              'Authorization, Content-Type, X-Webhook-Secret',
          'Access-Control-Allow-Methods': 'GET, PUT, POST, OPTIONS',
        },
      );
    };

Response _json(int statusCode, Map<String, dynamic> body) => Response(
  statusCode,
  body: jsonEncode(body),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _object(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  throw const ApiException(400, 'Expected an object.');
}

Map<String, dynamic> _objectOrEmpty(dynamic value) {
  if (value == null) return <String, dynamic>{};
  try {
    return _object(value);
  } on ApiException {
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _arguments(dynamic value) {
  if (value is String) {
    try {
      return _object(jsonDecode(value));
    } on Object {
      return <String, dynamic>{};
    }
  }
  return _objectOrEmpty(value);
}

String _requiredString(Map<String, dynamic> arguments, String key) {
  final value = arguments[key]?.toString().trim() ?? '';
  if (value.isEmpty) throw ApiException(400, '$key is required.');
  return value;
}

DateTime? _date(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
