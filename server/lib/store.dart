import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Server-side state only: webhook routes, phone numbers, Google Calendar
/// grants, and records made during calls that the app hasn't fetched yet.
/// Workspaces (agent, CRM, meetings, calls) live on the device.
class FileStore {
  FileStore(this.path);

  final String path;
  Map<String, dynamic> _root = {
    'workspaces': <String, dynamic>{},
    'integrations': <String, dynamic>{},
    'numbers': <String, dynamic>{},
    'calendars': <String, dynamic>{},
  };
  Future<void> _writes = Future<void>.value();

  Map<String, dynamic> get _integrations =>
      _root['integrations'] as Map<String, dynamic>;

  Map<String, dynamic> get _numbers => _root['numbers'] as Map<String, dynamic>;

  Map<String, dynamic> get _calendars =>
      _root['calendars'] as Map<String, dynamic>;

  Future<void> initialize() async {
    final file = File(path);
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) _root = {..._root, ...decoded};
  }

  String keyForToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// A workspace saved before data moved onto the device. Read-only: the app
  /// imports it once.
  Map<String, dynamic>? workspace(String key) {
    final value = (_root['workspaces'] as Map<String, dynamic>)[key];
    return value == null
        ? null
        : Map<String, dynamic>.from(value as Map<String, dynamic>);
  }

  /// The Twilio number bought for a workspace and its Vapi id, once imported.
  Map<String, dynamic>? number(String workspaceKey) {
    final value = _numbers[workspaceKey];
    return value == null
        ? null
        : Map<String, dynamic>.from(value as Map<String, dynamic>);
  }

  Future<void> saveNumber(String workspaceKey, Map<String, dynamic> number) {
    _numbers[workspaceKey] = number;
    return _persist();
  }

  /// The Google Calendar grant for a workspace: `refreshToken`, `email`, and
  /// `connectedAt`.
  Map<String, dynamic>? calendar(String workspaceKey) {
    final value = _calendars[workspaceKey];
    return value == null
        ? null
        : Map<String, dynamic>.from(value as Map<String, dynamic>);
  }

  Future<void> saveCalendar(
    String workspaceKey,
    Map<String, dynamic> calendar,
  ) {
    _calendars[workspaceKey] = calendar;
    return _persist();
  }

  Future<void> removeCalendar(String workspaceKey) {
    _calendars.remove(workspaceKey);
    return _persist();
  }

  Future<Map<String, dynamic>> ensureIntegration(
    String workspaceKey,
    String agentId,
  ) async {
    for (final entry in _integrations.entries) {
      final value = entry.value as Map<String, dynamic>;
      if (value['workspaceKey'] == workspaceKey &&
          value['agentId'] == agentId) {
        return {'routeId': entry.key, ...value};
      }
    }
    final routeId = _randomToken(18);
    final value = <String, dynamic>{
      'workspaceKey': workspaceKey,
      'agentId': agentId,
      'secret': _randomToken(32),
      'actions': <String, dynamic>{},
    };
    _integrations[routeId] = value;
    await _persist();
    return {'routeId': routeId, ...value};
  }

  Map<String, dynamic>? integration(String routeId) {
    final value = _integrations[routeId];
    return value == null
        ? null
        : Map<String, dynamic>.from(value as Map<String, dynamic>);
  }

  Future<void> recordAction(
    String routeId,
    String callId,
    String action,
  ) async {
    final integration = _integrations[routeId] as Map<String, dynamic>;
    final actions = integration['actions'] as Map<String, dynamic>;
    final current = (actions[callId] as List? ?? <dynamic>[]).cast<String>();
    if (!current.contains(action)) current.add(action);
    actions[callId] = current;
    await _persist();
  }

  List<String> actionsForCall(String routeId, String callId) {
    final integration = _integrations[routeId] as Map<String, dynamic>?;
    final actions = integration?['actions'] as Map<String, dynamic>?;
    return (actions?[callId] as List? ?? const []).cast<String>();
  }

  /// Holds a contact, meeting, or call made during a call until the app
  /// confirms it saved it; see [acknowledge].
  Future<void> addPending(
    String routeId,
    String type,
    Map<String, dynamic> record,
  ) async {
    final integration = _integrations[routeId] as Map<String, dynamic>;
    final seq = (integration['pendingSeq'] as int? ?? 0) + 1;
    integration['pendingSeq'] = seq;
    ((integration['pending'] ??= <dynamic>[]) as List).add({
      'seq': seq,
      'type': type,
      'record': record,
    });
    await _persist();
  }

  List<Map<String, dynamic>> pending(String routeId) {
    final integration = _integrations[routeId] as Map<String, dynamic>?;
    return (integration?['pending'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// Drops pending records up to [cursor], the last sequence number the app
  /// saved.
  Future<void> acknowledge(String routeId, int cursor) async {
    final pending = _integrations[routeId]?['pending'] as List?;
    if (pending == null || pending.isEmpty) return;
    final before = pending.length;
    pending.removeWhere((item) => ((item as Map)['seq'] as int) <= cursor);
    if (pending.length != before) await _persist();
  }

  Future<void> _persist() {
    _writes = _writes.then((_) async {
      final file = File(path);
      await file.parent.create(recursive: true);
      final temporary = File('$path.tmp');
      await temporary.writeAsString(jsonEncode(_root), flush: true);
      await temporary.rename(path);
    });
    return _writes;
  }

  String _randomToken(int bytes) {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(bytes, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }
}
