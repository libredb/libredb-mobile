import 'dart:convert';

/// Reads LibreDB Platform's answer to a grant `PUT`: `{"id": "<grant id>"}`.
final class GrantPutAnswerJson {
  const GrantPutAnswerJson._();

  /// The id of the grant Platform created or replaced; a [FormatException] when the body has no string `id`.
  static String read(String body) {
    final decoded = jsonDecode(body);
    final id = decoded is Map<String, dynamic> ? decoded['id'] : null;
    if (id is! String) throw const FormatException('The Platform grant answer has no string id');
    return id;
  }
}
