/// Merges records queued during calls into a workspace the app sent.
///
/// Contacts match an existing one by email or phone (by name when the record
/// has neither), so a repeat caller updates one CRM entry instead of adding
/// another. Meetings and calls are skipped when the app already has them.
void applyPending(
  Map<String, dynamic> workspace,
  Iterable<Map<String, dynamic>> items,
) {
  final contacts = [...?workspace['contacts'] as List?];
  final meetings = [...?workspace['meetings'] as List?];
  final calls = [...?workspace['calls'] as List?];
  // Queued contact id -> id of the existing contact it merged into.
  final mergedIds = <Object?, Object?>{};
  for (final item in items) {
    final record = Map<String, dynamic>.from(item['record'] as Map);
    switch (item['type']) {
      case 'contact':
        final index = contacts.indexWhere(
          (contact) => _sameContact(contact as Map, record),
        );
        if (index == -1) {
          contacts.insert(0, record);
          continue;
        }
        final existing = contacts[index] as Map;
        mergedIds[record['id']] = existing['id'];
        contacts[index] = {
          ...existing,
          for (final entry in record.entries)
            if (entry.value is String && (entry.value as String).isNotEmpty)
              entry.key: entry.value,
          'id': existing['id'],
          'leadSource': existing['leadSource'],
          'createdAt': existing['createdAt'],
        };
      case 'meeting':
        record['contactId'] =
            mergedIds[record['contactId']] ?? record['contactId'];
        final duplicate = meetings.cast<Map>().any(
          (meeting) =>
              meeting['id'] == record['id'] ||
              (meeting['contactId'] == record['contactId'] &&
                  meeting['startsAt'] == record['startsAt']),
        );
        if (!duplicate) meetings.insert(0, record);
      case 'call':
        if (!calls.cast<Map>().any((call) => call['id'] == record['id'])) {
          calls.add(record);
        }
    }
  }
  calls.sort(
    (a, b) => ((b as Map)['startedAt'] as String).compareTo(
      (a as Map)['startedAt'] as String,
    ),
  );
  workspace
    ..['contacts'] = contacts
    ..['meetings'] = meetings
    ..['calls'] = calls;
}

bool _sameContact(Map existing, Map record) {
  String field(Map contact, String key) =>
      (contact[key] as String? ?? '').trim().toLowerCase();
  for (final key in const ['email', 'phone']) {
    final value = field(record, key);
    if (value.isNotEmpty && field(existing, key) == value) return true;
  }
  final name = field(record, 'name');
  return field(record, 'email').isEmpty &&
      field(record, 'phone').isEmpty &&
      name.isNotEmpty &&
      field(existing, 'name') == name;
}
