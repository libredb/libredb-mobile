import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppException response(
    int status,
    String? code, {
    String? serverMessage,
    Duration? retryAfter,
    String? fixStatement,
  }) => switch (status) {
    400 => BadRequestException('body', statusCode: status, errorCode: code, serverMessage: serverMessage),
    401 || 403 => UnauthorizedException(
      'body',
      statusCode: status,
      errorCode: code,
      serverMessage: serverMessage,
      fixStatement: fixStatement,
    ),
    _ => FetchDataException(
      'body',
      statusCode: status,
      errorCode: code,
      serverMessage: serverMessage,
      retryAfter: retryAfter,
    ),
  };

  group('studioError maps each Studio code', () {
    final cases = <(int, String, Type, AppErrorCode)>[
      (401, 'AUTH_REQUIRED', AuthError, AppErrorCode.authInvalidAccessToken),
      (401, 'AUTH_ERROR', AuthError, AppErrorCode.studioDatabaseAuth),
      (403, 'AUTH_ERROR', AuthError, AppErrorCode.studioConnectionNotAvailable),
      (404, 'CONNECTION_NOT_FOUND', NotFoundError, AppErrorCode.studioConnectionNotAvailable),
      (403, 'PERMISSION_DENIED', AuthError, AppErrorCode.studioPermissionDenied),
      (403, 'CUSTOM_CONNECTIONS_DISABLED', AuthError, AppErrorCode.studioCustomConnectionsDisabled),
      (400, 'QUERY_ERROR', ValidationError, AppErrorCode.studioQueryError),
      (499, 'QUERY_CANCELLED', ServerError, AppErrorCode.studioQueryCancelled),
      (400, 'CONFIG_ERROR', ValidationError, AppErrorCode.studioConfigError),
      (504, 'TIMEOUT_ERROR', TimeoutError, AppErrorCode.studioTimeout),
      (503, 'CONNECTION_ERROR', ServerError, AppErrorCode.studioDatabaseUnreachable),
      (503, 'POOL_EXHAUSTED', ServerError, AppErrorCode.studioDatabaseUnreachable),
      (503, 'GOVERNANCE_UNAVAILABLE', ServerError, AppErrorCode.studioGovernanceUnavailable),
      (503, 'AUDIT_UNAVAILABLE', ServerError, AppErrorCode.studioGovernanceUnavailable),
      (503, 'IDENTITY_PROVIDER_UNAVAILABLE', ServerError, AppErrorCode.studioIdentityProviderUnavailable),
      // libredb-studio#1922: a verified token whose account Studio refuses.
      (403, 'BEARER_NO_ROLE', AuthError, AppErrorCode.studioAccountHasNoRole),
      (403, 'BEARER_NO_IDENTITY', AuthError, AppErrorCode.studioAccountHasNoIdentity),
      (409, 'TRANSACTION_NOT_OWNED', ValidationError, AppErrorCode.studioTransactionNotOwned),
      (409, 'TRANSACTION_CREDENTIAL_CHANGED', ServerError, AppErrorCode.studioTransactionCredentialChanged),
    ];

    for (final (status, code, type, appCode) in cases) {
      test('$status $code', () {
        final error = studioError(response(status, code));

        expect(error.runtimeType, type);
        expect(error.code, appCode.key);
      });
    }
  });

  test('a 429 is a RateLimitedError with the Retry-After delay', () {
    final error = studioError(response(429, 'RATE_LIMITED', retryAfter: const Duration(seconds: 12)));

    expect(
      error,
      isA<RateLimitedError>()
          .having((e) => e.code, 'code', AppErrorCode.studioRateLimited.key)
          .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 12)),
    );
  });

  test('a refused database credential carries the fixStatement Studio sent', () {
    final error = studioError(response(401, 'AUTH_ERROR', fixStatement: 'GRANT ROLE R TO USER U'));

    expect(
      error,
      isA<AuthError>()
          .having((e) => e.code, 'code', AppErrorCode.studioDatabaseAuth.key)
          .having((e) => e.fixStatement, 'fixStatement', 'GRANT ROLE R TO USER U'),
    );
  });

  test('a refused database credential without a fixStatement carries none', () {
    expect(
      studioError(response(401, 'AUTH_ERROR')),
      isA<AuthError>().having((e) => e.fixStatement, 'fixStatement', isNull),
    );
  });

  test('a 429 without a code is rate limited too', () {
    expect(studioError(response(429, null)), isA<RateLimitedError>());
  });

  test("the message is the server's words when it sent some, for the screen that shows them", () {
    final error = studioError(response(400, 'QUERY_ERROR', serverMessage: 'syntax error at or near "FORM"'));

    expect(error.message, 'syntax error at or near "FORM"');
  });

  test('the message falls back to the exception text', () {
    expect(studioError(response(400, 'QUERY_ERROR')).message, 'Invalid Request: body');
  });

  group('studioError without a known code falls back on the status', () {
    test('400 is a ValidationError', () {
      expect(studioError(response(400, null)), isA<ValidationError>().having((e) => e.code, 'code', isNull));
    });

    test('401 and 403 are AuthErrors', () {
      expect(studioError(response(401, null)), isA<AuthError>());
      expect(studioError(response(403, 'ORIGIN_MISMATCH')), isA<AuthError>());
    });

    test('404 is a NotFoundError', () {
      expect(studioError(response(404, null)), isA<NotFoundError>());
    });

    test('5xx is a ServerError', () {
      expect(studioError(response(500, 'INTERNAL_ERROR')), isA<ServerError>().having((e) => e.code, 'code', isNull));
    });
  });

  group('studioError for a failure without a response', () {
    test('an untrusted certificate keeps its code', () {
      expect(
        studioError(UntrustedCertificateException('bad cert')),
        isA<NetworkError>().having((e) => e.code, 'code', AppErrorCode.networkCertInvalid.key),
      );
    });

    test('a timeout is a TimeoutError', () {
      expect(studioError(FetchDataException('TimeoutException')), isA<TimeoutError>());
    });

    test('a dropped connection is a NetworkError', () {
      expect(studioError(FetchDataException('No Internet connection')), isA<NetworkError>());
    });

    test('an answer that does not have the documented shape is a ServerError', () {
      expect(
        studioError(const FormatException('no connections list')),
        isA<ServerError>().having((e) => e.code, 'code', AppErrorCode.studioUnreadableAnswer.key),
      );
    });

    test('anything else is an UnknownError', () {
      expect(studioError(StateError('x')), isA<UnknownError>());
    });
  });
}
