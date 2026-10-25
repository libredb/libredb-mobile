import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppError', () {
    group('NetworkError', () {
      test('should create with message only', () {
        const error = NetworkError('No internet connection');
        expect(error.message, 'No internet connection');
        expect(error.code, isNull);
      });

      test('should create with message and code', () {
        const error = NetworkError('DNS failure', code: 'DNS_LOOKUP_FAILED');
        expect(error.message, 'DNS failure');
        expect(error.code, 'DNS_LOOKUP_FAILED');
      });

      test('should be an AppError', () {
        const error = NetworkError('test');
        expect(error, isA<AppError>());
      });

      // The message can be a database's error that quotes the statement, and the text of an error reaches the log and
      // Sentry.
      test('toString names the type and leaves the message out', () {
        const error = NetworkError('No internet');
        expect(error.toString(), 'NetworkError');
      });

      test('toString names the code when present and leaves the message out', () {
        const error = NetworkError('No internet', code: 'NET_ERR');
        expect(error.toString(), 'NetworkError(code: NET_ERR)');
      });
    });

    group('AuthError', () {
      test('should create with message', () {
        const error = AuthError('Unauthorized');
        expect(error.message, 'Unauthorized');
        expect(error.code, isNull);
      });

      test('should create with message and code', () {
        const error = AuthError('Token expired', code: '401');
        expect(error.message, 'Token expired');
        expect(error.code, '401');
      });

      test('should be an AppError', () {
        const error = AuthError('test');
        expect(error, isA<AppError>());
      });

      test('should compare the fixStatement', () {
        const statement = AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT R TO U');
        expect(statement, const AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT R TO U'));
        expect(
          statement.hashCode,
          const AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT R TO U').hashCode,
        );
        expect(
          statement,
          isNot(const AuthError('refused', code: 'studio.database_auth', fixStatement: 'GRANT S TO U')),
        );
        expect(statement, isNot(const AuthError('refused', code: 'studio.database_auth')));
      });
    });

    group('ValidationError', () {
      test('should create with message', () {
        const error = ValidationError('Invalid email');
        expect(error.message, 'Invalid email');
      });

      test('should be an AppError', () {
        const error = ValidationError('test');
        expect(error, isA<AppError>());
      });
    });

    group('ServerError', () {
      test('should create with message', () {
        const error = ServerError('Internal server error');
        expect(error.message, 'Internal server error');
      });

      test('should create with code', () {
        const error = ServerError('Server error', code: '500');
        expect(error.code, '500');
      });

      test('should be an AppError', () {
        const error = ServerError('test');
        expect(error, isA<AppError>());
      });
    });

    group('NotFoundError', () {
      test('should create with message', () {
        const error = NotFoundError('User not found');
        expect(error.message, 'User not found');
      });

      test('should be an AppError', () {
        const error = NotFoundError('test');
        expect(error, isA<AppError>());
      });
    });

    group('TimeoutError', () {
      test('should create with message', () {
        const error = TimeoutError('Request timed out');
        expect(error.message, 'Request timed out');
      });

      test('should be an AppError', () {
        const error = TimeoutError('test');
        expect(error, isA<AppError>());
      });
    });

    group('UnknownError', () {
      test('should create with message', () {
        const error = UnknownError('Something went wrong');
        expect(error.message, 'Something went wrong');
      });

      test('should be an AppError', () {
        const error = UnknownError('test');
        expect(error, isA<AppError>());
      });
    });

    group('equality', () {
      test('errors of different types are not equal, even with the same message and code', () {
        expect(const NetworkError('x', code: 'c'), isNot(const ServerError('x', code: 'c')));
        expect(const ServerError('x', code: 'c'), isNot(const NetworkError('x', code: 'c')));
        expect(const UnknownError('x'), isNot(const NotFoundError('x')));
        expect(const NetworkError('x', code: 'c'), const NetworkError('x', code: 'c'));
      });

      test('RateLimitedError compares the retryAfter', () {
        const error = RateLimitedError('x', code: 'studio.rate_limited', retryAfter: Duration(seconds: 2));
        const same = RateLimitedError('x', code: 'studio.rate_limited', retryAfter: Duration(seconds: 2));
        expect(error, same);
        expect(error.hashCode, same.hashCode);
        expect(
          error,
          isNot(const RateLimitedError('x', code: 'studio.rate_limited', retryAfter: Duration(seconds: 30))),
        );
        expect(error, isNot(const RateLimitedError('x', code: 'studio.rate_limited')));
      });

      test('hashCode differs for the same message and code in a different type', () {
        expect(const NetworkError('x', code: 'c').hashCode, isNot(const ServerError('x', code: 'c').hashCode));
      });

      test('same type, same message, same code should be equal', () {
        const a = NetworkError('msg', code: 'c');
        const b = NetworkError('msg', code: 'c');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('same type, same message, no code should be equal', () {
        const a = ServerError('error');
        const b = ServerError('error');
        expect(a, equals(b));
      });

      test('same type, different message should not be equal', () {
        const a = NetworkError('msg1');
        const b = NetworkError('msg2');
        expect(a, isNot(equals(b)));
      });

      test('same type, same message, different code should not be equal', () {
        const a = NetworkError('msg', code: 'c1');
        const b = NetworkError('msg', code: 'c2');
        expect(a, isNot(equals(b)));
      });
    });

    group('pattern matching (sealed class)', () {
      test('should match NetworkError', () {
        const AppError error = NetworkError('test');
        final result = switch (error) {
          NetworkError() => 'network',
          AuthError() => 'auth',
          ValidationError() => 'validation',
          ServerError() => 'server',
          NotFoundError() => 'not_found',
          TimeoutError() => 'timeout',
          RateLimitedError() => 'rate_limited',
          RequestCancelledError() => 'cancelled',
          InterruptedError() => 'interrupted',
          UnknownError() => 'unknown',
        };
        expect(result, 'network');
      });

      test('should match AuthError', () {
        const AppError error = AuthError('test');
        final result = switch (error) {
          NetworkError() => 'network',
          AuthError() => 'auth',
          ValidationError() => 'validation',
          ServerError() => 'server',
          NotFoundError() => 'not_found',
          TimeoutError() => 'timeout',
          RateLimitedError() => 'rate_limited',
          RequestCancelledError() => 'cancelled',
          InterruptedError() => 'interrupted',
          UnknownError() => 'unknown',
        };
        expect(result, 'auth');
      });

      test('should match ServerError', () {
        const AppError error = ServerError('test');
        final result = switch (error) {
          NetworkError() => 'network',
          AuthError() => 'auth',
          ValidationError() => 'validation',
          ServerError() => 'server',
          NotFoundError() => 'not_found',
          TimeoutError() => 'timeout',
          RateLimitedError() => 'rate_limited',
          RequestCancelledError() => 'cancelled',
          InterruptedError() => 'interrupted',
          UnknownError() => 'unknown',
        };
        expect(result, 'server');
      });

      test('should match all subclasses exhaustively', () {
        final errors = <AppError>[
          const NetworkError('n'),
          const AuthError('a'),
          const ValidationError('v'),
          const ServerError('s'),
          const NotFoundError('nf'),
          const TimeoutError('t'),
          const RateLimitedError('r'),
          const RequestCancelledError('c'),
          const InterruptedError('i', code: 'editor.page_interrupted'),
          const UnknownError('u'),
        ];

        final results = errors
            .map(
              (error) => switch (error) {
                NetworkError() => 'network',
                AuthError() => 'auth',
                ValidationError() => 'validation',
                ServerError() => 'server',
                NotFoundError() => 'not_found',
                TimeoutError() => 'timeout',
                RateLimitedError() => 'rate_limited',
                RequestCancelledError() => 'cancelled',
                InterruptedError() => 'interrupted',
                UnknownError() => 'unknown',
              },
            )
            .toList();

        expect(results, [
          'network',
          'auth',
          'validation',
          'server',
          'not_found',
          'timeout',
          'rate_limited',
          'cancelled',
          'interrupted',
          'unknown',
        ]);
      });
    });
  });

  // The `statement` scrubber key makes fixStatement a credential field, so its text must leave it out.
  group('AuthError text', () {
    test('is the type and the code, as every AppError prints, without the fixStatement', () {
      const error = AuthError('refused', code: 'studio.credential_refused', fixStatement: 'GRANT SELECT ON t TO app');

      expect('$error', 'AuthError(code: studio.credential_refused)');
      expect('$error', isNot(contains('GRANT')));
    });

    test('is the type alone without a code', () {
      expect('${const AuthError('refused', fixStatement: 'GRANT SELECT ON t TO app')}', 'AuthError');
    });
  });
}
