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

  static const _workspaceKey = 'voice_agent_workspace_v2';
  final SharedPreferences preferences;

  @override
  bool get isDemo => true;

  @override
  Future<WorkspaceData> load() async {
    final encoded = preferences.getString(_workspaceKey);
    if (encoded == null) return emptyWorkspace();
    try {
      return WorkspaceData.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on Object {
      return emptyWorkspace();
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
      final initial = emptyWorkspace();
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

WorkspaceData emptyWorkspace() {
  return WorkspaceData(
    onboardingComplete: false,
    agent: const AgentConfig(
      id: 'lead-agent',
      type: AgentType.leadQualification,
      name: '',
      friendliness: Friendliness.friendly,
      persona: '',
      companyName: '',
      companyDescription: '',
      greeting: '',
      guidelines: '',
      knowledgeSources: [],
      bookMeetingEnabled: true,
      createContactEnabled: true,
      syncStatus: SyncStatus.draft,
    ),
    contacts: const [],
    meetings: const [],
    calls: const [],
  );
}
