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

  test('follows the user’s qualification setup', () {
    final agent = {
      'name': 'Maya',
      'persona': 'an SDR',
      'companyName': 'Northstar',
      'bookMeetingEnabled': true,
      'qualification': {
        'idealCustomer': 'Bay Area homeowners planning a remodel.',
        'questions': [
          {'text': 'What are you remodeling?', 'required': true},
          {'text': 'Who else decides?', 'required': false},
        ],
        'minimumBudget': r'$20,000',
        'startWithinMonths': 3,
        'requireDecisionMaker': true,
        'disqualifiers': ['Renters'],
        'meetingMinutes': 45,
        'notAFitMessage': 'Try our guide at northstar.com/guide.',
        'collect': ['phone', 'email'],
      },
    };
    final prompt = buildLeadQualificationPrompt(agent);

    expect(prompt, contains('- What are you remodeling? (required)'));
    expect(prompt, contains('- Who else decides?\n'));
    expect(prompt, contains('Bay Area homeowners planning a remodel.'));
    expect(prompt, contains(r'budget is at least $20,000'));
    expect(prompt, contains('within 3 months'));
    expect(prompt, contains('- Renters'));
    expect(prompt, contains('45-minute meeting and book'));
    expect(prompt, contains('northstar.com/guide'));
    expect(prompt, contains('name, phone number and email'));

    final analysis = buildCallAnalysis(agent);
    final schema = analysis['schema'] as Map<String, dynamic>;
    expect(schema['required'], contains('leadOutcome'));
    expect(analysis['description'], contains('- Renters'));
    expect(analysis['description'], contains('What are you remodeling?'));
  });

  test('takes a message for qualified leads when booking is off', () {
    final prompt = buildLeadQualificationPrompt({
      'name': 'Maya',
      'persona': 'an SDR',
      'companyName': 'Northstar',
      'qualification': {'meetingMinutes': 30},
    });

    expect(prompt, contains('take a message and say someone will reach out'));
  });

  test('judges only resolution for receptionists', () {
    final analysis = buildCallAnalysis({
      'type': 'receptionist',
      'qualification': {'questions': <dynamic>[]},
    });
    final schema = analysis['schema'] as Map<String, dynamic>;

    expect(schema['required'], ['resolved', 'reason']);
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
