import 'dart:io';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/account/data/models/change_password.dart';
import 'package:libredb_mobile/features/account/data/repositories/account_repository.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libredb_mobile/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/features/auth/domain/entities/auth_entity.dart';
import 'package:libredb_mobile/features/connections/data/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/object_browser/data/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/lifecycle/data/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/public_endpoint.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';
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
/// The last test fails when a repository that sends requests through [ApiClient] gains a method the table does not
/// drive.
void main() {
  // Keyed by test name; the part before the first space is the repository method.
  final requests = <String, Future<Result<Object?>> Function(ApiClient client)>{
    'IAccountRepository.register': (client) =>
        AccountRepository(client).register(const UserEntity(email: 'new.user@sample.tech')),
    'IAccountRepository.changePassword': (client) =>
        AccountRepository(client)
            .changePassword(const PasswordChangeDTO(currentPassword: 'password', newPassword: 'new_password')),
    'IAccountRepository.resetPassword': (client) => AccountRepository(client).resetPassword('admin@sample.tech'),
    'IAccountRepository.getAccount': (client) => AccountRepository(client).getAccount(),
    'IAuthRepository.authenticate': (client) =>
        LoginRepository(apiClient: client)
            .authenticate(const AuthCredentialsEntity(username: 'admin', password: 'admin')),
    'IAuthRepository.logout': (client) => LoginRepository(apiClient: client).logout(),
    'IAuthRepository.sendOtp': (client) =>
        LoginRepository(apiClient: client).sendOtp(const SendOtpEntity(email: 'admin@sample.tech')),
    'IAuthRepository.verifyOtp': (client) =>
        LoginRepository(apiClient: client).verifyOtp(const VerifyOtpEntity(email: 'admin@sample.tech', otp: '123456')),
    'IConnectionRepository.listManaged': (client) => ConnectionRepository(client).listManaged(),
    'IConnectionRepository.fetchPolicy': (client) => ConnectionRepository(client).fetchPolicy(),
    'IConnectionRepository.test': (client) => ConnectionRepository(client).test('seed:sales-db'),
    'IProviderMetaRepository.providerMeta': (client) => ProviderMetaRepository(client).providerMeta('seed:sales-db'),
    'IStudioIdentityRepository.fetch': (client) => StudioIdentityRepository(client).fetch(),
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
    'ISqlEditorRepository.run': (client) => SqlEditorRepository(client).run('seed:sales-db', 'select 1'),
    'ISqlEditorRepository.runScript': (client) =>
        SqlEditorRepository(client).runScript('seed:sales-db', 'select 1; select 2'),
    'ISqlEditorRepository.cancel': (client) => SqlEditorRepository(client).cancel('seed:sales-db', 'q-1'),
    'ISqlEditorRepository.beginTransaction': (client) => SqlEditorRepository(client).beginTransaction('seed:sales-db'),
    'ISqlEditorRepository.runInTransaction': (client) =>
        SqlEditorRepository(client).runInTransaction('seed:sales-db', 'select 1'),
    'ISqlEditorRepository.commit': (client) => SqlEditorRepository(client).commit('seed:sales-db'),
    'ISqlEditorRepository.rollback': (client) => SqlEditorRepository(client).rollback('seed:sales-db'),
    'ISqlEditorRepository.transactionStatus': (client) =>
        SqlEditorRepository(client).transactionStatus('seed:sales-db'),
    'ILifecycleRepository.fetchAppConfig': (client) => LifecycleRepository(client).fetchAppConfig(),
  };

  for (final MapEntry(key: name, value: send) in requests.entries) {
    test('$name succeeds through the mock-backed client', () async {
      TestEnv.authenticate();

      final result = await send(TestEnv.apiClient());

      expect(result, isA<Success<Object?>>(), reason: '$result');
    });
  }

  // Sent before sign-in: sign-in, the OTP sign-in, registration and password reset, and the app config the lifecycle
  // checks read.
  const sentBeforeSignIn = [
    'IAuthRepository.authenticate',
    'IAuthRepository.sendOtp',
    'IAuthRepository.verifyOtp',
    'IAccountRepository.register',
    'IAccountRepository.resetPassword',
    'ILifecycleRepository.fetchAppConfig',
  ];
  for (final name in sentBeforeSignIn) {
    test('$name succeeds through the mock-backed client without a stored token', () async {
      final result = await requests[name]!(TestEnv.apiClient());

      expect(result, isA<Success<Object?>>(), reason: '$result');
    });
  }

  // Every request path is relative to the API base URL, which ends in /api for the documented backend, so a path that
  // starts with /api/ reaches /api/api/ on the server.
  test('no request path the app sends starts with /api/', () async {
    final sentPaths = <String>{};
    for (final send in requests.values) {
      // The sign-out of IAuthRepository.logout ends the session the next request needs.
      TestEnv.authenticate();
      final client = TestEnv.apiClient();
      client.instance.interceptors.insert(0, _PathRecordingInterceptor(sentPaths));
      await send(client);
    }
    final paths = {...sentPaths, refreshEndpointPath, for (final endpoint in publicEndpoints) endpoint.path};

    expect(sentPaths, isNotEmpty);
    expect(paths.where((path) => path.startsWith('/api/')), isEmpty);
  });

  test('every method of a repository that sends requests through ApiClient is driven above', () {
    final driven = requests.keys.map((name) => name.split(' ').first).toSet();
    final methods = _apiClientRepositoryMethods();

    expect(methods.difference(driven), isEmpty, reason: 'Drive these methods above and add the mock files they need');
    expect(driven.difference(methods), isEmpty, reason: 'These entries match no repository method');
  });
}

/// `Interface.method` for every method of a repository interface that a class importing [ApiClient] implements.
Set<String> _apiClientRepositoryMethods() {
  final sources = [
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart')) file.readAsStringSync(),
  ];
  final implemented = {
    for (final source in sources)
      if (source.contains("import 'package:libredb_mobile/infrastructure/http/api_client.dart';"))
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
