import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'mock_contacts.dart';
import 'models.dart';
import 'repository.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, {this.seedMockContacts = true});

  static const _darkModeKey = 'voice_agent_dark_mode';

  final WorkspaceRepository repository;
  final bool seedMockContacts;
  WorkspaceData? _data;
  Future<void>? _syncing;
  bool _busy = false;
  bool _darkMode = true;
  String? _error;
  var _calendarAttempt = 0;
  bool _connectingCalendar = false;

  WorkspaceData get data => _data!;
  bool get isReady => _data != null;
  bool get isBusy => _busy;

  /// True while Google's consent page is open and the server hasn't
  /// received the grant yet.
  bool get isConnectingCalendar => _connectingCalendar;
  bool get isDemo => repository.isDemo;
  bool get isDarkMode => _darkMode;
  String? get error => _error;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _darkMode = preferences.getBool(_darkModeKey) ?? true;
    await _run(() async => _data = await repository.load());
    if (seedMockContacts && isReady) await _addMockContacts(preferences);
    if (!isDemo && isReady && data.onboardingComplete) await refresh();
    if (isReady && data.onboardingComplete) unawaited(syncAgent());
  }

  /// A real number onboarding can show before it's bought. Null in demo mode
  /// or when the server can't reach Twilio.
  Future<String?> availableNumber(String areaCode) async {
    try {
      return await repository.availableNumber(areaCode);
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
    unawaited(syncAgent());
  }

  Future<void> updateAgent(AgentConfig agent) async {
    _data = data.copyWith(agent: agent.copyWith(syncStatus: SyncStatus.draft));
    notifyListeners();
    await _persist();
    if (data.onboardingComplete) unawaited(syncAgent());
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

  /// Pushes the agent to Vapi. Runs on its own after every agent change;
  /// callers only await it when they need the synced assistant. Overlapping
  /// requests queue behind the running sync instead of racing it.
  Future<void> syncAgent() async {
    while (_syncing != null) {
      await _syncing;
    }
    if (!isReady || data.agent.syncStatus == SyncStatus.ready) return;
    final sync = _sync();
    _syncing = sync;
    try {
      await sync;
    } finally {
      _syncing = null;
    }
  }

  Future<void> _sync() async {
    final sent = data.copyWith(
      agent: data.agent.copyWith(syncStatus: SyncStatus.syncing),
    );
    _data = sent;
    notifyListeners();
    try {
      final synced = (await repository.syncAgent(sent)).agent;
      final changedMeanwhile = !identical(_data, sent);
      // Edits made while syncing stay local and trigger the next sync.
      final edited = data.agent.syncStatus != SyncStatus.syncing;
      _data = data.copyWith(
        agent: data.agent.copyWith(
          vapiAssistantId: synced.vapiAssistantId,
          vapiStructuredOutputId: synced.vapiStructuredOutputId,
          lastSyncedAt: synced.lastSyncedAt,
          syncStatus: edited ? SyncStatus.draft : SyncStatus.ready,
          clearSyncError: true,
        ),
      );
      notifyListeners();
      if (changedMeanwhile) await _persist();
    } on Object catch (exception) {
      _error = _message(exception);
      _data = data.copyWith(
        agent: data.agent.copyWith(
          syncStatus: data.agent.syncStatus == SyncStatus.syncing
              ? SyncStatus.failed
              : null,
          syncError: _error,
        ),
      );
      notifyListeners();
    }
  }

  /// Gets the agent its own number in [areaCode], trying [number] first when
  /// onboarding showed one. Failures land in [error].
  Future<void> provisionNumber(String areaCode, {String? number}) async {
    if (!RegExp(r'^\d{3}$').hasMatch(areaCode)) {
      throw const WorkspaceException('Enter a three-digit US area code.');
    }
    await syncAgent();
    if (data.agent.syncStatus != SyncStatus.ready) {
      throw WorkspaceException(
        data.agent.syncError ?? 'The agent couldn’t be set up. Try again.',
      );
    }
    await _run(() async {
      final provisioned = (await repository.provisionNumber(
        data,
        areaCode,
        number: number,
      )).agent;
      // Merge so edits made while the number was being bought survive.
      _data = data.copyWith(
        agent: data.agent.copyWith(
          phoneNumber: provisioned.phoneNumber,
          vapiPhoneNumberId: provisioned.vapiPhoneNumberId,
        ),
      );
      await _persist();
    });
    // Twilio compliance holds on the account aren't something users can act on.
    if (_error?.contains('restricted from provisioning') ?? false) {
      clearError();
    }
  }

  /// Opens Google's consent page in an in-app browser and waits for the
  /// server to receive the grant, so "Book a meeting" adds events to the
  /// owner's Google Calendar. Calling again restarts the wait. Returns
  /// whether the calendar ended up connected.
  Future<bool> connectGoogleCalendar() async {
    final attempt = ++_calendarAttempt;
    _error = null;
    try {
      var status = await repository.googleCalendarStatus();
      final consent = status.connected
          ? null
          : await repository.googleCalendarConsentUrl();
      if (consent != null) {
        _connectingCalendar = true;
        notifyListeners();
        if (!await launchUrl(consent, mode: LaunchMode.inAppBrowserView)) {
          throw const WorkspaceException('Couldn’t open Google sign-in.');
        }
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (!status.connected) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (attempt != _calendarAttempt) return false;
          if (DateTime.now().isAfter(deadline)) return false;
          try {
            status = await repository.googleCalendarStatus();
          } on Object {
            // A dropped poll shouldn't end the wait; the next one retries.
          }
        }
        unawaited(closeInAppWebView().catchError((_) {}));
      }
      _data = data.copyWith(
        agent: data.agent.copyWith(
          calendarConnected: true,
          calendarEmail: status.email,
        ),
      );
      await _persist();
      return true;
    } on Object catch (exception) {
      _error = _message(exception);
      return false;
    } finally {
      if (attempt == _calendarAttempt) _connectingCalendar = false;
      notifyListeners();
    }
  }

  Future<void> disconnectGoogleCalendar() async {
    _calendarAttempt++;
    _connectingCalendar = false;
    await _run(() async {
      await repository.disconnectGoogleCalendar();
      _data = data.copyWith(
        agent: data.agent.copyWith(
          calendarConnected: false,
          clearCalendarEmail: true,
        ),
      );
      await _persist();
    });
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

  /// Runs once per workspace, so deleted samples don't come back.
  Future<void> _addMockContacts(SharedPreferences preferences) async {
    final key = 'voice_agent_mock_contacts_${isDemo ? 'demo' : 'live'}';
    if (preferences.getBool(key) ?? false) return;
    final existing = data.contacts.map((contact) => contact.id).toSet();
    final added = mockContacts(
      DateTime.now(),
    ).where((contact) => !existing.contains(contact.id));
    _data = data.copyWith(contacts: [...data.contacts, ...added]);
    await _persist();
    await preferences.setBool(key, true);
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
    if (exception is ClientException) {
      if (kReleaseMode) {
        return 'Can’t reach HubSpot Test right now. Check your internet connection and try again.';
      }
      return 'Can’t reach the app server at $apiBaseUrl. Start the server run script, then try again.';
    }
    return 'Something went wrong. Check the connection and try again.';
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
