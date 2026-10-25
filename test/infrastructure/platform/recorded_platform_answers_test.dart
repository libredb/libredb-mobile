import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/platform_audit/data/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_connections/data/models/platform_connections_model.dart';
import 'package:libredb_mobile/features/platform_connections/data/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/platform_status/data/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_target.dart';
import 'package:libredb_mobile/infrastructure/http/interceptors/resilience_interceptor.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_errors.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_session_policy.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

/// Reads answers recorded from a real LibreDB Platform, so the Platform readers are held to what Platform sends rather
/// than to the hand-written answers in assets/mock.
///
/// Recorded on 2026-10-25 from the platform profile of tool/studio-dev, image
/// `ghcr.io/libredb/libredb-platform:1.3.0@sha256:e53ca9b82e337bb995a575ac4082de3da092d33c098a020a13292584fbc49ea9`,
/// with the placeholder license (no seat can be added), from a fresh volume, as raw bodies of `GET /api/v1/me`:
/// `me_no_token.json` without a token; `me_not_admin.json` with a libredb-mobile access token of `user`,
/// `me_norole.json` of `norole` (no `libredb_roles` claim), `me_license_invalid.json` of `admin`, and `me_expired.json`
/// of `admin` 95 seconds after it was issued; `me_api_disabled.json` from Platform recreated with
/// `PLATFORM_API_AUDIENCE` empty; `me_idp_unavailable.json` from Platform restarted while Keycloak was stopped, with an
/// `admin` token fetched before the stop. docs/studio.md ("Platform answers") has the command behind each one.
///
/// The success and write answers were recorded the same day from the same image with the free localhost dev license
/// (one admin seat, three user seats), from a fresh volume, as `admin` unless named otherwise, after `me.json`, so
/// `admin` held the admin seat; `me_admin_seats.json` is `admin2`'s. The two connections were created by hand in
/// Platform's web console (docs/studio.md, "Success and write answers"); every grant made for the recording was
/// revoked.
///
/// The audit, enable and disable answers were recorded the same day from the same image and license, from a fresh
/// volume, as `admin`, with a third hand-made connection `Dev app (toggle)` for enable and disable. The audit events
/// are the statements `user` ran through a Studio 1.1.0 governed by that Platform (`libredb-studio-platform`), with
/// statement capture switched between `full`, `redacted` and `none` on Platform's Studio settings page; the plan was
/// set to FREE for `audit_plan_feature_required.json` only. docs/studio.md ("Audit, liveness and enable or disable
/// answers") has every step. `health_live.json` is `GET /api/health/live`, fetched without a token.
///
/// Each body is answered to a [PlatformApiClient], so it goes through the client's envelope reader and exception path,
/// then through [platformError]; the session predicates read a [DioException] built from the status and the raw body.
void main() {
  String fixture(String name) => File('test/fixtures/platform/$name.json').readAsStringSync();

  DioException answer(int status, String body) {
    final request = RequestOptions(path: '/v1/me');
    return DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: status, data: body),
    );
  }

  late _FixtureAdapter adapter;
  late PlatformApiClient client;
  late int sessionExpiredCalls;
  late List<AppErrorCode> refusals;

  setUp(() async {
    sessionExpiredCalls = 0;
    refusals = [];
    client = PlatformApiClient(
      appConfig: const AppConfig(
        environment: Environment.prod,
        apiBaseUrl: 'https://localhost:9443/api',
        certificatePins: [],
        idleTimeout: null,
        platform: PlatformConfigured(baseUrl: 'https://localhost:9445/api'),
      ),
      secureStorage: FlutterSecureStorageAdapter(),
      tokenRotation: const _RotatingTokens(),
      onSessionExpired: () => sessionExpiredCalls++,
      onAccountRefused: refusals.add,
    );
    adapter = _FixtureAdapter();
    client.instance.httpClientAdapter = adapter;
    TestEnv.authenticate();
    await FlutterSecureStorageAdapter().write(SecureStorageKeys.refreshToken.key, 'REFRESH_TOKEN');
  });

  tearDown(ResilienceInterceptor.instance.resetAll);

  /// The exception the client throws when Platform answers every request with [status] and [body].
  Future<AppException> thrownFor(int status, String body) async {
    adapter.answer(status, body);
    try {
      await client.get('/v1/me');
    } on AppException catch (error) {
      return error;
    }
    fail('GET /v1/me did not throw');
  }

  for (final (name, status, code, mapped, sessionEnds, refusal) in [
    ('me_no_token', 401, 'BEARER_INVALID', AppErrorCode.authInvalidAccessToken, true, false),
    ('me_expired', 401, 'BEARER_INVALID', AppErrorCode.authInvalidAccessToken, true, false),
    ('me_not_admin', 403, 'ADMIN_ROLE_REQUIRED', AppErrorCode.platformAdminRoleRequired, false, true),
    ('me_norole', 403, 'ADMIN_ROLE_REQUIRED', AppErrorCode.platformAdminRoleRequired, false, true),
    ('me_license_invalid', 403, 'LICENSE_INVALID', AppErrorCode.platformLicenseInvalid, false, false),
    ('me_admin_seats', 403, 'LICENSE_ADMIN_SEATS', AppErrorCode.platformLicenseAdminSeats, false, true),
    ('me_api_disabled', 404, 'API_DISABLED', AppErrorCode.platformApiDisabled, false, false),
    (
      'me_idp_unavailable',
      503,
      'IDENTITY_PROVIDER_UNAVAILABLE',
      AppErrorCode.platformIdentityProviderUnavailable,
      false,
      false,
    ),
  ]) {
    test('GET /api/v1/me $name: $status $code', () async {
      final body = fixture(name);
      final message = ((jsonDecode(body) as Map)['error'] as Map)['message'] as String;

      final thrown = await thrownFor(status, body);

      expect(thrown.statusCode, status);
      expect(thrown.errorCode, code);
      expect(platformError(thrown).code, mapped.key);
      expect('$thrown', isNot(contains(message)), reason: "Platform's message never reaches an exception");
      expect(platformError(thrown).message, isNot(contains(message)));

      expect(isPlatformSessionExpired(answer(status, body)), sessionEnds);
      expect(isPlatformSessionRefused(answer(status, body)), sessionEnds);
      expect(platformAccountRefusal(answer(status, body)), refusal ? mapped : isNull);
      expect(sessionExpiredCalls, sessionEnds ? 1 : 0, reason: 'only a BEARER_INVALID after the refresh ends it');
      expect(refusals, refusal ? [mapped] : isEmpty, reason: 'only an account refusal opens the refusal page');
    });
  }

  group('success answers, read by the production repositories', () {
    test('GET /api/v1/me me: the admin holding the admin seat', () async {
      adapter.answer(200, fixture('me'));

      final identity = (await PlatformIdentityRepository(client).fetch()).dataOrNull!;

      expect(adapter.requests, ['GET /v1/me']);
      expect(identity.id, isNotEmpty);
      expect(identity.email, 'admin@example.com');
      expect(identity.name, 'Demo Admin');
      expect(identity.roles, ['PLATFORM_ADMIN']);
      expect(identity.permissions, containsAll(['connection.view', 'user.view', 'audit.view']));
      expect(identity.tenant.slug, 'default');
      expect(identity.tenant.name, 'LibreDB Mobile dev');
    });

    test('GET /api/v1/connections connections: both connections, newest first', () async {
      adapter.answer(200, fixture('connections'));

      final connections = (await PlatformConnectionRepository(client).list()).dataOrNull!;

      expect(adapter.requests, ['GET /v1/connections']);
      expect(
        [for (final c in connections) (c.name, c.engine, c.status, c.hasWriteCredential)],
        [('Dev app (read-only)', 'postgres', 'active', false), ('Dev app (write)', 'postgres', 'active', true)],
      );
    });

    test('GET /api/v1/connections/{id}/grants grants: the read grant of user', () async {
      adapter.answer(200, fixture('grants'));

      final grants = (await PlatformGrantRepository(client).list(_writeConnection)).dataOrNull!;

      expect(adapter.requests, ['GET /v1/connections/$_writeConnection/grants']);
      final grant = grants.single;
      expect(grant.subject, _user);
      expect(grant.subjectUsername, 'user');
      expect(grant.subjectEmail, 'user@example.com');
      expect(grant.level, 'read');
      expect(grant.expiresAt, isNull);
      expect(grant.grantedBy.name, 'Demo Admin');
      expect(grant.grantedBy.email, 'admin@example.com');
      expect(grant.grantedAt.isUtc, isTrue);
    });

    test('GET /api/v1/directory/users directory: every user, the disabled one with enabled false', () async {
      adapter.answer(200, fixture('directory'));

      final page = (await PlatformDirectoryRepository(client).search(query: '', page: 1)).dataOrNull!;

      expect(adapter.requests, ['GET /v1/directory/users']);
      expect(adapter.queries.single, {'page': '1'}, reason: 'an empty query sends no q');
      expect((page.page, page.total), (1, 5));
      expect(
        [for (final u in page.users) (u.username, u.enabled, u.studioRole, u.needsSeat)],
        [
          ('admin', true, 'admin', true),
          ('admin2', true, 'admin', true),
          ('disabled', false, 'user', true),
          ('norole', true, null, true),
          ('user', true, 'user', true),
        ],
      );
      final user = page.users.last;
      expect(user.id, _user);
      expect(user.email, 'user@example.com');
      expect(user.fullName, 'Demo User');
    });

    test('GET /api/v1/directory/users?q=adm directory_query: admin and admin2', () async {
      adapter.answer(200, fixture('directory_query'));

      final page = (await PlatformDirectoryRepository(client).search(query: ' adm ', page: 1)).dataOrNull!;

      expect(adapter.requests, ['GET /v1/directory/users']);
      expect(adapter.queries.single, {'page': '1', 'q': 'adm'}, reason: 'the query is sent trimmed');
      expect((page.page, page.total), (1, 2));
      expect([for (final u in page.users) u.username], ['admin', 'admin2']);
      expect(page.users.first.fullName, 'Demo Admin');
    });

    test('PUT /api/v1/connections/{id}/grants/{subject} grant_put: the id of the read grant of user', () async {
      adapter.answer(200, fixture('grant_put'));

      final id = (await PlatformGrantRepository(
        client,
      ).put(_writeConnection, _user, level: 'read', expiresAt: null)).dataOrNull;

      expect(adapter.requests, ['PUT /v1/connections/$_writeConnection/grants/$_user']);
      expect(
        adapter.bodies.single,
        '{"level":"read","expiresAt":null}',
        reason: 'the body the fixture was recorded with',
      );
      expect(id, 'cmvnibe6j000501p6r2h279hr');
    });
  });

  group('refusals of the grant and directory routes', () {
    Future<AppError> failureOf(Future<Result<Object?>> Function() call) async {
      final result = await call();
      expect(result, isA<Failure<Object?>>());
      return (result as Failure<Object?>).error;
    }

    test('GET /api/v1/connections/unknown/grants grants_unknown_connection: 404 NOT_FOUND', () async {
      adapter.answer(404, fixture('grants_unknown_connection'));

      final error = await failureOf(() => PlatformGrantRepository(client).list('unknown'));

      expect(error.code, AppErrorCode.platformNotFound.key);
      expect(error.message, isNot(contains('Connection not found')));
      expect(sessionExpiredCalls, 0);
      expect(refusals, isEmpty);
    });

    test('DELETE /api/v1/connections/{id}/grants/unknown grant_delete_unknown: 404 NOT_FOUND', () async {
      adapter.answer(404, fixture('grant_delete_unknown'));

      final error = await failureOf(() => PlatformGrantRepository(client).revoke(_writeConnection, 'unknown'));

      expect(adapter.requests, ['DELETE /v1/connections/$_writeConnection/grants/unknown'], reason: 'sent once');
      expect(error.code, AppErrorCode.platformNotFound.key);
      expect(error.message, isNot(contains('Grant not found')));
    });

    for (final (name, status, fieldKeys, mapped) in [
      ('grant_put_level', 400, ['level'], AppErrorCode.platformGrantLevelRefused),
      ('grant_put_subject_unknown', 400, ['subject'], AppErrorCode.platformGrantSubjectRefused),
      ('grant_put_subject_disabled', 400, ['subject'], AppErrorCode.platformGrantSubjectRefused),
      ('grant_put_expiry', 400, ['expiresAt'], AppErrorCode.platformGrantExpiryRefused),
      // The strict schema names no field for an extra key: Platform sends the empty key.
      ('grant_put_body', 400, [''], AppErrorCode.platformValidationFailed),
      ('grant_put_user_seats', 403, <String>[], AppErrorCode.platformLicenseUserSeats),
    ]) {
      test('PUT /api/v1/connections/{id}/grants/{subject} $name: $status', () async {
        final body = fixture(name);
        final error = (jsonDecode(body) as Map)['error'] as Map;
        adapter.answer(status, body);

        final thrown = await _thrown(
          () => client.put('/v1/connections', const {'level': 'read', 'expiresAt': null}, pathParams: 'id/grants/s'),
        );

        expect(adapter.requests, ['PUT /v1/connections/id/grants/s'], reason: 'a PUT is never sent again');
        expect(thrown.statusCode, status);
        expect(thrown.errorCode, error['code']);
        expect(thrown is BadRequestException ? thrown.fieldErrorKeys : <String>[], fieldKeys);
        expect(platformGrantWriteError(thrown).code, mapped.key);
        for (final text in [error['message'], ...((error['fieldErrors'] as Map?)?.values.expand((v) => v) ?? [])]) {
          expect('$thrown', isNot(contains('$text')), reason: "Platform's text can name a user");
        }
        expect(platformAccountRefusal(answer(status, body)), isNull, reason: 'a grant refusal never locks the admin');
        expect(sessionExpiredCalls, 0);
        expect(refusals, isEmpty);
      });
    }

    for (final (name, query, status, mapped) in [
      ('directory_bad_page', {'page': 0}, 400, AppErrorCode.platformValidationFailed),
      ('directory_unavailable', {'q': 'zz'}, 503, AppErrorCode.platformDirectoryUnavailable),
    ]) {
      test('GET /api/v1/directory/users $name: $status', () async {
        adapter.answer(status, fixture(name));

        final thrown = await _thrown(() => client.get('/v1/directory/users', queryParams: query));

        expect(adapter.requests, ['GET /v1/directory/users'], reason: 'a coded 503 is sent once');
        expect(thrown.statusCode, status);
        expect(platformError(thrown).code, mapped.key);
        expect(sessionExpiredCalls, 0);
        expect(refusals, isEmpty);
      });
    }

    test('directory_bad_page names the field page', () async {
      adapter.answer(400, fixture('directory_bad_page'));

      final thrown = await _thrown(() => client.get('/v1/directory/users', queryParams: {'page': 0}));

      expect((thrown as BadRequestException).fieldErrorKeys, ['page']);
    });
  });

  group('GET /api/v1/audit, read by PlatformAuditRepository', () {
    Future<AppError> failureOf(Future<Result<Object?>> Function() call) async {
      final result = await call();
      expect(result, isA<Failure<Object?>>());
      return (result as Failure<Object?>).error;
    }

    test('audit: every event of the run, newest first, with each status and each capture', () async {
      adapter.answer(200, fixture('audit'));

      final page = (await PlatformAuditRepository(client).list(filter: const AuditFilter(), offset: 0)).dataOrNull!;

      expect(adapter.requests, ['GET /v1/audit']);
      expect(adapter.queries.single, {'limit': '50', 'offset': '0'});
      expect((page.total, page.offset, page.events.length), (8, 0, 8));
      expect(
        [for (final e in page.events) (e.status, e.statementCapture, e.statementType, e.connectionName)],
        [
          ('success', 'none', 'SELECT', 'Dev app (write)'),
          ('cancelled', 'none', 'SELECT', 'Dev app (write)'),
          ('refused', 'redacted', 'SELECT', 'Dev app (toggle)'),
          ('error', 'redacted', 'INSERT', 'Dev app (read-only)'),
          ('error', 'redacted', 'SELECT', 'Dev app (write)'),
          ('success', 'full', 'SELECT', 'Dev app (write)'),
          ('success', 'full', 'INSERT', 'Dev app (write)'),
          ('success', 'full', 'DDL', 'Dev app (write)'),
        ],
      );
      // Checked as booleans and lengths, so a failing expect prints no statement and no error text.
      expect([for (final e in page.events) e.statement != null], [false, false, false, true, true, true, true, true]);
      expect([for (final e in page.events) e.errorMessage == null], everyElement(isTrue));
      expect(
        [for (final e in page.events) e.errorCode],
        [null, '57014', 'CONNECTION_NOT_FOUND', '42501', '22012', null, null, null],
      );
      expect(
        [for (final e in page.events) e.accessLevel],
        ['write', 'write', null, 'read', 'write', 'write', 'write', 'write'],
        reason: 'a refused request names no grant level',
      );
      for (final e in page.events) {
        expect(e.subject, _user);
        expect(e.sessionRole, 'user');
        expect(e.source, 'editor');
        expect(e.engine, 'postgres');
        expect(e.connectionKnown, isTrue);
        expect(e.statementTruncated, isFalse);
        expect(e.startedAt.isUtc, isTrue);
      }
      expect(page.events.first.connectionId, _auditWriteConnection);
      expect(page.events[1].durationMs, greaterThan(1000), reason: 'pg_sleep ran until the cancel');
    });

    test('audit_page: two events from offset 2, the total of the whole log', () async {
      adapter.answer(200, fixture('audit_page'));

      final page = (await PlatformAuditRepository(
        client,
      ).list(filter: const AuditFilter(), offset: 2, limit: 2)).dataOrNull!;

      expect(adapter.queries.single, {'limit': '2', 'offset': '2'});
      expect((page.total, page.offset), (8, 2));
      expect([for (final e in page.events) (e.status, e.statementType)], [('refused', 'SELECT'), ('error', 'INSERT')]);
    });

    test('audit_filtered: the SELECT that failed on the write connection, and only it', () async {
      adapter.answer(200, fixture('audit_filtered'));

      final page = (await PlatformAuditRepository(client).list(
        filter: AuditFilter(
          status: 'error',
          statementType: 'SELECT',
          connectionId: _auditWriteConnection,
          from: DateTime.utc(2026, 10, 25, 13, 28),
          to: DateTime.utc(2026, 10, 25, 13, 30),
        ),
        offset: 0,
      )).dataOrNull!;

      expect(adapter.queries.single, {
        'limit': '50',
        'offset': '0',
        'connectionId': _auditWriteConnection,
        'statementType': 'SELECT',
        'status': 'error',
        'from': '2026-10-25T13:28:00.000Z',
        'to': '2026-10-25T13:30:00.000Z',
      }, reason: 'the query the fixture was recorded with');
      final event = page.events.single;
      expect(page.total, 1);
      expect((event.status, event.statementType, event.statementCapture), ('error', 'SELECT', 'redacted'));
      expect((event.connectionId, event.errorCode), (_auditWriteConnection, '22012'));
      expect(event.statement?.contains('mobile_audit_fixture_error'), isTrue, reason: 'redacted keeps identifiers');
      expect(event.errorMessage, isNull, reason: 'redacted capture records no error text');
    });

    test('audit_search: the events whose recorded statement holds the term, none without a statement', () async {
      adapter.answer(200, fixture('audit_search'));

      final page = (await PlatformAuditRepository(
        client,
      ).list(filter: const AuditFilter(search: ' mobile_audit_fixture '), offset: 0)).dataOrNull!;

      expect(adapter.queries.single, {'limit': '50', 'offset': '0', 'search': 'mobile_audit_fixture'});
      expect(page.total, 5);
      expect([for (final e in page.events) e.statement?.contains('mobile_audit_fixture')], everyElement(isTrue));
      expect({for (final e in page.events) e.statementCapture}, {'full', 'redacted'});
    });

    test('audit_bad_filters: 400 VALIDATION_FAILED on from, limit and status', () async {
      final body = fixture('audit_bad_filters');
      final error = (jsonDecode(body) as Map)['error'] as Map;
      adapter.answer(400, body);

      final thrown = await _thrown(
        () => client.get('/v1/audit', queryParams: {'limit': 201, 'status': 'nope', 'from': 'yesterday'}),
      );

      expect(adapter.requests, ['GET /v1/audit']);
      expect(thrown.errorCode, 'VALIDATION_FAILED');
      expect((thrown as BadRequestException).fieldErrorKeys, unorderedEquals(['from', 'limit', 'status']));
      expect(platformError(thrown).code, AppErrorCode.platformValidationFailed.key);
      for (final text in [error['message'], ...(error['fieldErrors'] as Map).values.expand((v) => v)]) {
        expect('$thrown', isNot(contains('$text')));
      }
      expect(sessionExpiredCalls, 0);
      expect(refusals, isEmpty);
    });

    test('audit_plan_feature_required: 403 PLAN_FEATURE_REQUIRED, a plan without the audit log', () async {
      final body = fixture('audit_plan_feature_required');
      adapter.answer(403, body);

      final error = await failureOf(() => PlatformAuditRepository(client).list(filter: const AuditFilter(), offset: 0));

      expect(adapter.requests, ['GET /v1/audit'], reason: 'sent once');
      expect(error.code, AppErrorCode.platformPlanFeatureRequired.key);
      expect(error.message, isNot(contains('plan upgrade')), reason: "Platform's message never reaches the error");
      expect(platformAccountRefusal(answer(403, body)), isNull, reason: 'a plan refusal never locks the admin out');
      expect(sessionExpiredCalls, 0);
      expect(refusals, isEmpty);
    });

    test('PERMISSION_DENIED has no fixture: a bearer caller is always a Platform admin', () {
      expect(File('test/fixtures/platform/audit_permission_denied.json').existsSync(), isFalse);
    });
  });

  test('GET /api/health/live health_live: Platform answers live, read by PlatformStatusRepository', () async {
    adapter.answer(200, fixture('health_live'));

    final result = await PlatformStatusRepository(client).liveness();

    expect(result, isA<Success<void>>());
    expect(adapter.requests, ['GET /health/live'], reason: 'outside /api/v1, sent once');
  });

  // IPlatformConnectionRepository.setActive sends it and reads the 200 through PlatformConnectionsModel.readOne: one
  // connection in the item shape of GET /api/v1/connections.
  group('PATCH /api/v1/connections/{id}', () {
    test('connection_patch: a no-op 200 answers the connection', () {
      final connection = PlatformConnectionsModel.readOne(fixture('connection_patch'));

      expect(
        (connection.name, connection.status, connection.hasWriteCredential),
        ('Dev app (read-only)', 'active', false),
      );
    });

    for (final (name, active, status) in [
      ('connection_patch_disable', false, 'inactive'),
      ('connection_patch_enable', true, 'active'),
    ]) {
      test('$name: the toggle connection answers $status', () async {
        adapter.answer(200, fixture(name));

        final connection = (await PlatformConnectionRepository(
          client,
        ).setActive(_toggleConnection, active: active)).dataOrNull!;

        expect(adapter.requests, ['PATCH /v1/connections/$_toggleConnection']);
        expect(adapter.bodies.single, '{"active":$active}', reason: 'the body the fixture was recorded with');
        expect(
          (connection.id, connection.name, connection.status, connection.hasWriteCredential),
          (_toggleConnection, 'Dev app (toggle)', status, false),
        );
      });
    }

    test('connection_patch_user_seats: 403 LICENSE_USER_SEATS, sent once, never locks the admin', () async {
      final body = fixture('connection_patch_user_seats');
      adapter.answer(403, body);

      final result = await PlatformConnectionRepository(client).setActive(_toggleConnection, active: true);

      expect(adapter.requests, ['PATCH /v1/connections/$_toggleConnection'], reason: 'a PATCH is never sent again');
      final error = (result as Failure<Object?>).error;
      expect(error.code, AppErrorCode.platformLicenseUserSeats.key);
      expect(error.message, isNot(contains('Not enough user seats')));
      expect(platformAccountRefusal(answer(403, body)), isNull);
      expect(sessionExpiredCalls, 0);
      expect(refusals, isEmpty);
    });

    for (final (name, status, code, fieldKeys) in [
      ('connection_patch_body', 400, 'VALIDATION_FAILED', ['']),
      ('connection_patch_unknown', 404, 'NOT_FOUND', <String>[]),
    ]) {
      test('$name: $status $code', () {
        final body = fixture(name);

        expect(const PlatformErrorEnvelope().codeOf(body), code);
        expect(const PlatformErrorEnvelope().fieldErrorKeysOf(body), fieldKeys);
      });
    }
  });
}

const _writeConnection = '641ed0ff-6669-41eb-9976-557025a3eb80';
// The connections of the audit, enable and disable recording, on a later fresh volume than the grant answers.
const _auditWriteConnection = '51e50862-781e-4010-b4ea-d9a9db5f24d7';
const _toggleConnection = '4c25dc92-af0c-4a36-857c-095d4e602b31';
const _user = 'a0000000-0000-4000-8000-000000000002';

Future<AppException> _thrown(Future<Object?> Function() call) async {
  try {
    await call();
  } on AppException catch (error) {
    return error;
  }
  fail('the request did not throw');
}

/// Answers every request with one recorded status and body.
class _FixtureAdapter implements HttpClientAdapter {
  var _status = 500;
  var _body = '';

  /// Each request as `METHOD path`, in the order sent.
  final requests = <String>[];

  /// The query parameters of each request, in the order sent.
  final queries = <Map<String, String>>[];

  /// The body of each request as sent, empty for a request without one.
  final bodies = <String>[];

  void answer(int status, String body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null ? <int>[] : [for (final chunk in await requestStream.toList()) ...chunk];
    requests.add('${options.method} ${options.uri.path.replaceFirst('/api', '')}');
    queries.add(options.uri.queryParameters);
    bodies.add(utf8.decode(body));
    return ResponseBody.fromString(
      _body,
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A refresh that always succeeds, so a BEARER_INVALID is sent once more with the new token.
class _RotatingTokens implements TokenRotation {
  const _RotatingTokens();

  @override
  Future<TokenRotationResult> rotate(String refreshToken) async =>
      const TokensRotated(accessToken: 'NEW_JWT', refreshToken: 'NEW_REFRESH');
}
