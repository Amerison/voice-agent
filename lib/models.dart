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
    required this.syncStatus,
    this.voice = 'Elliot',
    this.calendarConnected = false,
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
  final SyncStatus syncStatus;

  /// Vapi built-in voice id.
  final String voice;
  final bool calendarConnected;

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
    SyncStatus? syncStatus,
    String? voice,
    bool? calendarConnected,
    String? reservedNumber,
    String? phoneNumber,
    String? vapiAssistantId,
    String? vapiPhoneNumberId,
    String? vapiStructuredOutputId,
    DateTime? lastSyncedAt,
    String? syncError,
    bool clearSyncError = false,
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
    syncStatus: syncStatus ?? this.syncStatus,
    voice: voice ?? this.voice,
    calendarConnected: calendarConnected ?? this.calendarConnected,
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
    'syncStatus': syncStatus.name,
    'voice': voice,
    'calendarConnected': calendarConnected,
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
    bookMeetingEnabled: json['bookMeetingEnabled'] as bool? ?? false,
    createContactEnabled: json['createContactEnabled'] as bool? ?? true,
    syncStatus: SyncStatus.values.byName(
      json['syncStatus'] as String? ?? 'draft',
    ),
    voice: json['voice'] as String? ?? 'Elliot',
    calendarConnected: json['calendarConnected'] as bool? ?? false,
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
  });

  final String id;
  final DateTime startedAt;
  final int durationSeconds;
  final String callerNumber;
  final bool resolved;
  final String resolutionReason;
  final List<TranscriptMessage> transcript;
  final List<String> actions;
  final String endedReason;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'callerNumber': callerNumber,
    'resolved': resolved,
    'resolutionReason': resolutionReason,
    'transcript': transcript.map((item) => item.toJson()).toList(),
    'actions': actions,
    'endedReason': endedReason,
  };

  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    durationSeconds: (json['durationSeconds'] as num?)?.round() ?? 0,
    callerNumber: json['callerNumber'] as String? ?? 'Unknown caller',
    resolved: json['resolved'] as bool? ?? false,
    resolutionReason: json['resolutionReason'] as String? ?? 'Not analyzed',
    transcript: ((json['transcript'] as List?) ?? const [])
        .map((item) => TranscriptMessage.fromJson(item as Map<String, dynamic>))
        .toList(),
    actions: ((json['actions'] as List?) ?? const []).cast<String>(),
    endedReason: json['endedReason'] as String? ?? 'unknown',
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
