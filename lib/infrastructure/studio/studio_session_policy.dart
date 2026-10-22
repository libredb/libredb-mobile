import 'package:dio/dio.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';

/// The [SessionExpiredPredicate] of LibreDB Studio: a 401 whose body carries `AUTH_REQUIRED`, or no code at all.
///
/// Studio also answers 401 when a database refuses its credential (`AUTH_ERROR`) or a model provider refuses its key
/// (`LLM_AUTH`); the session is fine then, so a token refresh would not help and must not end it. A 401 without a code
/// is `GET /api/auth/me`'s `{"authenticated":false}`, which a refresh may fix.
bool isStudioSessionExpired(DioException error) {
  if (error.response?.statusCode != 401) return false;
  final code = ApiClient.errorCodeOf(error.response?.data);
  return code == null || code == studioSessionEndedCode;
}

/// The [SessionRefusedPredicate] of LibreDB Studio: a 401 `AUTH_REQUIRED` for a request sent again with a token the
/// identity provider has just issued.
///
/// A 401 without a code is not one: `GET /api/auth/me` answers `{"authenticated":false}` both for a refused token and
/// when Studio cannot reach the identity provider to check it, and a new session would not fix the second, so the
/// error reaches the caller and the session is kept.
bool isStudioSessionRefused(DioException error) =>
    error.response?.statusCode == 401 && ApiClient.errorCodeOf(error.response?.data) == studioSessionEndedCode;

/// The only error code by which Studio says that the session ended.
const studioSessionEndedCode = 'AUTH_REQUIRED';
