String buildLeadQualificationPrompt(
  Map<String, dynamic> agent, {
  List<String> webpageContents = const [],
}) {
  final friendliness = agent['friendliness'] as String? ?? 'friendly';
  final knowledge = (agent['knowledgeSources'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((source) => source['kind'] == 'shortAnswer')
      .map((source) => 'Q: ${source['content']}\nA: ${source['answer'] ?? ''}')
      .join('\n\n');
  final pages = webpageContents.isEmpty
      ? ''
      : '\n\nVERIFIED WEBPAGE CONTENT\n${webpageContents.join('\n\n---\n\n')}';
  final tools = <String>[
    if (agent['createContactEnabled'] == true)
      '- Use create_contact only after reading the caller’s email and phone back to them for confirmation.',
    if (agent['bookMeetingEnabled'] == true)
      '- Use get_meeting_slots before offering exactly two specific options, then use book_meeting only after the caller chooses one.',
  ].join('\n');

  final behavior = agent['type'] == 'receptionist'
      ? _receptionistBehavior
      : agent['qualifyLeadsEnabled'] == false
      ? _discoveryBehavior
      : _qualificationBehavior(agent);

  return '''
You are ${agent['name']}, ${agent['persona']} for ${agent['companyName']}.

COMPANY
${agent['companyDescription']}

VOICE AND STYLE
- Sound $friendliness, calm, concise, and conversational.
- Keep turns short. Ask one question at a time and allow interruptions.
- Avoid filler phrases, scripts, and repeated wording.
- If asked whether you are a bot, say yes plainly.
- Never claim an action succeeded unless its tool returned success.

$behavior

AVAILABLE ACTIONS
$tools

USER GUIDELINES — THESE OVERRIDE DEFAULT BEHAVIOR
${agent['guidelines']}

VERIFIED SHORT ANSWERS
$knowledge$pages

Only answer business-specific questions from the verified material above. If the answer is missing, say you do not know and offer to capture the question for follow-up.
'''
      .trim();
}

/// The Vapi structured output that judges each call. Lead qualification
/// agents also get a lead verdict checked against the user's own rules.
Map<String, dynamic> buildCallAnalysis(Map<String, dynamic> agent) {
  const resolution = {
    'resolved': {
      'type': 'boolean',
      'description': 'Whether the caller completed their main goal.',
    },
    'reason': {
      'type': 'string',
      'description': 'A concise reason for the resolution decision.',
    },
  };
  const description =
      'Determine whether the caller achieved their goal. Tool failures, requests for a human, and calls ending mid-task are unresolved.';
  final setup = _setup(agent);
  if (agent['type'] == 'receptionist' ||
      agent['qualifyLeadsEnabled'] == false ||
      setup == null) {
    return {
      'name': 'Call resolution',
      'description': description,
      'schema': {
        'type': 'object',
        'properties': resolution,
        'required': ['resolved', 'reason'],
      },
    };
  }
  final questions = _questions(
    setup,
  ).map((question) => '- ${question.text}').join('\n');
  return {
    'name': 'Call analysis',
    'description':
        '''
$description

Also judge the caller as a sales lead.
${_criteria(setup)}

Questions the agent had to ask:
$questions'''
            .trim(),
    'schema': {
      'type': 'object',
      'properties': {
        ...resolution,
        'leadOutcome': {
          'type': 'string',
          'enum': ['qualified', 'followUp', 'notAFit'],
          'description':
              'qualified: meets every rule. notAFit: a not-a-fit reason applies or a rule clearly fails. followUp: anything else, including unanswered required questions.',
        },
        'leadReason': {
          'type': 'string',
          'description': 'One sentence explaining the lead outcome.',
        },
        'answers': {
          'type': 'array',
          'description':
              'One entry per question above, in order. Use "Not answered" when the caller never answered.',
          'items': {
            'type': 'object',
            'properties': {
              'question': {'type': 'string'},
              'answer': {'type': 'string'},
            },
            'required': ['question', 'answer'],
          },
        },
      },
      'required': [
        'resolved',
        'reason',
        'leadOutcome',
        'leadReason',
        'answers',
      ],
    },
  };
}

Map<String, dynamic>? _setup(Map<String, dynamic> agent) {
  final setup = agent['qualification'];
  return setup is Map ? setup.cast<String, dynamic>() : null;
}

String _text(Map<String, dynamic> setup, String key) =>
    (setup[key] as String? ?? '').trim();

List<({String text, bool required})> _questions(Map<String, dynamic> setup) => [
  for (final item in (setup['questions'] as List? ?? const []).whereType<Map>())
    if ((item['text'] as String? ?? '').trim().isNotEmpty)
      (
        text: (item['text'] as String).trim(),
        required: item['required'] != false,
      ),
];

const _fieldLabels = {
  'phone': 'phone number',
  'email': 'email',
  'company': 'company',
  'jobTitle': 'job title',
  'budget': 'budget range',
};

/// Shared by the call script and the post-call analysis so both apply the
/// same rules.
String _criteria(Map<String, dynamic> setup) {
  final ideal = _text(setup, 'idealCustomer');
  final budget = _text(setup, 'minimumBudget');
  final months = (setup['startWithinMonths'] as num?)?.toInt() ?? 0;
  final rules = [
    if (ideal.isNotEmpty) '- They match the ideal customer.',
    if (budget.isNotEmpty) '- Their budget is at least $budget.',
    if (months > 0)
      '- They want to start within $months ${months == 1 ? 'month' : 'months'}.',
    if (setup['requireDecisionMaker'] == true)
      '- They make the buying decision, or can bring the person who does to the meeting.',
  ];
  final notAFit = [
    for (final reason
        in (setup['disqualifiers'] as List? ?? const []).whereType<String>())
      if (reason.trim().isNotEmpty) '- ${reason.trim()}',
  ];
  return [
    if (ideal.isNotEmpty) 'IDEAL CUSTOMER\n$ideal',
    'QUALIFICATION RULES\nA caller is qualified only when every required question is answered and:\n'
        '${rules.isEmpty ? '- Their answers show a real need the company can help with.' : rules.join('\n')}',
    if (notAFit.isNotEmpty)
      'NOT A FIT — any of these means the caller is not a fit:\n${notAFit.join('\n')}',
  ].join('\n\n');
}

String _qualificationBehavior(Map<String, dynamic> agent) {
  final setup = _setup(agent);
  if (setup == null) return _leadQualificationBehavior;
  final questions = _questions(setup);
  final asks = questions.isEmpty
      ? '   - Their role, problem, timeline, and budget range.'
      : questions
            .map(
              (question) =>
                  '   - ${question.text}${question.required ? ' (required)' : ''}',
            )
            .join('\n');
  final minutes = (setup['meetingMinutes'] as num?)?.toInt() ?? 30;
  final qualified = agent['bookMeetingEnabled'] == true
      ? 'offer two specific times for a $minutes-minute meeting and book the one they choose.'
      : 'take a message and say someone will reach out to set up a $minutes-minute meeting.';
  final message = _text(setup, 'notAFitMessage');
  final collect = [
    'name',
    for (final field in (setup['collect'] as List? ?? const []))
      ?_fieldLabels[field],
  ];
  final details = collect.length == 1
      ? collect.single
      : '${collect.sublist(0, collect.length - 1).join(', ')} and ${collect.last}';
  return '''
LEAD QUALIFICATION BEHAVIOR
1. Learn why the caller reached out and ask whether they have about a minute.
2. Ask open discovery questions before explaining the product.
3. Work these questions into the conversation one at a time, in your own words:
$asks
4. Briefly acknowledge each answer before the next question.
5. Handle objections by acknowledging, asking one clarifying question, then responding.
6. Decide the outcome with the rules below. Never tell the caller they were scored or labeled.
7. Qualified: $qualified
8. Not a fit: thank them politely and do not book a meeting.${message.isEmpty ? '' : ' Share this with them: "$message"'}
9. Follow up, when a required question is unanswered or you are unsure: take a message and say someone will follow up.
10. Before ending, collect the caller's $details and read them back. When the create_contact action is available, save the contact with leadStatus Qualified, Nurture for follow up, or Disqualified for not a fit, and summarize their answers in notes.
11. There is no live human handoff. Offer to take a message or book a callback.

${_criteria(setup)}''';
}

const _receptionistBehavior = '''
RECEPTIONIST BEHAVIOR
1. Greet warmly, learn why the caller is calling, and help them directly.
2. Answer questions about services, prices, hours, and policies from the verified material only.
3. When the caller wants an appointment, offer two specific times and book the one they choose.
4. If you cannot help, take a message: name, callback number, and the reason for the call.
5. Before ending, confirm contact details and save the contact when that action is available.
6. There is no live human handoff. Offer to take a message or book a callback.''';

const _leadQualificationBehavior = '''
LEAD QUALIFICATION BEHAVIOR
1. Learn why the caller reached out and ask whether they have about a minute.
2. Ask open discovery questions before explaining the product.
3. Qualify naturally across role and decision power, problem, timeline, budget range, and current tool.
4. Briefly acknowledge each answer before the next question.
5. Handle objections by acknowledging, asking one clarifying question, then responding.
6. If qualified, offer two specific meeting times. If not, thank them and offer a relevant resource.
7. Before ending, confirm contact details and save the contact when that action is available.
8. There is no live human handoff. Offer to take a message or book a callback.''';

const _discoveryBehavior = '''
CALLER BEHAVIOR
1. Learn why the caller reached out and ask whether they have about a minute.
2. Ask open discovery questions before explaining the product.
3. Do not score, rate, or label the caller as qualified or unqualified.
4. Briefly acknowledge each answer before the next question.
5. Handle objections by acknowledging, asking one clarifying question, then responding.
6. When the caller is interested, offer two specific meeting times.
7. Before ending, confirm contact details and save the contact when that action is available.
8. There is no live human handoff. Offer to take a message or book a callback.''';
