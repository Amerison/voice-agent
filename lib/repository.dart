import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

abstract class WorkspaceRepository {
  bool get isDemo;

  Future<WorkspaceData> load();

  Future<void> save(WorkspaceData data);

  Future<WorkspaceData> syncAgent(WorkspaceData data);

  Future<WorkspaceData> provisionNumber(WorkspaceData data, String areaCode);

  Future<WorkspaceData> refresh(WorkspaceData data);
}

Future<WorkspaceRepository> createRepository() async {
  final preferences = await SharedPreferences.getInstance();
  if (apiBaseUrl.trim().isEmpty) {
    return LocalWorkspaceRepository(preferences);
  }
  return ApiWorkspaceRepository(
    preferences: preferences,
    baseUrl: apiBaseUrl.replaceFirst(RegExp(r'/$'), ''),
  );
}

class LocalWorkspaceRepository implements WorkspaceRepository {
  LocalWorkspaceRepository(this.preferences);

  static const _workspaceKey = 'voice_agent_workspace_v1';
  final SharedPreferences preferences;

  @override
  bool get isDemo => true;

  @override
  Future<WorkspaceData> load() async {
    final encoded = preferences.getString(_workspaceKey);
    if (encoded == null) return seedWorkspace();
    try {
      return WorkspaceData.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on Object {
      return seedWorkspace();
    }
  }

  @override
  Future<void> save(WorkspaceData data) =>
      preferences.setString(_workspaceKey, jsonEncode(data.toJson()));

  @override
  Future<WorkspaceData> syncAgent(WorkspaceData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final updated = data.copyWith(
      agent: data.agent.copyWith(
        syncStatus: SyncStatus.ready,
        vapiAssistantId: data.agent.vapiAssistantId ?? 'demo-assistant',
        lastSyncedAt: DateTime.now(),
        clearSyncError: true,
      ),
    );
    await save(updated);
    return updated;
  }

  @override
  Future<WorkspaceData> provisionNumber(
    WorkspaceData data,
    String areaCode,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final updated = data.copyWith(
      agent: data.agent.copyWith(
        phoneNumber: '+1 ($areaCode) 555-0142',
        vapiPhoneNumberId: 'demo-number',
      ),
    );
    await save(updated);
    return updated;
  }

  @override
  Future<WorkspaceData> refresh(WorkspaceData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return load();
  }
}

class ApiWorkspaceRepository implements WorkspaceRepository {
  ApiWorkspaceRepository({required this.preferences, required this.baseUrl});

  static const _tokenKey = 'voice_agent_installation_token';
  final SharedPreferences preferences;
  final String baseUrl;

  @override
  bool get isDemo => false;

  String get _token {
    final existing = preferences.getString(_tokenKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    preferences.setString(_tokenKey, token);
    return token;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Content-Type': 'application/json',
  };

  @override
  Future<WorkspaceData> load() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/workspace'),
      headers: _headers,
    );
    if (response.statusCode == 404) {
      final initial = seedWorkspace();
      await save(initial);
      return initial;
    }
    return _decodeWorkspace(response);
  }

  @override
  Future<void> save(WorkspaceData data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/v1/workspace'),
      headers: _headers,
      body: jsonEncode(data.toJson()),
    );
    _ensureSuccess(response);
  }

  @override
  Future<WorkspaceData> syncAgent(WorkspaceData data) =>
      _postWorkspace('/v1/agent/sync', data);

  @override
  Future<WorkspaceData> provisionNumber(
    WorkspaceData data,
    String areaCode,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/agent/provision-number'),
      headers: _headers,
      body: jsonEncode({'workspace': data.toJson(), 'areaCode': areaCode}),
    );
    return _decodeWorkspace(response);
  }

  @override
  Future<WorkspaceData> refresh(WorkspaceData data) => load();

  Future<WorkspaceData> _postWorkspace(String path, WorkspaceData data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode({'workspace': data.toJson()}),
    );
    return _decodeWorkspace(response);
  }

  WorkspaceData _decodeWorkspace(http.Response response) {
    _ensureSuccess(response);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final value = payload['workspace'] as Map<String, dynamic>? ?? payload;
    return WorkspaceData.fromJson(value);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'The server returned ${response.statusCode}.';
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      message = payload['error'] as String? ?? message;
    } on Object {
      // Keep the status-based message when the response is not JSON.
    }
    throw WorkspaceException(message);
  }
}

class WorkspaceException implements Exception {
  const WorkspaceException(this.message);
  final String message;

  @override
  String toString() => message;
}

WorkspaceData seedWorkspace() {
  final now = DateTime.now();
  final contacts = List<Contact>.generate(25, (index) {
    const firstNames = [
      'Avery',
      'Jordan',
      'Morgan',
      'Taylor',
      'Riley',
      'Casey',
      'Jamie',
      'Parker',
      'Quinn',
      'Cameron',
    ];
    const lastNames = [
      'Chen',
      'Patel',
      'Rivera',
      'Kim',
      'Okafor',
      'Martinez',
      'Nguyen',
      'Singh',
    ];
    const companies = [
      'Northstar Labs',
      'Juniper Health',
      'Harbor & Co.',
      'Brightpath',
      'Summit Works',
      'Fieldstone',
    ];
    const statuses = ['New', 'Qualified', 'Nurture', 'Disqualified'];
    final first = firstNames[index % firstNames.length];
    final last = lastNames[index % lastNames.length];
    return Contact(
      id: 'contact-${index + 1}',
      name: '$first $last',
      phone: '+1 415 555 ${1000 + index}',
      email: '${first.toLowerCase()}.${last.toLowerCase()}@example.com',
      company: companies[index % companies.length],
      jobTitle: index.isEven ? 'Head of Operations' : 'Growth Lead',
      leadSource: index % 3 == 0 ? 'Referral' : 'Inbound call',
      leadStatus: statuses[index % statuses.length],
      budgetRange: index.isEven ? r'$10k–$25k' : r'$25k–$50k',
      notes: index.isEven
          ? 'Interested in reducing manual follow-up.'
          : 'Asked about implementation time.',
      createdAt: now.subtract(Duration(days: index + 2)),
    );
  });

  return WorkspaceData(
    onboardingComplete: false,
    agent: AgentConfig(
      id: 'lead-agent',
      name: 'Maya',
      friendliness: Friendliness.friendly,
      persona: 'An experienced sales development representative',
      companyName: 'Northstar',
      companyDescription:
          'We help growing teams qualify and follow up with inbound leads.',
      greeting: 'Hi, you’ve reached Maya at Northstar. How can I help today?',
      guidelines:
          'Ask one question at a time.\nNever invent pricing.\nConfirm the caller’s email and phone number before saving.',
      knowledgeSources: const [
        KnowledgeSource(
          id: 'source-1',
          kind: KnowledgeKind.shortAnswer,
          title: 'What does Northstar do?',
          content: 'What does Northstar do?',
          answer:
              'Northstar helps growing teams qualify and follow up with inbound leads.',
        ),
      ],
      bookMeetingEnabled: true,
      createContactEnabled: true,
      syncStatus: SyncStatus.draft,
    ),
    contacts: contacts,
    meetings: List<Meeting>.generate(
      5,
      (index) => Meeting(
        id: 'meeting-${index + 1}',
        contactId: contacts[index].id,
        contactName: contacts[index].name,
        startsAt: now.add(Duration(days: index + 1, hours: 10 + index)),
        status: 'Scheduled',
      ),
    ),
    calls: [
      CallRecord(
        id: 'demo-call-1',
        startedAt: now.subtract(const Duration(hours: 2)),
        durationSeconds: 184,
        callerNumber: '+1 415 555 0188',
        resolved: true,
        resolutionReason: 'Qualified lead booked a discovery meeting.',
        transcript: const [
          TranscriptMessage(
            role: 'assistant',
            text: 'Hi, you’ve reached Maya at Northstar. How can I help today?',
          ),
          TranscriptMessage(
            role: 'caller',
            text: 'We need a better way to follow up with inbound leads.',
          ),
          TranscriptMessage(
            role: 'assistant',
            text: 'That makes sense. What is slowing your team down today?',
          ),
          TranscriptMessage(
            role: 'caller',
            text: 'We respond too late and lose good prospects.',
          ),
          TranscriptMessage(
            role: 'assistant',
            text:
                'I can help arrange a conversation. Would Tuesday at 10 or Wednesday at 2 work better?',
          ),
        ],
        actions: const ['Created contact', 'Booked meeting'],
        endedReason: 'customer-ended-call',
      ),
      CallRecord(
        id: 'demo-call-2',
        startedAt: now.subtract(const Duration(days: 1, hours: 3)),
        durationSeconds: 47,
        callerNumber: '+1 510 555 0114',
        resolved: false,
        resolutionReason:
            'Caller requested a human and no handoff is available.',
        transcript: const [
          TranscriptMessage(
            role: 'assistant',
            text: 'Hi, you’ve reached Maya at Northstar. How can I help today?',
          ),
          TranscriptMessage(
            role: 'caller',
            text: 'Can I speak with a person about a custom contract?',
          ),
          TranscriptMessage(
            role: 'assistant',
            text: 'I can take a message or help book a callback.',
          ),
        ],
        actions: const [],
        endedReason: 'customer-ended-call',
      ),
    ],
  );
}
