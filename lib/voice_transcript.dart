import 'dart:async';

import 'package:flutter/foundation.dart';

enum TranscriptSpeaker { agent, user }

@immutable
class TranscriptLine {
  const TranscriptLine({required this.speaker, required this.text});

  final TranscriptSpeaker speaker;
  final String text;
}

/// Turns Vapi's sentence-by-sentence transcript events into one line per turn.
///
/// Agent sentences are appended to the agent's current turn. User speech is
/// held back until the user has been quiet for [userSettleDelay], so several
/// final fragments become a single line; [isUserThinking] is true meanwhile.
class VoiceTranscript extends ChangeNotifier {
  VoiceTranscript({this.userSettleDelay = const Duration(milliseconds: 1200)});

  final Duration userSettleDelay;
  final List<TranscriptLine> _lines = [];
  final List<String> _pendingUser = [];
  Timer? _userTimer;

  List<TranscriptLine> get lines => List.unmodifiable(_lines);

  bool get isUserThinking => _pendingUser.isNotEmpty;

  bool get isEmpty => _lines.isEmpty && _pendingUser.isEmpty;

  void addAgent(String text) {
    final sentence = text.trim();
    if (sentence.isEmpty) return;
    _commitUser();
    final last = _lines.isEmpty ? null : _lines.last;
    if (last != null && last.speaker == TranscriptSpeaker.agent) {
      _lines.last = TranscriptLine(
        speaker: TranscriptSpeaker.agent,
        text: '${last.text} $sentence',
      );
    } else {
      _lines.add(
        TranscriptLine(speaker: TranscriptSpeaker.agent, text: sentence),
      );
    }
    notifyListeners();
  }

  void addUser(String text) {
    final fragment = text.trim();
    if (fragment.isEmpty) return;
    _pendingUser.add(fragment);
    _restartUserTimer();
    notifyListeners();
  }

  /// Call for partial user transcripts so a pause mid-sentence doesn't commit.
  void userStillSpeaking() {
    if (_pendingUser.isNotEmpty) _restartUserTimer();
  }

  void flush() {
    if (_commitUser()) notifyListeners();
  }

  void clear() {
    _userTimer?.cancel();
    _pendingUser.clear();
    _lines.clear();
    notifyListeners();
  }

  void _restartUserTimer() {
    _userTimer?.cancel();
    _userTimer = Timer(userSettleDelay, flush);
  }

  bool _commitUser() {
    _userTimer?.cancel();
    if (_pendingUser.isEmpty) return false;
    _lines.add(
      TranscriptLine(
        speaker: TranscriptSpeaker.user,
        text: _pendingUser.join(' '),
      ),
    );
    _pendingUser.clear();
    return true;
  }

  @override
  void dispose() {
    _userTimer?.cancel();
    super.dispose();
  }
}
