import 'dart:convert';

import 'package:libredb_mobile/core/logging/app_logger.dart';

/// Pure token / role utility functions.
///
/// Intentionally has no I/O dependencies: callers (e.g. [SessionCubit])
/// own the secure-storage read and hand the token here as a String. This
/// keeps `core/` free of `infrastructure/` imports per the architecture
/// guard, and makes every function trivially testable.
class SecurityUtils {
  static final _log = AppLogger.getLogger("SecurityUtils");

  /// True when [token] is non-null and non-empty.
  static bool hasToken(String? token) {
    return token != null && token.isNotEmpty;
  }

  /// Decode a JWT token and return the expiration time as [DateTime].
  ///
  /// Returns null if the token is invalid or does not contain an `exp` claim.
  static DateTime? getTokenExpiration(String token) {
    _log.trace("BEGIN:getTokenExpiration");
    try {
      final parts = token.split(".");
      if (parts.length != 3) return null;

      var payload = parts[1];
      if (payload.length % 4 != 0) {
        payload += '=' * (4 - payload.length % 4);
      }
      final decoded = String.fromCharCodes(base64Url.decode(payload));
      final payloadMap = json.decode(decoded) as Map<String, dynamic>;
      final exp = payloadMap["exp"];
      if (exp == null) return null;

      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (e) {
      // The text of a parse error quotes the part of the token it failed on, so only the type of the error is logged.
      _log.error("END:getTokenExpiration - Error: {}", [e.runtimeType]);
      return null;
    }
  }
}
