import 'package:flutter_test/flutter_test.dart';
import 'package:voice_agent/voice_transcript.dart';

void main() {
  const settle = Duration(milliseconds: 1200);

  testWidgets('bundles consecutive agent sentences into one turn', (
    tester,
  ) async {
    final transcript = VoiceTranscript();
    addTearDown(transcript.dispose);

    transcript
      ..addAgent('Hi, this is Maya.')
      ..addAgent('How can I help you today?');

    expect(transcript.lines, hasLength(1));
    expect(
      transcript.lines.single.text,
      'Hi, this is Maya. How can I help you today?',
    );
  });

  testWidgets('holds user speech until a pause, then commits one line', (
    tester,
  ) async {
    final transcript = VoiceTranscript(userSettleDelay: settle);
    addTearDown(transcript.dispose);

    transcript.addUser('I want to');
    expect(transcript.isUserThinking, isTrue);
    expect(transcript.lines, isEmpty);
    expect(transcript.isEmpty, isFalse);

    await tester.pump(const Duration(milliseconds: 800));
    transcript.userStillSpeaking();
    await tester.pump(const Duration(milliseconds: 800));
    transcript.addUser('book a demo.');
    await tester.pump(const Duration(milliseconds: 800));
    expect(transcript.lines, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    expect(transcript.isUserThinking, isFalse);
    expect(transcript.lines.single.speaker, TranscriptSpeaker.user);
    expect(transcript.lines.single.text, 'I want to book a demo.');
  });

  testWidgets('commits pending user speech before the agent replies', (
    tester,
  ) async {
    final transcript = VoiceTranscript(userSettleDelay: settle);
    addTearDown(transcript.dispose);

    transcript
      ..addAgent('What brings you in?')
      ..addUser('Pricing.')
      ..addAgent('Sure.')
      ..addAgent('Our plans start at fifty dollars.');

    expect(transcript.lines.map((line) => line.speaker), [
      TranscriptSpeaker.agent,
      TranscriptSpeaker.user,
      TranscriptSpeaker.agent,
    ]);
    expect(
      transcript.lines.last.text,
      'Sure. Our plans start at fifty dollars.',
    );
    expect(transcript.isUserThinking, isFalse);
  });
}
