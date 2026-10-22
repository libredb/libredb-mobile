import 'dart:convert';

import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';

/// Reads Studio's `GET /api/health` and `GET /api/ready`.
final class StudioStatusJson {
  const StudioStatusJson._();

  /// Checks `{"status": "healthy", "timestamp": ..., "service": "libredb-studio"}` (libredb-studio
  /// `src/lib/api/liveness.ts`). Throws a [FormatException] for any other answer, such as a captive portal's page or
  /// another server at the configured address.
  static void liveness(String body) {
    final decoded = _object(body);
    if (decoded['status'] != 'healthy' || decoded['service'] != 'libredb-studio') {
      throw const FormatException('The liveness answer is not a healthy LibreDB Studio');
    }
  }

  /// Reads `{"status": ..., "contract": {...}, "detail"?: ...}`. Throws a [FormatException] for a missing or unknown
  /// status; a `detail` that is not a string is left out.
  static StudioReadiness readiness(String body) {
    final decoded = _object(body);
    final detail = decoded['detail'] is String ? decoded['detail'] as String : null;
    return switch (decoded['status']) {
      'ready' => const StudioReadinessReady(),
      'ok' => const StudioReadinessOk(),
      'degraded' => const StudioReadinessDegraded(),
      'loading' => const StudioReadinessLoading(),
      'misconfigured' => StudioReadinessMisconfigured(detail: detail),
      'incompatible' => StudioReadinessIncompatible(detail: detail),
      _ => throw const FormatException('The readiness answer has no known status'),
    };
  }

  static Map<String, dynamic> _object(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('The answer is not a JSON object');
    return decoded;
  }
}
