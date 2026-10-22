import 'dart:convert';
import 'dart:io';

import 'package:libredb_mobile/core/errors/app_api_exception.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/data/models/studio_identity_model.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_policy_model.dart';
import 'package:libredb_mobile/features/connections/data/models/connection_test_result_model.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/sql_editor_json.dart';
import 'package:libredb_mobile/features/studio_status/data/models/studio_status_json.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_errors.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads answers recorded from a real Studio, so the readers are held to what Studio sends rather than to the
/// hand-written answers in assets/mock.
///
/// Recorded from Studio main at dbfea263 in tool/studio-dev, as user admin with a libredb-mobile access token, on the
/// built-in SQLite sample connection. SQLite has no transactions, so test/fixtures/studio/txstatus.json is Studio's
/// refusal of one. Record again after a Studio change to these routes.
///
/// The governed fixtures (`*_governed.json`, `governance_unavailable.json`, `admin_governance.json`) come from the
/// governed profile of tool/studio-dev, Studio main at dbfea263 in governance mode, recorded with a libredb-mobile access
/// token: as user, who holds a write grant on sales-dev and a read grant on sales-prod, and as admin for the governance
/// status. docs/studio.md describes the profile and how the unavailable source was produced.
/// The governed seed was generated from Studio 02dc26057, which has the same governance contract as dbfea263.
/// `health.json`, `ready.json`, `ready_governed.json` and `ready_degraded.json` (the governed Studio with its source
/// stopped) were recorded without a token, as the app sends them.
void main() {
  String fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

  test('GET /api/auth/me of a bearer session', () {
    final identity = StudioIdentityModel.fromJsonString(fixture('me'));

    expect(identity.role, const StudioAdminRole());
    expect(identity.username, 'admin@example.com');
    expect(identity.viaBearer, isTrue);
  });

  test('POST /api/auth/logout of a bearer session', () {
    expect(() => StudioIdentityModel.readSignOutAccepted(fixture('logout')), returnsNormally);
  });

  test('GET /api/connections/managed', () {
    final managed = ManagedConnectionsModel.read(fixture('managed'));
    final connections = managed.connections;

    expect(connections.map((c) => c.id), ['seed:sqlite-embedded-sample', 'seed:libredb-embedded-sample']);
    expect(connections.map((c) => c.seedId), ['sqlite-embedded-sample', 'libredb-embedded-sample']);
    expect(connections.first.database, 'data/sample-employees.db');
    expect(connections.every((c) => !c.managed && !c.readOnly && c.color == null), isTrue);
    expect(managed.cacheHint, const Duration(minutes: 1));
  });

  test('GET /api/connections/policy without governance', () {
    final policy = ConnectionPolicyModel.fromJsonString(fixture('policy'));

    expect(policy.governance, isFalse);
  });

  test('GET /api/connections/managed under governance lists the granted connections', () {
    final managed = ManagedConnectionsModel.read(fixture('managed_governed'));
    final connections = managed.connections;

    expect(connections.map((c) => c.id), ['seed:sales-dev', 'seed:sales-prod']);
    expect(connections.map((c) => c.environment), ['development', 'production']);
    expect(connections.map((c) => c.group), ['Sales', 'Sales']);
    expect(connections.first.type, 'postgres');
    final raw = (jsonDecode(fixture('managed_governed')) as Map<String, dynamic>)['connections'] as List;
    expect(raw.map((c) => (c as Map)['user']), [
      'sales_writer',
      'sales_reader',
    ], reason: 'sales-prod is bound for read');
  });

  test('GET /api/connections/managed under governance reads the fields of a governed connection', () {
    final managed = ManagedConnectionsModel.read(fixture('managed_governed'));
    final connections = managed.connections;

    expect(connections.map((c) => c.color), ['#16a34a', '#dc2626']);
    expect(connections.map((c) => c.seedId), ['sales-dev', 'sales-prod']);
    expect(connections.every((c) => c.managed), isTrue);
    expect(
      connections.every((c) => !c.readOnly),
      isTrue,
      reason: 'a read grant is not the seed flag; the recorded Studio sends no access field',
    );
    expect(managed.cacheHint, const Duration(seconds: 10));
    final text = connections.map((c) => '$c ${c.props}').join();
    expect(text, isNot(contains('sales_writer')));
    expect(text, isNot(contains('sales_reader')));
  });

  test('GET /api/connections/policy under governance', () {
    final policy = ConnectionPolicyModel.fromJsonString(fixture('policy_governed'));

    expect(policy.customConnections, isFalse);
    expect(policy.governance, isTrue);
    expect(policy.statementCapture, 'full');
  });

  test('GET /api/connections/managed while the governance source is unavailable', () {
    final body = fixture('governance_unavailable');
    final error = studioError(FetchDataException(body, statusCode: 503, errorCode: ApiClient.errorCodeOf(body)));

    expect(error.code, AppErrorCode.studioGovernanceUnavailable.key);
  });

  test('GET /api/admin/governance of a loaded snapshot', () {
    // The app has no reader of this route yet; the test pins the fields an admin screen would show.
    final governance = (jsonDecode(fixture('admin_governance')) as Map<String, dynamic>)['governance'] as Map;

    expect(governance['source'], 'postgres');
    expect(governance['freshness'], 'ok');
    expect(governance['admittedConnections'], 2);
    expect(governance['skipped'], isEmpty);
    expect((governance['canary'] as Map).values, everyElement('ok'));
    expect(governance['settings'], contains(equals({'key': 'queryLog.statementCapture', 'source': 'runtime'})));
  });

  test('POST /api/db/test-connection', () {
    expect(ConnectionTestResultModel.fromJsonString(fixture('test')).latency, isNotNull);
  });

  test('POST /api/db/provider-meta of SQLite', () {
    final meta = ProviderMetaJson.read(fixture('meta'));

    expect(meta.isSql, isTrue);
    expect(meta.containerLevels, isEmpty, reason: 'SQLite has no container level');
    expect(meta.supportsTransactions, isFalse);
    expect(meta.objectKinds.map((k) => k.id), containsAll(['table', 'view']));
    expect(meta.schemaRefreshPattern, r'(CREATE|DROP|ALTER|TRUNCATE)\b');
    expect(meta.explainFormat, 'sqlite-queryplan');
    expect(meta.containerPathShapes, 'exact');
    expect(meta.supportsResultPagination, isTrue);
    expect(meta.objectKinds.where((k) => k.acceptsRowWrites).map((k) => k.id), ['table']);
    expect(meta.objectKinds.every((k) => k.sourceLanguage == 'sql'), isTrue);
    expect(meta.labels.entityNamePlural, 'Tables');
    expect(meta.labels.searchPlaceholder, 'Search tables or columns...');
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

  // Studio 02dc26057 has the same health and ready routes as dbfea263.
  test('GET /api/health', () {
    StudioStatusJson.liveness(fixture('health'));
  });

  test('GET /api/ready without governance', () {
    expect(StudioStatusJson.readiness(fixture('ready')), const StudioReadinessReady());
  });

  test('GET /api/ready of the governed Studio', () {
    expect(StudioStatusJson.readiness(fixture('ready_governed')), const StudioReadinessOk());
  });

  // Recorded about 15 seconds after the governance source was stopped, while the connection routes answered
  // governance_unavailable.json.
  test('GET /api/ready of the governed Studio without its source is degraded, worded as temporarily unavailable', () {
    final readiness = StudioStatusJson.readiness(fixture('ready_degraded'));

    expect(readiness, const StudioReadinessDegraded());
    expect(GovernanceOutage.fromReadiness(readiness).kind, GovernanceOutageKind.temporarilyUnavailable);
  });
}
