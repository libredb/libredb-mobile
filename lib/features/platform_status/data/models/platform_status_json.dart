import 'dart:convert';

/// Reads Platform's `GET /api/health/live`.
final class PlatformStatusJson {
  const PlatformStatusJson._();

  /// Checks `{"status": "live"}` (libredb-platform `src/app/api/health/live/route.ts`). Throws a [FormatException]
  /// for any other answer, such as a captive portal's page or another server at the configured address.
  static void liveness(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['status'] != 'live') {
      throw const FormatException('The liveness answer is not a live LibreDB Platform');
    }
  }
}
