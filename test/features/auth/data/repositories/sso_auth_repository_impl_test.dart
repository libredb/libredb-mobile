import 'dart:io';

import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/sso_auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:libredb_mobile/infrastructure/auth/oidc/oidc_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:logger/logger.dart' show Logger, OutputEvent;

/// Answers [signIn] with the configured outcome.
class _FakeOidcClient implements IOidcClient {
  OidcSignInOutcome signInOutcome = const OidcSignInCancelled();

  @override
  Future<OidcSignInOutcome> signIn() async => signInOutcome;

  @override
  Future<TokenRotationResult> refresh({
    required String refreshToken,
    required String idToken,
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) => throw UnimplementedError('a sign-in never refreshes');

  @override
  Future<OidcLogoutOutcome> endProviderSession({String? idTokenHint}) =>
      throw UnimplementedError('a sign-in never logs out');
}

class _FakeAuthSessionRepository implements IAuthSessionRepository {
  Result<void>? persistResult;
  final persisted = <AuthSession>[];

  @override
  Future<Result<void>> persist(AuthSession session) async {
    persisted.add(session);
    return persistResult ?? const Success(null);
  }

  @override
  Future<Result<void>> clear() async => const Success(null);
}

final _expiresAt = DateTime.utc(2026, 10, 21, 12);

final _tokens = OidcTokens(
  accessToken: 'access-token',
  idToken: 'id-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: _expiresAt,
);

Map<String, Object?> _claims({Map<String, Object?> extra = const {}}) => {
  'iss': 'https://id.example.com/realms/demo',
  'sub': 'subject-1',
  ...extra,
};

void main() {
  late _FakeOidcClient client;
  late _FakeAuthSessionRepository sessions;
  late Directory temporary;
  late SsoAuthRepository repository;

  setUp(() {
    client = _FakeOidcClient();
    sessions = _FakeAuthSessionRepository();
    temporary = Directory.systemTemp.createTempSync('sso_share_files');
    repository = SsoAuthRepository(
      client: client,
      sessionRepository: sessions,
      shareFiles: TemporaryShareFiles(temporaryDirectory: () async => temporary),
    );
  });

  tearDown(() {
    if (temporary.existsSync()) temporary.deleteSync(recursive: true);
  });

  Future<SsoProviderSignIn> signInWith(Map<String, Object?> claims) {
    client.signInOutcome = OidcSignedIn(tokens: _tokens, claims: claims);
    return repository.signIn(target: SessionTarget.studio);
  }

  group('SsoAuthRepository.signIn', () {
    test('persists the session the tokens make', () async {
      final result = await signInWith(_claims(extra: {'email': 'user@example.com'}));

      expect(result, isA<SsoProviderSignedIn>());
      expect(sessions.persisted, hasLength(1));
      final session = sessions.persisted.single;
      expect(session.idToken, 'access-token');
      expect(session.refreshToken, 'refresh-token');
      expect(session.oidcIdToken, 'id-token');
      expect(session.accessTokenExpiresAt, _expiresAt);
      expect(session.target, SessionTarget.studio);
    });

    test('persists the target the sign-in was asked for', () async {
      client.signInOutcome = OidcSignedIn(tokens: _tokens, claims: _claims());

      expect(await repository.signIn(target: SessionTarget.platform), isA<SsoProviderSignedIn>());

      expect(sessions.persisted.single.target, SessionTarget.platform);
    });

    // A share the app was killed in, before a session that ended without the wipe (a restore that timed out, lost
    // tokens), left its file for the next account (#202).
    test('removes the files a share left before the new session is stored', () async {
      final left = await TemporaryShareFiles(temporaryDirectory: () async => temporary).write('a.sql', [1]);
      final copy = File('${temporary.path}/share_plus/a.sql')..createSync(recursive: true);

      final result = await signInWith(_claims());

      expect(result, isA<SsoProviderSignedIn>());
      expect(left.existsSync(), isFalse);
      expect(copy.existsSync(), isFalse);
    });

    test('refuses the sign-in and stores no session when the phone refuses to remove the share files', () async {
      repository = SsoAuthRepository(
        client: client,
        sessionRepository: sessions,
        shareFiles: TemporaryShareFiles(temporaryDirectory: () async => throw const FileSystemException('refused')),
      );

      final result = await signInWith(_claims());

      expect(result, const SsoProviderRejected(AppErrorCode.authShareFilesNotRemoved));
      expect(sessions.persisted, isEmpty);
    });

    // The role comes only from Studio's GET /api/auth/me, so a token's role claim is never read.
    for (final roles in [
      ['admin'],
      ['guest'],
      <String>[],
    ]) {
      test('signs in whatever the role claim holds ($roles)', () async {
        final result = await signInWith(
          _claims(
            extra: {
              'roles': roles,
              'realm_access': {'roles': roles},
            },
          ),
        );

        expect(result, isA<SsoProviderSignedIn>());
        expect(sessions.persisted, hasLength(1));
      });
    }

    test('persists no refresh token when the provider issued none', () async {
      client.signInOutcome = OidcSignedIn(
        tokens: OidcTokens(accessToken: 'access-token', idToken: 'id-token', accessTokenExpiresAt: _expiresAt),
        claims: _claims(),
      );

      expect(await repository.signIn(target: SessionTarget.studio), isA<SsoProviderSignedIn>());

      expect(sessions.persisted.single.refreshToken, isNull);
    });

    for (final (name, claims) in [
      ('no sub', {'iss': 'https://id.example.com/realms/demo'}),
      ('an empty sub', {'iss': 'https://id.example.com/realms/demo', 'sub': ''}),
      ('a sub that is not a string', {'iss': 'https://id.example.com/realms/demo', 'sub': 7}),
      ('no iss', {'sub': 'subject-1'}),
      ('an empty iss', {'iss': '', 'sub': 'subject-1'}),
      ('an iss that is not a string', {'iss': true, 'sub': 'subject-1'}),
    ]) {
      test('an ID token with $name is rejected and nothing is persisted', () async {
        final result = await signInWith(claims);

        expect(
          result,
          isA<SsoProviderRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authOidcNoClaims),
        );
        expect(sessions.persisted, isEmpty);
      });
    }

    test('a provider that could not be reached is rejected with the discovery code', () async {
      client.signInOutcome = const OidcSignInFailed(OidcFailure.discovery);

      final result = await repository.signIn(target: SessionTarget.studio);

      expect(
        result,
        isA<SsoProviderRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authOidcDiscovery),
      );
      expect(sessions.persisted, isEmpty);
    });

    test('a failed sign-in is rejected with the failed code', () async {
      client.signInOutcome = const OidcSignInFailed(OidcFailure.failed);

      final result = await repository.signIn(target: SessionTarget.studio);

      expect(result, isA<SsoProviderRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authOidcFailed));
      expect(sessions.persisted, isEmpty);
    });

    test('a discovery naming an endpoint that is not https is rejected with the configuration code', () async {
      client.signInOutcome = const OidcSignInFailed(OidcFailure.insecureEndpoint);

      final result = await repository.signIn(target: SessionTarget.studio);

      expect(result, isA<SsoProviderRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authOidcConfig));
      expect(sessions.persisted, isEmpty);
    });

    test('a provider certificate that matches no pin is rejected with the certificate code', () async {
      client.signInOutcome = const OidcSignInFailed(OidcFailure.untrustedCertificate);

      final result = await repository.signIn(target: SessionTarget.studio);

      expect(
        result,
        isA<SsoProviderRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.networkCertInvalid),
      );
      expect(sessions.persisted, isEmpty);
    });

    test('a cancel passes through', () async {
      client.signInOutcome = const OidcSignInCancelled();

      expect(await repository.signIn(target: SessionTarget.studio), isA<SsoProviderCancelled>());
      expect(sessions.persisted, isEmpty);
    });

    test('a session that cannot be persisted is rejected with the persist code', () async {
      sessions.persistResult = const Failure(UnknownError('disk full'));

      final result = await signInWith(_claims());

      expect(
        result,
        isA<SsoProviderRejected>().having((r) => r.errorCode, 'errorCode', AppErrorCode.authSessionPersistFailed),
      );
    });
  });

  // A production build prints the info level, and the email mask does not cover a preferred username or a subject.
  group('SsoAuthRepository log output in production', () {
    late List<String> lines;

    setUp(() {
      AppLogger.configure(isProduction: true);
      lines = [];
      void collect(OutputEvent event) => lines.addAll(event.lines);
      Logger.addOutputListener(collect);
      addTearDown(() => Logger.removeOutputListener(collect));
    });

    tearDown(() => AppLogger.configure(isProduction: false));

    test('a sign-in logs neither the username nor the subject', () async {
      final result = await signInWith(_claims(extra: {'preferred_username': 'jdoe-identifier'}));

      expect(result, isA<SsoProviderSignedIn>());
      expect(lines.join('\n'), contains('Signed in through the identity provider'));
      expect(lines.join('\n'), allOf(isNot(contains('jdoe-identifier')), isNot(contains('subject-1'))));
    });
  });
}
