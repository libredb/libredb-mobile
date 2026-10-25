import 'dart:io';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/data/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/platform_status/data/repositories/platform_status_repository.dart';
import 'package:libredb_mobile/features/platform_connections/data/repositories/platform_connection_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/platform_audit/data/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_grants/data/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/studio_status/data/repositories/studio_status_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/public_endpoint.dart';
import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/statement_repository.dart';
import 'package:libredb_mobile/infrastructure/studio/studio_timeouts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_env.dart';

/// Guards that the mock answers every request the app's repositories send in mock mode.
///
/// `MockInterceptor` fails a GET, POST, PUT or PATCH whose file under `assets/mock/` is missing with 501, so each
/// repository method is sent through the mock-backed [TestEnv.apiClient] and must succeed. Driving the real
/// repositories, instead of deriving file names from their source, sends the paths and parameters the repositories
/// build through the name resolution `MockInterceptor` uses, so the test cannot drift from either.
///
/// The methods sent before sign-in also run without a stored token: the mock answers a public endpoint without one, as
/// the server does, and rejects any other request without one with 401.
///
/// LibreDB Platform's repositories send through their own [PlatformApiClient], so they have their own table, driven
/// with [TestEnv.platformApiClient].
///
/// The last test fails when a repository that sends requests through [ApiClient] or [PlatformApiClient] gains a method
/// neither table drives.
void main() {
  // Keyed by test name; the part before the first space is the repository method.
  final requests = <String, Future<Result<Object?>> Function(ApiClient client)>{
    'IConnectionRepository.listManaged': (client) =>
        ConnectionRepository(client, ConnectionQueryTimeouts()).listManaged(),
    'IConnectionRepository.fetchPolicy': (client) =>
        ConnectionRepository(client, ConnectionQueryTimeouts()).fetchPolicy(),
    'IConnectionRepository.test': (client) =>
        ConnectionRepository(client, ConnectionQueryTimeouts()).test('seed:sales-db'),
    'IProviderMetaRepository.providerMeta': (client) => ProviderMetaRepository(client).providerMeta('seed:sales-db'),
    'IStudioIdentityRepository.fetch': (client) => StudioIdentityRepository(client).fetch(),
    'IStudioIdentityRepository.recordSignOut': (client) => StudioIdentityRepository(client).recordSignOut(),
    'IObjectBrowserRepository.containers': (client) => ObjectBrowserRepository(client).containers('seed:sales-db'),
    'IObjectBrowserRepository.counts': (client) =>
        ObjectBrowserRepository(client).counts('seed:sales-db', container: const ['public']),
    'IObjectBrowserRepository.list': (client) =>
        ObjectBrowserRepository(client).list('seed:sales-db', container: const ['public'], kind: 'table'),
    'IObjectBrowserRepository.describe': (client) =>
        ObjectBrowserRepository(client).describe('seed:sales-db', path: const ['public', 'orders'], kind: 'table'),
    'IObjectBrowserRepository.source': (client) =>
        ObjectBrowserRepository(client).source('seed:sales-db', path: const ['sales', 'order_totals'], kind: 'view'),
    'IObjectBrowserRepository.search': (client) =>
        ObjectBrowserRepository(client).search('seed:sales-db', term: 'order'),
    'IObjectBrowserRepository.scanKeys': (client) => ObjectBrowserRepository(client).scanKeys('seed:cache'),
    'IStatementRepository.run': (client) =>
        StatementRepository(client, ConnectionQueryTimeouts()).run('seed:sales-db', 'select 1'),
    'IStatementRepository.cancel': (client) =>
        StatementRepository(client, ConnectionQueryTimeouts()).cancel('seed:sales-db', 'q-1'),
    'ISqlEditorRepository.run': (client) => _sqlEditor(client).run('seed:sales-db', 'select 1'),
    'ISqlEditorRepository.runScript': (client) => _sqlEditor(client).runScript('seed:sales-db', 'select 1; select 2'),
    'ISqlEditorRepository.cancel': (client) => _sqlEditor(client).cancel('seed:sales-db', 'q-1'),
    'ISqlEditorRepository.beginTransaction': (client) => _sqlEditor(client).beginTransaction('seed:sales-db'),
    'ISqlEditorRepository.runInTransaction': (client) =>
        _sqlEditor(client).runInTransaction('seed:sales-db', 'select 1'),
    'ISqlEditorRepository.commit': (client) => _sqlEditor(client).commit('seed:sales-db'),
    'ISqlEditorRepository.rollback': (client) => _sqlEditor(client).rollback('seed:sales-db'),
    'ISqlEditorRepository.transactionStatus': (client) => _sqlEditor(client).transactionStatus('seed:sales-db'),
    'IStudioStatusRepository.liveness': (client) => StudioStatusRepository(client).liveness(),
    'IStudioStatusRepository.readiness': (client) => StudioStatusRepository(client).readiness(),
  };

  // Keyed like [requests]; later Platform repositories append their rows here.
  final platformRequests = <String, Future<Result<Object?>> Function(PlatformApiClient client)>{
    'IPlatformGrantRepository.list': (client) => PlatformGrantRepository(client).list('cm0connection000000000001'),
    'IPlatformGrantRepository.revoke': (client) =>
        PlatformGrantRepository(client).revoke('cm0connection000000000001', 'cm0grant000000000000000001'),
    'IPlatformIdentityRepository.fetch': (client) => PlatformIdentityRepository(client).fetch(),
    'IPlatformConnectionRepository.list': (client) => PlatformConnectionRepository(client).list(),
    'IPlatformDirectoryRepository.search': (client) => PlatformDirectoryRepository(client).search(query: '', page: 1),
    'IPlatformGrantRepository.put': (client) =>
        PlatformGrantRepository(client)
            .put('cm0connection000000000001', 'f:ldap-1:ken.ldap', level: 'read', expiresAt: null),
    'IPlatformConnectionRepository.setActive': (client) =>
        PlatformConnectionRepository(client).setActive('cm0conn0000000000000000001', active: false),
    'IPlatformAuditRepository.list': (client) =>
        PlatformAuditRepository(client).list(filter: const AuditFilter(), offset: 0),
    'IPlatformStatusRepository.liveness': (client) => PlatformStatusRepository(client).liveness(),
  };

  for (final MapEntry(key: name, value: send) in platformRequests.entries) {
    test('$name succeeds through the mock-backed Platform client', () async {
      TestEnv.authenticate();

      final result = await send(TestEnv.platformApiClient());

      expect(result, isA<Success<Object?>>(), reason: '$result');
    });
  }

  for (final MapEntry(key: name, value: send) in requests.entries) {
    test('$name succeeds through the mock-backed client', () async {
      TestEnv.authenticate();

      final result = await send(TestEnv.apiClient());

      expect(result, isA<Success<Object?>>(), reason: '$result');
    });
  }

  // Sent before sign-in: Studio's liveness and readiness. The sign-in itself goes to the identity provider.
  const sentBeforeSignIn = ['IStudioStatusRepository.liveness', 'IStudioStatusRepository.readiness'];
  for (final name in sentBeforeSignIn) {
    test('$name succeeds through the mock-backed client without a stored token', () async {
      final result = await requests[name]!(TestEnv.apiClient());

      expect(result, isA<Success<Object?>>(), reason: '$result');
    });
  }

  // Sent before sign-in: Platform's liveness, which the login page's Platform entry asks.
  const platformSentBeforeSignIn = ['IPlatformStatusRepository.liveness'];
  for (final name in platformSentBeforeSignIn) {
    test('$name succeeds through the mock-backed Platform client without a stored token', () async {
      final result = await platformRequests[name]!(TestEnv.platformApiClient());

      expect(result, isA<Success<Object?>>(), reason: '$result');
    });
  }

  // Every request path is relative to the API base URL, which ends in /api for the documented backend, so a path that
  // starts with /api/ reaches /api/api/ on the server.
  test('no request path the app sends starts with /api/', () async {
    final sentPaths = <String>{};
    for (final send in requests.values) {
      TestEnv.authenticate();
      final client = TestEnv.apiClient();
      client.instance.interceptors.insert(0, _PathRecordingInterceptor(sentPaths));
      await send(client);
    }
    for (final send in platformRequests.values) {
      TestEnv.authenticate();
      final client = TestEnv.platformApiClient();
      client.instance.interceptors.insert(0, _PathRecordingInterceptor(sentPaths));
      await send(client);
    }
    final paths = {...sentPaths, for (final endpoint in publicEndpoints) endpoint.path};

    expect(sentPaths, isNotEmpty);
    expect(paths.where((path) => path.startsWith('/api/')), isEmpty);
  });

  // MockInterceptor answers each action of POST /db/transaction from its own file, as Studio answers each in its own
  // shape, so a method that sent another action would read another answer and still succeed above.
  test('each /db/transaction method reads the recorded answer of its action', () async {
    const files = {
      'ISqlEditorRepository.beginTransaction': 'POST_db_transaction_begin.json',
      'ISqlEditorRepository.runInTransaction': 'POST_db_transaction_query.json',
      'ISqlEditorRepository.commit': 'POST_db_transaction_commit.json',
      'ISqlEditorRepository.rollback': 'POST_db_transaction_rollback.json',
      'ISqlEditorRepository.transactionStatus': 'POST_db_transaction_status.json',
    };
    for (final MapEntry(key: name, value: file) in files.entries) {
      final actions = <Object?>[];
      TestEnv.authenticate();
      final client = TestEnv.apiClient();
      client.instance.interceptors.insert(0, _ActionRecordingInterceptor(actions));

      expect(await requests[name]!(client), isA<Success<Object?>>(), reason: name);

      expect(actions, hasLength(1), reason: name);
      expect('POST_db_transaction_${actions.single}.json', file, reason: name);
      expect(File('assets/mock/$file').existsSync(), isTrue, reason: file);
    }
  });

  test('every method of a repository that sends requests through ApiClient or PlatformApiClient is driven above', () {
    final driven = [...requests.keys, ...platformRequests.keys].map((name) => name.split(' ').first).toSet();
    final methods = _apiClientRepositoryMethods();

    expect(methods.difference(driven), isEmpty, reason: 'Drive these methods above and add the mock files they need');
    expect(driven.difference(methods), isEmpty, reason: 'These entries match no repository method');
  });
}

SqlEditorRepository _sqlEditor(ApiClient client) {
  final queryTimeouts = ConnectionQueryTimeouts();
  return SqlEditorRepository(client, StatementRepository(client, queryTimeouts), queryTimeouts);
}

/// `Interface.method` for every method of a repository interface that a class importing [ApiClient] or
/// [PlatformApiClient] implements.
Set<String> _apiClientRepositoryMethods() {
  final sources = [
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart')) file.readAsStringSync(),
  ];
  final implemented = {
    for (final source in sources)
      if (source.contains("import 'package:libredb_mobile/infrastructure/http/api_client.dart';") ||
          source.contains("import 'package:libredb_mobile/infrastructure/platform/platform_api_client.dart';"))
        for (final match in RegExp(r'class \w+ implements (I\w+Repository)\b').allMatches(source)) match[1]!,
  };
  final declared = {
    for (final source in sources)
      for (final interface in RegExp(
        r'^abstract class (I\w+Repository) \{$(.*?)^\}',
        multiLine: true,
        dotAll: true,
      ).allMatches(source))
        interface[1]!: {
          for (final method in RegExp(r'^  Future<.*?> (\w+)\(', multiLine: true).allMatches(interface[2]!)) method[1]!,
        },
  };
  // The patterns above match how the interfaces are written today. One written another way would otherwise drop out
  // of the check without a failure.
  expect(implemented, isNotEmpty, reason: 'No class importing ApiClient implements an I*Repository interface');
  for (final interface in implemented) {
    expect(declared[interface], isNotEmpty, reason: 'Found no methods of $interface: extend the patterns to read it');
  }
  return {
    for (final interface in implemented)
      for (final method in declared[interface]!) '$interface.$method',
  };
}

/// Records the path of every request it sees, before the path parameters, as `MockInterceptor` resolves it.
class _PathRecordingInterceptor extends Interceptor {
  _PathRecordingInterceptor(this._paths);

  final Set<String> _paths;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _paths.add(options.extra['_basePath'] as String? ?? options.path);
    handler.next(options);
  }
}

/// Records the body's `action` of every `/db/transaction` request it sees.
class _ActionRecordingInterceptor extends Interceptor {
  _ActionRecordingInterceptor(this._actions);

  final List<Object?> _actions;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if ((options.extra['_basePath'] as String? ?? options.path) == '/db/transaction') {
      _actions.add((options.data as Map)['action']);
    }
    handler.next(options);
  }
}
