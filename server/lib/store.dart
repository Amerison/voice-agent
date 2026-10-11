import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

class FileStore {
  FileStore(this.path);

  final String path;
  Map<String, dynamic> _root = {
    'workspaces': <String, dynamic>{},
    'integrations': <String, dynamic>{},
  };
  Future<void> _writes = Future<void>.value();

  Future<void> initialize() async {
    final file = File(path);
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) _root = decoded;
  }

  String keyForToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Map<String, dynamic>? workspace(String key) {
    final value = (_root['workspaces'] as Map<String, dynamic>)[key];
    return value == null
        ? null
        : Map<String, dynamic>.from(value as Map<String, dynamic>);
  }

  Future<void> saveWorkspace(String key, Map<String, dynamic> workspace) async {
    (_root['workspaces'] as Map<String, dynamic>)[key] = workspace;
    await _persist();
  }

  Map<String, dynamic> ensureIntegration(String workspaceKey, String agentId) {
    final integrations = _root['integrations'] as Map<String, dynamic>;
    for (final entry in integrations.entries) {
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
    integrations[routeId] = value;
    _persist();
    return {'routeId': routeId, ...value};
  }

  Map<String, dynamic>? integration(String routeId) {
    final value = (_root['integrations'] as Map<String, dynamic>)[routeId];
    return value == null
        ? null
        : Map<String, dynamic>.from(value as Map<String, dynamic>);
  }

  Future<void> recordAction(
    String routeId,
    String callId,
    String action,
  ) async {
    final integration =
        (_root['integrations'] as Map<String, dynamic>)[routeId]
            as Map<String, dynamic>;
    final actions = integration['actions'] as Map<String, dynamic>;
    final current = (actions[callId] as List? ?? <dynamic>[]).cast<String>();
    if (!current.contains(action)) current.add(action);
    actions[callId] = current;
    await _persist();
  }

  List<String> actionsForCall(String routeId, String callId) {
    final integration =
        (_root['integrations'] as Map<String, dynamic>)[routeId]
            as Map<String, dynamic>?;
    final actions = integration?['actions'] as Map<String, dynamic>?;
    return (actions?[callId] as List? ?? const []).cast<String>();
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
