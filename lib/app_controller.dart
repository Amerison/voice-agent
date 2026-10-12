import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'repository.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);

  static const _darkModeKey = 'voice_agent_dark_mode';

  final WorkspaceRepository repository;
  WorkspaceData? _data;
  bool _busy = false;
  bool _darkMode = true;
  String? _error;

  WorkspaceData get data => _data!;
  bool get isReady => _data != null;
  bool get isBusy => _busy;
  bool get isDemo => repository.isDemo;
  bool get isDarkMode => _darkMode;
  String? get error => _error;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = preferences.getBool(_darkModeKey) ?? true;
    await _run(() async => _data = await repository.load());
    if (!isDemo && isReady && data.onboardingComplete) await refresh();
  }

  /// Null in demo mode or when the server can't reach Vapi.
  Future<String?> accountNumber() async {
    try {
      return await repository.accountNumber();
    } on Object {
      return null;
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeKey, value);
  }

  Future<void> completeOnboarding({AgentConfig? agent}) async {
    _data = data.copyWith(onboardingComplete: true, agent: agent ?? data.agent);
    notifyListeners();
    await _persist();
  }

  Future<void> updateAgent(AgentConfig agent) async {
    _data = data.copyWith(agent: agent.copyWith(syncStatus: SyncStatus.draft));
    notifyListeners();
    await _persist();
  }

  Future<void> addWebpage(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const WorkspaceException(
        'Enter a complete URL, including https://.',
      );
    }
    final source = KnowledgeSource(
      id: _newId('source'),
      kind: KnowledgeKind.webpage,
      title: uri.host,
      content: uri.toString(),
    );
    await updateAgent(
      data.agent.copyWith(
        knowledgeSources: [...data.agent.knowledgeSources, source],
      ),
    );
  }

  Future<void> addShortAnswer(String question, String answer) async {
    if (question.trim().isEmpty || answer.trim().isEmpty) {
      throw const WorkspaceException('Add both a question and an answer.');
    }
    final source = KnowledgeSource(
      id: _newId('source'),
      kind: KnowledgeKind.shortAnswer,
      title: question.trim(),
      content: question.trim(),
      answer: answer.trim(),
    );
    await updateAgent(
      data.agent.copyWith(
        knowledgeSources: [...data.agent.knowledgeSources, source],
      ),
    );
  }

  Future<void> removeKnowledgeSource(String id) async {
    await updateAgent(
      data.agent.copyWith(
        knowledgeSources: data.agent.knowledgeSources
            .where((source) => source.id != id)
            .toList(),
      ),
    );
  }

  Future<void> syncAgent() async {
    _data = data.copyWith(
      agent: data.agent.copyWith(syncStatus: SyncStatus.syncing),
    );
    notifyListeners();
    await _run(() async => _data = await repository.syncAgent(data));
    if (_error != null) {
      _data = data.copyWith(
        agent: data.agent.copyWith(
          syncStatus: SyncStatus.failed,
          syncError: _error,
        ),
      );
      notifyListeners();
    }
  }

  Future<void> provisionNumber(String areaCode) async {
    if (!RegExp(r'^\d{3}$').hasMatch(areaCode)) {
      throw const WorkspaceException('Enter a three-digit US area code.');
    }
    if (data.agent.syncStatus != SyncStatus.ready) {
      throw const WorkspaceException('Sync the agent before getting a number.');
    }
    await _run(
      () async => _data = await repository.provisionNumber(data, areaCode),
    );
  }

  Future<void> refresh() async {
    await _run(() async => _data = await repository.refresh(data));
  }

  Future<void> saveContact(Contact contact) async {
    final contacts = [...data.contacts];
    final index = contacts.indexWhere((item) => item.id == contact.id);
    if (index == -1) {
      contacts.insert(0, contact);
    } else {
      contacts[index] = contact;
    }
    _data = data.copyWith(contacts: contacts);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteContact(String id) async {
    _data = data.copyWith(
      contacts: data.contacts.where((item) => item.id != id).toList(),
    );
    notifyListeners();
    await _persist();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await repository.save(data);
    } on Object catch (exception) {
      _error = _message(exception);
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
    } on Object catch (exception) {
      _error = _message(exception);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _message(Object exception) {
    if (exception is WorkspaceException) return exception.message;
    return 'Something went wrong. Check the connection and try again.';
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
