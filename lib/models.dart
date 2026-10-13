enum Friendliness { professional, neutral, friendly }

enum KnowledgeKind { webpage, shortAnswer }

enum SyncStatus { draft, syncing, ready, failed }

enum AgentType {
  receptionist,
  leadQualification,
  customerSupport,
  outboundCalling;

  String get label => switch (this) {
    receptionist => 'AI receptionist',
    leadQualification => 'AI lead qualification',
    customerSupport => 'Customer support',
    outboundCalling => 'Outbound calling',
  };

  bool get isAvailable => this == receptionist || this == leadQualification;
}

/// Details the agent confirms before saving a lead. Name is always collected.
enum LeadField {
  phone('Phone number'),
  email('Email'),
  company('Company'),
  jobTitle('Job title'),
  budget('Budget range');

  const LeadField(this.label);

  final String label;
}

class QualifyingQuestion {
  const QualifyingQuestion({
    required this.id,
    required this.text,
    this.required = true,
  });

  final String id;
  final String text;
  final bool required;

  QualifyingQuestion copyWith({String? text, bool? required}) =>
      QualifyingQuestion(
        id: id,
        text: text ?? this.text,
        required: required ?? this.required,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'required': required,
  };

  factory QualifyingQuestion.fromJson(Map<String, dynamic> json) =>
      QualifyingQuestion(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        required: json['required'] as bool? ?? true,
      );
}

/// What a lead qualification agent asks, how it decides who's a fit, and
/// what it does with each kind of caller.
class LeadQualification {
  const LeadQualification({
    this.idealCustomer = '',
    this.questions = defaultQuestions,
    this.minimumBudget = '',
    this.startWithinMonths = 0,
    this.requireDecisionMaker = false,
    this.disqualifiers = defaultDisqualifiers,
    this.meetingMinutes = 30,
    this.notAFitMessage = '',
    this.collect = const {LeadField.phone, LeadField.email},
  });

  static const defaultQuestions = [
    QualifyingQuestion(
      id: 'need',
      text: 'What problem are you hoping to solve?',
    ),
    QualifyingQuestion(
      id: 'timeline',
      text: 'When are you hoping to get started?',
    ),
    QualifyingQuestion(
      id: 'budget',
      text: 'What budget range do you have in mind?',
    ),
    QualifyingQuestion(
      id: 'authority',
      text: 'Who else is involved in the decision?',
      required: false,
    ),
  ];

  static const defaultDisqualifiers = [
    'Looking for a job',
    'Selling a product or service to us',
  ];

  final String idealCustomer;
  final List<QualifyingQuestion> questions;
  final String minimumBudget;

  /// 0 means any timeline is fine.
  final int startWithinMonths;
  final bool requireDecisionMaker;
  final List<String> disqualifiers;
  final int meetingMinutes;

  /// Said to callers who aren't a fit, such as a link to a guide.
  final String notAFitMessage;
  final Set<LeadField> collect;

  LeadQualification copyWith({
    String? idealCustomer,
    List<QualifyingQuestion>? questions,
    String? minimumBudget,
    int? startWithinMonths,
    bool? requireDecisionMaker,
    List<String>? disqualifiers,
    int? meetingMinutes,
    String? notAFitMessage,
    Set<LeadField>? collect,
  }) => LeadQualification(
    idealCustomer: idealCustomer ?? this.idealCustomer,
    questions: questions ?? this.questions,
    minimumBudget: minimumBudget ?? this.minimumBudget,
    startWithinMonths: startWithinMonths ?? this.startWithinMonths,
    requireDecisionMaker: requireDecisionMaker ?? this.requireDecisionMaker,
    disqualifiers: disqualifiers ?? this.disqualifiers,
    meetingMinutes: meetingMinutes ?? this.meetingMinutes,
    notAFitMessage: notAFitMessage ?? this.notAFitMessage,
    collect: collect ?? this.collect,
  );

  Map<String, dynamic> toJson() => {
    'idealCustomer': idealCustomer,
    'questions': questions.map((item) => item.toJson()).toList(),
    'minimumBudget': minimumBudget,
    'startWithinMonths': startWithinMonths,
    'requireDecisionMaker': requireDecisionMaker,
    'disqualifiers': disqualifiers,
    'meetingMinutes': meetingMinutes,
    'notAFitMessage': notAFitMessage,
    'collect': [
      for (final field in LeadField.values)
        if (collect.contains(field)) field.name,
    ],
  };

  factory LeadQualification.fromJson(Map<String, dynamic> json) =>
      LeadQualification(
        idealCustomer: json['idealCustomer'] as String? ?? '',
        questions: json['questions'] is List
            ? (json['questions'] as List)
                  .map(
                    (item) => QualifyingQuestion.fromJson(
                      item as Map<String, dynamic>,
                    ),
                  )
                  .toList()
            : defaultQuestions,
        minimumBudget: json['minimumBudget'] as String? ?? '',
        startWithinMonths: (json['startWithinMonths'] as num?)?.toInt() ?? 0,
        requireDecisionMaker: json['requireDecisionMaker'] as bool? ?? false,
        disqualifiers: json['disqualifiers'] is List
            ? (json['disqualifiers'] as List).cast<String>()
            : defaultDisqualifiers,
        meetingMinutes: (json['meetingMinutes'] as num?)?.toInt() ?? 30,
        notAFitMessage: json['notAFitMessage'] as String? ?? '',
        collect: json['collect'] is List
            ? {
                for (final name in (json['collect'] as List).cast<String>())
                  ?LeadField.values.asNameMap()[name],
              }
            : const {LeadField.phone, LeadField.email},
      );
}

class KnowledgeSource {
  const KnowledgeSource({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    this.answer,
  });

  final String id;
  final KnowledgeKind kind;
  final String title;
  final String content;
  final String? answer;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'content': content,
    'answer': answer,
  };

  factory KnowledgeSource.fromJson(Map<String, dynamic> json) =>
      KnowledgeSource(
        id: json['id'] as String,
        kind: KnowledgeKind.values.byName(json['kind'] as String),
        title: json['title'] as String,
        content: json['content'] as String,
        answer: json['answer'] as String?,
      );
}

/// Vapi retired these voices; saved agents move to the closest active one.
const _retiredVoices = {'Paige': 'Clara', 'Kylie': 'Savannah', 'Cole': 'Kai'};

String _activeVoice(String? voice) {
  final id = voice == null || voice.isEmpty ? 'Elliot' : voice;
  return _retiredVoices[id] ?? id;
}

class AgentConfig {
  const AgentConfig({
    required this.id,
    this.type = AgentType.leadQualification,
    required this.name,
    required this.friendliness,
    required this.persona,
    required this.companyName,
    required this.companyDescription,
    required this.greeting,
    required this.guidelines,
    required this.knowledgeSources,
    required this.bookMeetingEnabled,
    required this.createContactEnabled,
    this.qualifyLeadsEnabled = true,
    this.qualification = const LeadQualification(),
    required this.syncStatus,
    this.voice = 'Elliot',
    this.calendarConnected = false,
    this.calendarEmail,
    this.reservedNumber,
    this.phoneNumber,
    this.vapiAssistantId,
    this.vapiPhoneNumberId,
    this.vapiStructuredOutputId,
    this.lastSyncedAt,
    this.syncError,
  });

  final String id;
  final AgentType type;
  final String name;
  final Friendliness friendliness;
  final String persona;
  final String companyName;
  final String companyDescription;
  final String greeting;
  final String guidelines;
  final List<KnowledgeSource> knowledgeSources;
  final bool bookMeetingEnabled;
  final bool createContactEnabled;

  /// Off hides qualified leads from reports and stops the agent tagging them.
  final bool qualifyLeadsEnabled;
  final LeadQualification qualification;
  final SyncStatus syncStatus;

  /// Vapi built-in voice id.
  final String voice;
  final bool calendarConnected;

  /// The Google account meetings are booked on, once connected.
  final String? calendarEmail;

  /// Mock number shown during onboarding until a real one is provisioned.
  final String? reservedNumber;
  final String? phoneNumber;
  final String? vapiAssistantId;
  final String? vapiPhoneNumberId;
  final String? vapiStructuredOutputId;
  final DateTime? lastSyncedAt;
  final String? syncError;

  AgentConfig copyWith({
    AgentType? type,
    String? name,
    Friendliness? friendliness,
    String? persona,
    String? companyName,
    String? companyDescription,
    String? greeting,
    String? guidelines,
    List<KnowledgeSource>? knowledgeSources,
    bool? bookMeetingEnabled,
    bool? createContactEnabled,
    bool? qualifyLeadsEnabled,
    LeadQualification? qualification,
    SyncStatus? syncStatus,
    String? voice,
    bool? calendarConnected,
    String? calendarEmail,
    String? reservedNumber,
    String? phoneNumber,
    String? vapiAssistantId,
    String? vapiPhoneNumberId,
    String? vapiStructuredOutputId,
    DateTime? lastSyncedAt,
    String? syncError,
    bool clearSyncError = false,
    bool clearCalendarEmail = false,
  }) => AgentConfig(
    id: id,
    type: type ?? this.type,
    name: name ?? this.name,
    friendliness: friendliness ?? this.friendliness,
    persona: persona ?? this.persona,
    companyName: companyName ?? this.companyName,
    companyDescription: companyDescription ?? this.companyDescription,
    greeting: greeting ?? this.greeting,
    guidelines: guidelines ?? this.guidelines,
    knowledgeSources: knowledgeSources ?? this.knowledgeSources,
    bookMeetingEnabled: bookMeetingEnabled ?? this.bookMeetingEnabled,
    createContactEnabled: createContactEnabled ?? this.createContactEnabled,
    qualifyLeadsEnabled: qualifyLeadsEnabled ?? this.qualifyLeadsEnabled,
    qualification: qualification ?? this.qualification,
    syncStatus: syncStatus ?? this.syncStatus,
    voice: voice ?? this.voice,
    calendarConnected: calendarConnected ?? this.calendarConnected,
    calendarEmail: clearCalendarEmail
        ? null
        : calendarEmail ?? this.calendarEmail,
    reservedNumber: reservedNumber ?? this.reservedNumber,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    vapiAssistantId: vapiAssistantId ?? this.vapiAssistantId,
    vapiPhoneNumberId: vapiPhoneNumberId ?? this.vapiPhoneNumberId,
    vapiStructuredOutputId:
        vapiStructuredOutputId ?? this.vapiStructuredOutputId,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    syncError: clearSyncError ? null : syncError ?? this.syncError,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'friendliness': friendliness.name,
    'persona': persona,
    'companyName': companyName,
    'companyDescription': companyDescription,
    'greeting': greeting,
    'guidelines': guidelines,
    'knowledgeSources': knowledgeSources.map((item) => item.toJson()).toList(),
    'bookMeetingEnabled': bookMeetingEnabled,
    'createContactEnabled': createContactEnabled,
    'qualifyLeadsEnabled': qualifyLeadsEnabled,
    'qualification': qualification.toJson(),
    'syncStatus': syncStatus.name,
    'voice': voice,
    'calendarConnected': calendarConnected,
    'calendarEmail': calendarEmail,
    'reservedNumber': reservedNumber,
    'phoneNumber': phoneNumber,
    'vapiAssistantId': vapiAssistantId,
    'vapiPhoneNumberId': vapiPhoneNumberId,
    'vapiStructuredOutputId': vapiStructuredOutputId,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'syncError': syncError,
  };

  factory AgentConfig.fromJson(Map<String, dynamic> json) => AgentConfig(
    id: json['id'] as String,
    type:
        AgentType.values.asNameMap()[json['type'] as String?] ??
        AgentType.leadQualification,
    name: json['name'] as String,
    friendliness: Friendliness.values.byName(json['friendliness'] as String),
    persona: json['persona'] as String,
    companyName: json['companyName'] as String,
    companyDescription: json['companyDescription'] as String,
    greeting: json['greeting'] as String,
    guidelines: json['guidelines'] as String,
    knowledgeSources: ((json['knowledgeSources'] as List?) ?? const [])
        .map((item) => KnowledgeSource.fromJson(item as Map<String, dynamic>))
        .toList(),
    bookMeetingEnabled: json['bookMeetingEnabled'] as bool? ?? true,
    createContactEnabled: json['createContactEnabled'] as bool? ?? true,
    qualifyLeadsEnabled: json['qualifyLeadsEnabled'] as bool? ?? true,
    qualification: json['qualification'] is Map<String, dynamic>
        ? LeadQualification.fromJson(
            json['qualification'] as Map<String, dynamic>,
          )
        : const LeadQualification(),
    syncStatus: SyncStatus.values.byName(
      json['syncStatus'] as String? ?? 'draft',
    ),
    voice: _activeVoice(json['voice'] as String?),
    calendarConnected: json['calendarConnected'] as bool? ?? false,
    calendarEmail: json['calendarEmail'] as String?,
    reservedNumber: json['reservedNumber'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
    vapiAssistantId: json['vapiAssistantId'] as String?,
    vapiPhoneNumberId: json['vapiPhoneNumberId'] as String?,
    vapiStructuredOutputId: json['vapiStructuredOutputId'] as String?,
    lastSyncedAt: json['lastSyncedAt'] == null
        ? null
        : DateTime.parse(json['lastSyncedAt'] as String),
    syncError: json['syncError'] as String?,
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.company,
    required this.jobTitle,
    required this.leadSource,
    required this.leadStatus,
    required this.budgetRange,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String company;
  final String jobTitle;
  final String leadSource;
  final String leadStatus;
  final String budgetRange;
  final String notes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'company': company,
    'jobTitle': jobTitle,
    'leadSource': leadSource,
    'leadStatus': leadStatus,
    'budgetRange': budgetRange,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    company: json['company'] as String? ?? '',
    jobTitle: json['jobTitle'] as String? ?? '',
    leadSource: json['leadSource'] as String? ?? 'Inbound call',
    leadStatus: json['leadStatus'] as String? ?? 'New',
    budgetRange: json['budgetRange'] as String? ?? 'Not shared',
    notes: json['notes'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class Meeting {
  const Meeting({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.startsAt,
    required this.status,
  });

  final String id;
  final String contactId;
  final String contactName;
  final DateTime startsAt;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactId': contactId,
    'contactName': contactName,
    'startsAt': startsAt.toIso8601String(),
    'status': status,
  };

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    id: json['id'] as String,
    contactId: json['contactId'] as String,
    contactName: json['contactName'] as String? ?? 'Unknown caller',
    startsAt: DateTime.parse(json['startsAt'] as String),
    status: json['status'] as String? ?? 'Scheduled',
  );
}

class TranscriptMessage {
  const TranscriptMessage({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};

  factory TranscriptMessage.fromJson(Map<String, dynamic> json) =>
      TranscriptMessage(
        role: json['role'] as String,
        text: json['text'] as String? ?? json['message'] as String? ?? '',
      );
}

enum LeadOutcome {
  qualified('Qualified'),
  followUp('Follow up'),
  notAFit('Not a fit');

  const LeadOutcome(this.label);

  final String label;
}

/// Post-call verdict on a lead qualification call.
class LeadResult {
  const LeadResult({
    required this.outcome,
    required this.reason,
    this.answers = const [],
  });

  final LeadOutcome outcome;
  final String reason;
  final List<({String question, String answer})> answers;

  Map<String, dynamic> toJson() => {
    'outcome': outcome.name,
    'reason': reason,
    'answers': [
      for (final item in answers)
        {'question': item.question, 'answer': item.answer},
    ],
  };

  static LeadResult? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final outcome = LeadOutcome.values.asNameMap()[json['outcome']];
    if (outcome == null) return null;
    return LeadResult(
      outcome: outcome,
      reason: json['reason'] as String? ?? '',
      answers: [
        for (final item
            in (json['answers'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          (
            question: item['question']?.toString() ?? '',
            answer: item['answer']?.toString() ?? '',
          ),
      ],
    );
  }
}

class CallRecord {
  const CallRecord({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.callerNumber,
    required this.resolved,
    required this.resolutionReason,
    required this.transcript,
    required this.actions,
    required this.endedReason,
    this.isTest = false,
    this.lead,
  });

  final String id;
  final DateTime startedAt;
  final int durationSeconds;
  final String callerNumber;

  /// In-app voice tests; kept out of resolution stats.
  final bool isTest;
  final bool resolved;
  final String resolutionReason;
  final List<TranscriptMessage> transcript;
  final List<String> actions;
  final String endedReason;

  /// Null unless a lead qualification agent took the call.
  final LeadResult? lead;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'callerNumber': callerNumber,
    'isTest': isTest,
    'resolved': resolved,
    'resolutionReason': resolutionReason,
    'transcript': transcript.map((item) => item.toJson()).toList(),
    'actions': actions,
    'endedReason': endedReason,
    'lead': ?lead?.toJson(),
  };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    durationSeconds: (json['durationSeconds'] as num?)?.round() ?? 0,
    callerNumber: switch (json['callerNumber'] as String?) {
      null => 'Unknown caller',
      'Web test call' => 'Test Call',
      final caller => caller,
    },
    isTest:
        json['isTest'] as bool? ??
        const {'Web test call', 'Test Call'}.contains(json['callerNumber']),
    resolved: json['resolved'] as bool? ?? false,
    resolutionReason: json['resolutionReason'] as String? ?? 'Not analyzed',
    transcript: ((json['transcript'] as List?) ?? const [])
        .map((item) => TranscriptMessage.fromJson(item as Map<String, dynamic>))
        .toList(),
    actions: ((json['actions'] as List?) ?? const []).cast<String>(),
    endedReason: json['endedReason'] as String? ?? 'unknown',
    lead: LeadResult.fromJson(json['lead']),
  );
}

class WorkspaceData {
  const WorkspaceData({
    required this.onboardingComplete,
    required this.agent,
    required this.contacts,
    required this.meetings,
    required this.calls,
  });

  final bool onboardingComplete;
  final AgentConfig agent;
  final List<Contact> contacts;
  final List<Meeting> meetings;
  final List<CallRecord> calls;

  WorkspaceData copyWith({
    bool? onboardingComplete,
    AgentConfig? agent,
    List<Contact>? contacts,
    List<Meeting>? meetings,
    List<CallRecord>? calls,
  }) => WorkspaceData(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    agent: agent ?? this.agent,
    contacts: contacts ?? this.contacts,
    meetings: meetings ?? this.meetings,
    calls: calls ?? this.calls,
  );

  Map<String, dynamic> toJson() => {
    'onboardingComplete': onboardingComplete,
    'agent': agent.toJson(),
    'contacts': contacts.map((item) => item.toJson()).toList(),
    'meetings': meetings.map((item) => item.toJson()).toList(),
    'calls': calls.map((item) => item.toJson()).toList(),
  };

  factory WorkspaceData.fromJson(Map<String, dynamic> json) => WorkspaceData(
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    agent: AgentConfig.fromJson(json['agent'] as Map<String, dynamic>),
    contacts: ((json['contacts'] as List?) ?? const [])
        .map((item) => Contact.fromJson(item as Map<String, dynamic>))
        .toList(),
    meetings: ((json['meetings'] as List?) ?? const [])
        .map((item) => Meeting.fromJson(item as Map<String, dynamic>))
        .toList(),
    calls: ((json['calls'] as List?) ?? const [])
        .map((item) => CallRecord.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
