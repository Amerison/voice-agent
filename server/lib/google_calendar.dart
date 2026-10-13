import 'dart:convert';

import 'package:http/http.dart' as http;

/// Books meetings on the business owner's primary Google Calendar. The client
/// secret and refresh tokens stay on the server.
class GoogleCalendarClient {
  GoogleCalendarClient({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final http.Client _http;

  /// Adding events, reading free/busy for availability, and the account email
  /// to show in the app.
  static const scopes = [
    'openid',
    'email',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.events.freebusy',
  ];

  final _accessTokens = <String, ({String token, DateTime expiresAt})>{};

  /// Google's consent page. `prompt=consent` makes Google return a refresh
  /// token even when this account connected before.
  Uri consentUrl(String state) =>
      Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'access_type': 'offline',
        'prompt': 'consent',
        'include_granted_scopes': 'true',
        'state': state,
      });

  /// Trades the code from the consent redirect for a long-lived refresh token.
  Future<({String refreshToken, String? email})> exchangeCode(
    String code,
  ) async {
    final body = await _token({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
    });
    final refreshToken = body['refresh_token'] as String?;
    if (refreshToken == null) {
      throw const GoogleCalendarException(
        'Google didn’t grant offline access. Try connecting again.',
        400,
      );
    }
    final granted = (body['scope'] as String? ?? '').split(' ');
    if (!granted.contains(scopes[2]) || !granted.contains(scopes[3])) {
      throw const GoogleCalendarException(
        'Allow both calendar permissions so I can check availability and '
        'add meetings.',
        400,
      );
    }
    _cache(refreshToken, body);
    return (
      refreshToken: refreshToken,
      email: _emailFromIdToken(body['id_token'] as String?),
    );
  }

  /// Busy ranges on the primary calendar between [from] and [to].
  Future<List<({DateTime start, DateTime end})>> busy(
    String refreshToken,
    DateTime from,
    DateTime to,
  ) async {
    final body = await _api(
      refreshToken,
      'POST',
      '/freeBusy',
      json: {
        'timeMin': from.toUtc().toIso8601String(),
        'timeMax': to.toUtc().toIso8601String(),
        'items': [
          {'id': 'primary'},
        ],
      },
    );
    final calendar =
        (body['calendars'] as Map?)?['primary'] as Map? ?? const {};
    if ((calendar['errors'] as List? ?? const []).isNotEmpty) {
      throw const GoogleCalendarException(
        'Google Calendar availability is unavailable right now.',
        502,
      );
    }
    return [
      for (final range in calendar['busy'] as List? ?? const [])
        (
          start: DateTime.parse((range as Map)['start'] as String),
          end: DateTime.parse(range['end'] as String),
        ),
    ];
  }

  /// Adds an event to the primary calendar and returns it.
  Future<Map<String, dynamic>> createEvent(
    String refreshToken, {
    required String summary,
    required String description,
    required DateTime start,
    required DateTime end,
  }) => _api(
    refreshToken,
    'POST',
    '/calendars/primary/events',
    json: {
      'summary': summary,
      'description': description,
      'start': {'dateTime': start.toUtc().toIso8601String()},
      'end': {'dateTime': end.toUtc().toIso8601String()},
      'reminders': {'useDefault': true},
    },
  );

  /// Revokes the grant so the app no longer appears in the account's
  /// third-party access list.
  Future<void> revoke(String refreshToken) async {
    _accessTokens.remove(refreshToken);
    await _http
        .post(
          Uri.https('oauth2.googleapis.com', '/revoke'),
          body: {'token': refreshToken},
        )
        .timeout(const Duration(seconds: 15));
  }

  Future<String> _accessToken(String refreshToken) async {
    final cached = _accessTokens[refreshToken];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.token;
    }
    final body = await _token({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    return _cache(refreshToken, body);
  }

  String _cache(String refreshToken, Map<String, dynamic> body) {
    final token = body['access_token'] as String;
    final seconds = (body['expires_in'] as num?)?.toInt() ?? 3600;
    _accessTokens[refreshToken] = (
      token: token,
      expiresAt: DateTime.now().add(Duration(seconds: seconds - 60)),
    );
    return token;
  }

  Future<Map<String, dynamic>> _token(Map<String, String> fields) async {
    final response = await _http
        .post(
          Uri.https('oauth2.googleapis.com', '/token'),
          body: {
            ...fields,
            'client_id': clientId,
            'client_secret': clientSecret,
          },
        )
        .timeout(const Duration(seconds: 15));
    final body = _decode(response);
    if (response.statusCode == 200) return body;
    final error = body['error'] as String?;
    throw GoogleCalendarException(
      body['error_description'] as String? ??
          error ??
          'Google returned ${response.statusCode}.',
      response.statusCode,
      revoked: error == 'invalid_grant',
    );
  }

  Future<Map<String, dynamic>> _api(
    String refreshToken,
    String method,
    String path, {
    Map<String, dynamic>? json,
  }) async {
    final request =
        http.Request(
            method,
            Uri.parse('https://www.googleapis.com/calendar/v3$path'),
          )
          ..headers['Authorization'] =
              'Bearer ${await _accessToken(refreshToken)}'
          ..headers['Content-Type'] = 'application/json';
    if (json != null) request.body = jsonEncode(json);
    final response = await http.Response.fromStream(
      await _http.send(request).timeout(const Duration(seconds: 15)),
    );
    final body = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final error = body['error'];
    throw GoogleCalendarException(
      (error is Map ? error['message'] as String? : null) ??
          'Google Calendar returned ${response.statusCode}.',
      response.statusCode,
      revoked: response.statusCode == 401,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      return <String, dynamic>{};
    }
  }

  /// The id token comes straight from Google's token endpoint over TLS, so
  /// its payload can be read without verifying the signature.
  String? _emailFromIdToken(String? idToken) {
    final parts = idToken?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return (payload as Map)['email'] as String?;
    } on Object {
      return null;
    }
  }
}

class GoogleCalendarException implements Exception {
  const GoogleCalendarException(
    this.message,
    this.statusCode, {
    this.revoked = false,
  });
  final String message;
  final int statusCode;

  /// The owner revoked access or the grant expired; they need to reconnect.
  final bool revoked;

  @override
  String toString() => message;
}
