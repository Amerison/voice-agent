import 'dart:convert';

import 'package:http/http.dart' as http;

class VapiClient {
  VapiClient({required this.privateKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String privateKey;
  final http.Client _http;
  static const _base = 'https://api.vapi.ai';

  Future<Map<String, dynamic>> createAssistant(
    Map<String, dynamic> payload,
  ) async => await _request('POST', '/assistant', payload);

  Future<Map<String, dynamic>> updateAssistant(
    String id,
    Map<String, dynamic> payload,
  ) async => await _request('PATCH', '/assistant/$id', payload);

  Future<Map<String, dynamic>> createStructuredOutput(
    String assistantId,
  ) async => await _request('POST', '/structured-output', {
    'name': 'Call resolution',
    'type': 'ai',
    'description':
        'Determine whether the caller achieved their goal. Tool failures, requests for a human, and calls ending mid-task are unresolved.',
    'schema': {
      'type': 'object',
      'properties': {
        'resolved': {
          'type': 'boolean',
          'description': 'Whether the caller completed their main goal.',
        },
        'reason': {
          'type': 'string',
          'description': 'A concise reason for the resolution decision.',
        },
      },
      'required': ['resolved', 'reason'],
    },
    'assistantIds': [assistantId],
  });

  /// Buys a Vapi number. Free accounts get exactly one, so prefer
  /// [listNumbers] and [assignNumber] when the account already has it.
  Future<Map<String, dynamic>> provisionNumber({
    required String assistantId,
    required String areaCode,
  }) async => await _request('POST', '/phone-number', {
    'provider': 'vapi',
    'assistantId': assistantId,
    'numberDesiredAreaCode': areaCode,
  });

  Future<List<Map<String, dynamic>>> listNumbers() async =>
      (await _request('GET', '/phone-number') as List)
          .cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> assignNumber(
    String id,
    String assistantId,
  ) async => await _request('PATCH', '/phone-number/$id', {
    'assistantId': assistantId,
  });

  /// Read-only; listing calls costs no credits.
  Future<List<Map<String, dynamic>>> listCalls(String assistantId) async =>
      (await _request('GET', '/call?assistantId=$assistantId&limit=100')
              as List)
          .cast<Map<String, dynamic>>();

  Future<dynamic> _request(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final request = http.Request(method, Uri.parse('$_base$path'))
      ..headers.addAll({
        'Authorization': 'Bearer $privateKey',
        'Content-Type': 'application/json',
      });
    if (payload != null) request.body = jsonEncode(payload);
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Vapi returned ${response.statusCode}.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message =
            body['message'] as String? ?? body['error'] as String? ?? message;
      } on Object {
        // Avoid returning untrusted HTML or credentials in error responses.
      }
      throw VapiException(message, response.statusCode);
    }
    return jsonDecode(response.body);
  }
}

class VapiException implements Exception {
  const VapiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
