import 'dart:convert';

/// Reads Studio's answer to `POST /api/db/cancel` (`src/app/api/db/cancel/route.ts`): `{cancelled}`.
final class CancelAnswerJson {
  const CancelAnswerJson._();

  /// Whether the engine stopped the run; an answer without the flag throws a [FormatException].
  static bool cancelled(String body) {
    final json = jsonDecode(body);
    final cancelled = json is Map<String, dynamic> ? json['cancelled'] : null;
    return cancelled is bool ? cancelled : throw const FormatException('The cancel answer has no cancelled flag');
  }
}
