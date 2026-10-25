import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// The server an `ApiClient` talks to: its base URL, the pins of its host, and how its error bodies read.
///
/// LibreDB Studio and LibreDB Platform each get their own client, so a request never reaches the other server and an
/// error body is never read with the other server's envelope.
final class ApiTarget {
  const ApiTarget({this.baseUrl, this.certificatePins = const <String>[], required this.envelope});

  /// LibreDB Studio, the app's backend: `PROD_API_URL` and `STUDIO_CERT_PINS` of [config].
  factory ApiTarget.studio(AppConfig config) => ApiTarget(
    baseUrl: config.apiBaseUrl,
    certificatePins: config.certificatePins,
    envelope: const StudioErrorEnvelope(),
  );

  /// The base URL every path is relative to; null only outside prod, where `MockInterceptor` answers.
  final String? baseUrl;

  /// The pins of the host of [baseUrl]; empty leaves that host on the system trust store.
  final List<String> certificatePins;

  /// How the server's error bodies read.
  final ErrorEnvelope envelope;
}

/// How a server's error body reads: its machine-readable code, and the text an exception may carry.
///
/// [codeOf] and [fieldErrorKeysOf] read the raw body, before it is scrubbed, because a code or a field name holds no
/// request data. [exceptionText] builds the text from the scrubbed body, and that text reaches the log, the dev console
/// and, for an uncaught error, Sentry.
sealed class ErrorEnvelope {
  const ErrorEnvelope();

  /// The code of [data], a raw body given as a decoded map or as text, or null when it carries none.
  String? codeOf(Object? data);

  /// The keys of the field errors of [data], a raw body, in the order the server sent them; empty when it has none.
  List<String> fieldErrorKeysOf(Object? data);

  /// The text of the exception for an answer with [status] and the raw body [data], whose scrubbed text is
  /// [scrubbedBody].
  String exceptionText({required int status, required Object? data, required String scrubbedBody});

  /// The server's own words of [scrubbedBody], for a screen whose purpose is to show them, or null.
  String? serverMessageOf(String scrubbedBody);

  /// A statement that fixes the refusal, from [scrubbedBody], or null.
  String? fixStatementOf(String scrubbedBody);

  /// The JSON value of [data], given as a decoded value or as text, or null for text that is not JSON.
  static Object? decode(Object? data) {
    if (data is! String) return data;
    try {
      return jsonDecode(data);
    } on FormatException {
      return null;
    }
  }
}

/// LibreDB Studio's error body: a top-level `code`, the database's own words in a string `error`, and `details` and
/// `fixStatement` (`src/lib/api/error-body.ts` in Studio).
final class StudioErrorEnvelope extends ErrorEnvelope {
  const StudioErrorEnvelope();

  /// The members of a JSON error body that LibreDB Studio fills with a database's own words and with statements:
  /// `error` (the database's message, which can quote the statement), `details` (its `detail` and the error's position)
  /// and `fixStatement` (`src/lib/api/error-body.ts` in Studio).
  static const _databaseTextMembers = {'error', 'details', 'fixStatement'};

  /// The string `code` of a JSON object body. A code names a kind of failure and holds no request data, so it is read
  /// before the body is scrubbed.
  @override
  String? codeOf(Object? data) {
    final decoded = ErrorEnvelope.decode(data);
    return decoded is Map && decoded['code'] is String ? decoded['code'] as String : null;
  }

  /// Studio sends no field errors.
  @override
  List<String> fieldErrorKeysOf(Object? data) => const <String>[];

  /// The scrubbed body text without its [_databaseTextMembers] when it is a JSON object: no scrubber can tell a
  /// database's words or a statement from other text. [serverMessageOf] and [fixStatementOf] keep what a screen shows.
  /// Any other body is returned as it is.
  @override
  String exceptionText({required int status, required Object? data, required String scrubbedBody}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(scrubbedBody);
    } on FormatException {
      return scrubbedBody;
    }
    if (decoded is! Map || !decoded.keys.any(_databaseTextMembers.contains)) return scrubbedBody;
    return jsonEncode({
      for (final MapEntry(:key, :value) in decoded.entries)
        if (!_databaseTextMembers.contains(key)) key: value,
    });
  }

  @override
  String? serverMessageOf(String scrubbedBody) => _stringFieldOf(scrubbedBody, 'error');

  @override
  String? fixStatementOf(String scrubbedBody) => _stringFieldOf(scrubbedBody, 'fixStatement');

  /// The string [field] of the scrubbed body text [scrubbedBody], when it is a JSON object.
  static String? _stringFieldOf(String scrubbedBody, String field) {
    final decoded = ErrorEnvelope.decode(scrubbedBody);
    return decoded is Map && decoded[field] is String ? decoded[field] as String : null;
  }
}

/// LibreDB Platform's error body, `{"error":{"code","message","fieldErrors"?}}` (libredb-platform
/// `src/shared/lib/bearer/api-v1-response.ts`).
///
/// Platform's `message` and the messages of `fieldErrors` can name a user, such as a Keycloak user that is disabled, so
/// neither ever reaches the exception text, a log line or a screen: the text carries only the status, the code and the
/// field keys, and there is no server message.
final class PlatformErrorEnvelope extends ErrorEnvelope {
  const PlatformErrorEnvelope();

  @override
  String? codeOf(Object? data) {
    final error = _errorOf(data);
    return error != null && error['code'] is String ? error['code'] as String : null;
  }

  /// The keys of `error.fieldErrors`: zod paths joined with `.`, `""` for the root and `body` for a body that is not a
  /// JSON object (libredb-platform `src/shared/lib/bearer/api-v1-input.ts`).
  @override
  List<String> fieldErrorKeysOf(Object? data) {
    final fieldErrors = _errorOf(data)?['fieldErrors'];
    if (fieldErrors is! Map) return const <String>[];
    return List.unmodifiable(fieldErrors.keys.whereType<String>());
  }

  @override
  String exceptionText({required int status, required Object? data, required String scrubbedBody}) {
    final code = codeOf(data);
    final keys = fieldErrorKeysOf(data);
    return [
      'Platform answered $status',
      code == null ? 'without a code' : 'with $code',
      if (keys.isNotEmpty) 'on fields ${jsonEncode(keys)}',
    ].join(' ');
  }

  @override
  String? serverMessageOf(String scrubbedBody) => null;

  @override
  String? fixStatementOf(String scrubbedBody) => null;

  static Map<Object?, Object?>? _errorOf(Object? data) {
    final decoded = ErrorEnvelope.decode(data);
    final error = decoded is Map ? decoded['error'] : null;
    return error is Map ? error : null;
  }
}
