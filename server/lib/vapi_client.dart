import 'dart:convert';

import 'package:http/http.dart' as http;

class VapiClient {
  VapiClient({required this.privateKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String privateKey;
  final http.Client _http;
  static const _base = 'https://api.vapi.ai';

  Future<Map<String, dynamic>> createAssistant(Map<String, dynamic> payload) =>
      _request('POST', '/assistant', payload);

  Future<Map<String, dynamic>> updateAssistant(
    String id,
    Map<String, dynamic> payload,
  ) => _request('PATCH', '/assistant/$id', payload);

  Future<Map<String, dynamic>> createStructuredOutput(
    String assistantId,
  ) => _request('POST', '/structured-output', {
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

  Future<Map<String, dynamic>> provisionNumber({
    required String assistantId,
    required String areaCode,
  }) => _request('POST', '/phone-number', {
    'provider': 'vapi',
    'assistantId': assistantId,
    'areaCode': areaCode,
  });

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final request = http.Request(method, Uri.parse('$_base$path'))
      ..headers.addAll({
        'Authorization': 'Bearer $privateKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(payload);
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
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class VapiException implements Exception {
  const VapiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
