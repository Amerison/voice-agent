import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

/// Empty means demo mode. Release builds go to TestFlight and the App Store,
/// where a plain-HTTP development server on a home network is unreachable, so
/// they only accept an HTTPS server.
final apiBaseUrl =
    kReleaseMode && !_apiBaseUrlDefine.trim().startsWith('https://')
    ? ''
    : _apiBaseUrlDefine;

abstract class WorkspaceRepository {
  bool get isDemo;

  Future<WorkspaceData> load();

  Future<void> save(WorkspaceData data);

  Future<WorkspaceData> syncAgent(WorkspaceData data);

  /// Gets the agent its own phone number in [areaCode], trying [number]
  /// first when onboarding already showed one.
  Future<WorkspaceData> provisionNumber(
    WorkspaceData data,
    String areaCode, {
    String? number,
  });

  /// Pulls the latest calls; in live mode they come from Vapi.
  Future<WorkspaceData> refresh(WorkspaceData data);

  /// A number in [areaCode] that onboarding can show before it's bought, in
  /// E.164 form. Null in demo mode.
  Future<String?> availableNumber(String areaCode);
}

WorkspaceData? _readWorkspace(SharedPreferences preferences, String key) {
  final encoded = preferences.getString(key);
  if (encoded == null) return null;
  try {
    return WorkspaceData.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  } on Object {
    return null;
  }
}

Future<void> _writeWorkspace(
  SharedPreferences preferences,
  String key,
  WorkspaceData data,
) => preferences.setString(key, jsonEncode(data.toJson()));

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
  Future<WorkspaceData> load() async =>
      _readWorkspace(preferences, _workspaceKey) ?? emptyWorkspace();

  @override
  Future<void> save(WorkspaceData data) =>
      _writeWorkspace(preferences, _workspaceKey, data);

  @override
  Future<WorkspaceData> syncAgent(WorkspaceData data) async {
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
    String areaCode, {
    String? number,
  }) async {
    final updated = data.copyWith(
      agent: data.agent.copyWith(
        phoneNumber: number ?? '+1${areaCode}5550142',
        vapiPhoneNumberId: 'demo-number',
      ),
    );
    await save(updated);
    return updated;
  }

  @override
  Future<String?> availableNumber(String areaCode) async => null;

  @override
  Future<WorkspaceData> refresh(WorkspaceData data) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return load();
  }
}

/// Keeps the workspace (agent, CRM, meetings, calls) on the device and uses
/// the server only for work that needs the Vapi and Twilio secrets.
class ApiWorkspaceRepository implements WorkspaceRepository {
  ApiWorkspaceRepository({required this.preferences, required this.baseUrl});

  static const _tokenKey = 'voice_agent_installation_token';
  // Separate from demo data so a demo assistant id never reaches Vapi.
  static const _workspaceKey = 'voice_agent_live_workspace_v1';
  static const _inboxCursorKey = 'voice_agent_inbox_cursor';
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
    final saved = _readWorkspace(preferences, _workspaceKey);
    if (saved != null) return saved;
    final workspace = await _importFromServer() ?? emptyWorkspace();
    await save(workspace);
    return workspace;
  }

  /// Workspaces used to live on the server; brings one over on first launch.
  Future<WorkspaceData?> _importFromServer() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/v1/workspace'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      return _decodeWorkspace(response);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(WorkspaceData data) =>
      _writeWorkspace(preferences, _workspaceKey, data);

  @override
  Future<WorkspaceData> syncAgent(WorkspaceData data) async =>
      _saved(await _post('/v1/agent/sync', {'workspace': data.toJson()}));

  @override
  Future<WorkspaceData> provisionNumber(
    WorkspaceData data,
    String areaCode, {
    String? number,
  }) async => _saved(
    await _post('/v1/agent/provision-number', {
      'workspace': data.toJson(),
      'areaCode': areaCode,
      'number': ?number,
    }),
  );

  @override
  Future<WorkspaceData> refresh(WorkspaceData data) async {
    final payload = await _post('/v1/calls/refresh', {
      'workspace': data.toJson(),
      'inboxCursor': preferences.getInt(_inboxCursorKey) ?? 0,
    });
    final workspace = await _saved(payload);
    // Only after saving: the cursor tells the server it can drop these.
    final cursor = payload['inboxCursor'];
    if (cursor is int) await preferences.setInt(_inboxCursorKey, cursor);
    return workspace;
  }

  @override
  Future<String?> availableNumber(String areaCode) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/numbers/available?areaCode=$areaCode'),
      headers: _headers,
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map<String, dynamic>)['number']
        as String?;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<WorkspaceData> _saved(Map<String, dynamic> payload) async {
    final workspace = WorkspaceData.fromJson(
      payload['workspace'] as Map<String, dynamic>,
    );
    await save(workspace);
    return workspace;
  }

  WorkspaceData _decodeWorkspace(http.Response response) {
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return WorkspaceData.fromJson(payload['workspace'] as Map<String, dynamic>);
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
      type: AgentType.receptionist,
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
