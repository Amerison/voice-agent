import 'package:test/test.dart';
import 'package:voice_agent_server/prompt_builder.dart';

void main() {
  test('includes identity, guidelines, tools, and verified answers', () {
    final prompt = buildLeadQualificationPrompt({
      'name': 'Maya',
      'persona': 'an SDR',
      'companyName': 'Northstar',
      'companyDescription': 'Lead qualification software',
      'friendliness': 'friendly',
      'guidelines': 'Never quote prices.',
      'createContactEnabled': true,
      'bookMeetingEnabled': true,
      'knowledgeSources': [
        {
          'kind': 'shortAnswer',
          'content': 'What do you do?',
          'answer': 'We qualify inbound leads.',
        },
      ],
    });

    expect(prompt, contains('You are Maya'));
    expect(prompt, contains('Never quote prices.'));
    expect(prompt, contains('create_contact'));
    expect(prompt, contains('book_meeting'));
    expect(prompt, contains('We qualify inbound leads.'));
    expect(
      prompt,
      contains('If asked whether you are a bot, say yes plainly.'),
    );
  });

  test('uses receptionist behavior for receptionist agents', () {
    final prompt = buildLeadQualificationPrompt({
      'type': 'receptionist',
      'name': 'Luna',
      'persona': 'the AI receptionist',
      'companyName': 'Acme',
    });

    expect(prompt, contains('RECEPTIONIST BEHAVIOR'));
    expect(prompt, isNot(contains('LEAD QUALIFICATION BEHAVIOR')));
  });

  test('skips qualification when the qualify leads action is off', () {
    final prompt = buildLeadQualificationPrompt({
      'name': 'Maya',
      'persona': 'an SDR',
      'companyName': 'Northstar',
      'qualifyLeadsEnabled': false,
    });

    expect(prompt, contains('CALLER BEHAVIOR'));
    expect(prompt, isNot(contains('LEAD QUALIFICATION BEHAVIOR')));
  });
}
