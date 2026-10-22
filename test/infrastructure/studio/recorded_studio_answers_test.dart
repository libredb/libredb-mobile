import 'dart:io';

import 'package:flutter_bloc_advance/core/errors/app_api_exception.dart';
import 'package:flutter_bloc_advance/core/errors/app_error_code.dart';
import 'package:flutter_bloc_advance/features/auth/data/models/studio_identity_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/connection_policy_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/connection_test_result_model.dart';
import 'package:flutter_bloc_advance/features/connections/data/models/managed_connections.dart';
import 'package:flutter_bloc_advance/features/object_browser/data/models/object_browser_json.dart';
import 'package:flutter_bloc_advance/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:flutter_bloc_advance/infrastructure/http/api_client.dart';
import 'package:flutter_bloc_advance/infrastructure/studio/studio_errors.dart';
import 'package:flutter_bloc_advance/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads answers recorded from a real Studio, so the readers are held to what Studio sends rather than to the
/// hand-written answers in assets/mock.
///
/// Recorded from Studio main at dbfea263 in tool/studio-dev, as user admin with a libredb-mobile access token, on the
/// built-in SQLite sample connection. SQLite has no transactions, so test/fixtures/studio/txstatus.json is Studio's
/// refusal of one. Record again after a Studio change to these routes.
void main() {
  String fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

  test('GET /api/auth/me of a bearer session', () {
    final identity = StudioIdentityModel.fromJsonString(fixture('me'));

    expect(identity.role, StudioRole.admin);
    expect(identity.username, 'admin@example.com');
    expect(identity.viaBearer, isTrue);
  });

  test('GET /api/connections/managed', () {
    final connections = ManagedConnections.fromJsonString(fixture('managed'));

    expect(connections.map((c) => c.id), ['seed:sqlite-embedded-sample', 'seed:libredb-embedded-sample']);
    expect(connections.first.database, 'data/sample-employees.db');
  });

  test('GET /api/connections/policy without governance', () {
    final policy = ConnectionPolicyModel.fromJsonString(fixture('policy'));

    expect(policy.governance, isFalse);
  });

  test('POST /api/db/test-connection', () {
    expect(ConnectionTestResultModel.fromJsonString(fixture('test')).latency, isNotNull);
  });

  test('POST /api/db/provider-meta of SQLite', () {
    final meta = ObjectBrowserJson.providerMeta(fixture('meta'));

    expect(meta.isSql, isTrue);
    expect(meta.containerLevels, isEmpty, reason: 'SQLite has no container level');
    expect(meta.supportsTransactions, isFalse);
    expect(meta.objectKinds.map((k) => k.id), containsAll(['table', 'view']));
  });

  test('POST /api/db/objects/containers of an engine without containers', () {
    expect(ObjectBrowserJson.containers(fixture('containers')), isEmpty);
  });

  test('POST /api/db/objects/counts', () {
    expect(ObjectBrowserJson.counts(fixture('counts')).keys, containsAll(['table', 'view']));
  });

  test('POST /api/db/objects/list and search', () {
    expect(ObjectBrowserJson.objects(fixture('list')).map((o) => o.name), contains('employee'));
    expect(ObjectBrowserJson.objects(fixture('search')), isNotEmpty);
  });

  test('POST /api/db/objects/describe', () {
    expect(ObjectBrowserJson.detail(fixture('describe')).columns, isNotEmpty);
  });

  test('POST /api/db/query with a page that has more rows', () {
    final result = SqlEditorJson.queryResult(fixture('query'));

    expect(result.rows, hasLength(2));
    expect(result.fields.first, 'emp_no');
    expect(result.columnTypes['emp_no'], 'INTEGER');
    expect(result.pagination?.hasMore, isTrue);
  });

  test('POST /api/db/query with a bind value', () {
    expect(SqlEditorJson.queryResult(fixture('queryparams')).rows.single['answer'], 42);
  });

  test('POST /api/db/multi-query that stops at a failed statement', () {
    final script = SqlEditorJson.scriptResult(fixture('multi'));

    expect(script.statementCount, 3);
    expect(script.executedCount, 2);
    expect(script.statements.last.error, contains('syntax error'));
  });

  test('POST /api/db/cancel of a run that is not running', () {
    expect(SqlEditorJson.cancelled(fixture('cancel')), isFalse);
  });

  test("a database error keeps the database's words", () {
    final error = studioError(
      BadRequestException(
        fixture('queryerror'),
        statusCode: 400,
        errorCode: ApiClient.errorCodeOf(fixture('queryerror')),
        serverMessage: 'near "FORM": syntax error',
      ),
    );

    expect(error.code, AppErrorCode.studioQueryError.key);
  });

  test('a transaction on an engine without transactions is a 400 without a code', () {
    expect(ApiClient.errorCodeOf(fixture('txstatus')), isNull);
  });
}
