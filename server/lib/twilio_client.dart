import 'dart:convert';

import 'package:http/http.dart' as http;

/// Finds and buys local US numbers. The Auth Token stays on the server.
class TwilioClient {
  TwilioClient({
    required this.accountSid,
    required this.authToken,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String accountSid;
  final String authToken;
  final http.Client _http;

  String get _base => 'https://api.twilio.com/2010-04-01/Accounts/$accountSid';

  /// A voice-capable local number that needs no address on file, in E.164
  /// form: in [areaCode] when given, otherwise anywhere in the US. Null when
  /// none are left; busy area codes like 415 and 212 often sell out.
  Future<String?> availableLocalNumber([String? areaCode]) async {
    final body = await _request(
      'GET',
      '/AvailablePhoneNumbers/US/Local.json',
      query: {
        'AreaCode': ?areaCode,
        'VoiceEnabled': 'true',
        'ExcludeAllAddressRequired': 'true',
        'PageSize': '1',
      },
    );
    final numbers = body['available_phone_numbers'] as List? ?? const [];
    if (numbers.isEmpty) return null;
    return (numbers.first as Map)['phone_number'] as String?;
  }

  /// Buys [phoneNumber]. Each number bills monthly until it's released in the
  /// Twilio Console.
  Future<Map<String, dynamic>> buyNumber(
    String phoneNumber, {
    required String friendlyName,
  }) => _request(
    'POST',
    '/IncomingPhoneNumbers.json',
    form: {'PhoneNumber': phoneNumber, 'FriendlyName': friendlyName},
  );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? form,
  }) async {
    final credentials = base64Encode(utf8.encode('$accountSid:$authToken'));
    final request =
        http.Request(
            method,
            Uri.parse('$_base$path').replace(queryParameters: query),
          )
          ..headers['Authorization'] = 'Basic $credentials'
          ..headers['Accept'] = 'application/json';
    if (form != null) request.bodyFields = form;
    final streamed = await _http
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Twilio returned ${response.statusCode}.';
      int? code;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message'] as String? ?? message;
        code = body['code'] as int?;
      } on Object {
        // Keep the status-based message when the response is not JSON.
      }
      throw TwilioException(message, response.statusCode, code);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

class TwilioException implements Exception {
  const TwilioException(this.message, this.statusCode, [this.code]);
  final String message;
  final int statusCode;

  /// Twilio's error code, e.g. 21422 when a number is no longer available.
  final int? code;

  @override
  String toString() => message;
}
