import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/features/auth/data/repositories/auth_session_repository_impl.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/infrastructure/storage/temporary_share_files.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mock_classes.dart';

/// The interfaces of the stores that keep data of a signed-in account on this device, past the session.
const _perAccountInterfaces = [
  'IStatementTextStore',
  'IFavoriteConnectionsRepository',
  'IActiveConnectionStore',
  'IActiveCatalogStore',
];

/// Each class under `lib/` that implements one of [_perAccountInterfaces], with the registry entry that clears it.
///
/// A new implementation fails the first test until it is listed here and its data is cleared by an entry.
const _knownImplementations = {
  'StatementTextStore': 'statement_text',
  'FavoriteConnectionsRepository': 'connection_favorites',
  'ActiveConnectionPreferences': 'active_connection',
  'ActiveCatalogPreferences': 'active_catalog',
};

/// The device preferences that hold no data of an account, which 'Remove my data' keeps.
const _devicePreferences = {
  StorageKeys.language,
  StorageKeys.theme,
  StorageKeys.brightness,
  StorageKeys.resultViewMode,
  StorageKeys.appLockEnabled,
  StorageKeys.appLockTimeout,
};

/// The values of [SecureStorageKeys], each a value of the session (its tokens and its target), which every sign-out
/// deletes. A secure value kept per account past the session is named by its store instead, as the statement text keys
/// are.
const _sessionValues = {
  SecureStorageKeys.jwtToken,
  SecureStorageKeys.refreshToken,
  SecureStorageKeys.oidcIdToken,
  SecureStorageKeys.accessTokenExpiresAt,
  SecureStorageKeys.sessionTarget,
};

/// The files under `lib/` that reach the device's directories through path_provider, with the registry entry that
/// clears what each keeps there. A new directory fails the guard until it is listed here and cleared.
const _directoryUsers = {
  'lib/infrastructure/storage/encrypted_text_file_store.dart': 'statement_text',
  'lib/infrastructure/storage/temporary_share_files.dart': 'share_files',
};

/// Whom what a file keeps through the device stores belongs to.
sealed class _Keeps {
  const _Keeps();
}

/// Data of an account past the session, cleared by the registry entry [name].
final class _Entry extends _Keeps {
  const _Entry(this.name);
  final String name;
}

/// Session storage, which every sign-out deletes: the tokens and the cache of GET responses.
final class _Session extends _Keeps {
  const _Session();
}

/// Device storage that holds no data of an account: the language, the theme, the result view mode, the app lock.
final class _Device extends _Keeps {
  const _Device();
}

/// Passes a store on, or shows what the stores hold, and keeps nothing of its own.
final class _NoneOfItsOwn extends _Keeps {
  const _NoneOfItsOwn();
}

/// Every file under `lib/` that imports the secure store, the device preferences or shared_preferences, with what it
/// keeps there. A new file fails the guard until it is named here, so a store that writes under a key of its own, such
/// as `'notes_$subject'`, cannot pass unseen.
const _storageUsers = <String, _Keeps>{
  'lib/infrastructure/storage/encrypted_text_file_store.dart': _Entry('statement_text'),
  'lib/features/connections/data/repositories/favorite_connections_repository.dart': _Entry('connection_favorites'),
  'lib/infrastructure/storage/active_connection_preferences.dart': _Entry('active_connection'),
  'lib/infrastructure/storage/active_catalog_preferences.dart': _Entry('active_catalog'),
  'lib/features/connections/data/repositories/collapsed_sections_repository.dart': _Entry(
    'connection_sections_collapsed',
  ),
  'lib/features/auth/data/repositories/auth_session_repository_impl.dart': _Session(),
  'lib/features/auth/data/repositories/sso_sign_out_auth_repository.dart': _Session(),
  'lib/features/auth/data/services/sso_session_startup_impl.dart': _Session(),
  'lib/app/session/session_cubit.dart': _Session(),
  'lib/infrastructure/auth/oidc/oidc_token_rotation.dart': _Session(),
  'lib/infrastructure/cache/shared_prefs_cache_storage.dart': _Session(),
  'lib/infrastructure/http/api_client.dart': _Session(),
  'lib/infrastructure/platform/platform_api_client.dart': _Session(),
  'lib/infrastructure/http/interceptors/auth_interceptor.dart': _Session(),
  'lib/infrastructure/http/interceptors/token_refresh_interceptor.dart': _Session(),
  'lib/app/localization/locale_cubit.dart': _Device(),
  'lib/app/theme/theme_bloc.dart': _Device(),
  'lib/app/bootstrap/app_bootstrap.dart': _Device(),
  'lib/infrastructure/storage/result_view_mode_preferences.dart': _Device(),
  'lib/features/app_lock/data/repositories/app_lock_settings_preferences.dart': _Device(),
  'lib/infrastructure/storage/local_storage.dart': _Device(),
  'lib/app/app.dart': _NoneOfItsOwn(),
  'lib/app/di/app_dependencies.dart': _NoneOfItsOwn(),
  'lib/app/di/app_scope.dart': _NoneOfItsOwn(),
  'lib/app/dev_console/tabs/storage_tab.dart': _NoneOfItsOwn(),
};

const _subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';

void main() {
  late MockIStatementTextStore statementText;
  late MockIFavoriteConnectionsRepository favorites;
  late MockIActiveConnectionStore activeConnection;
  late MockIActiveCatalogStore activeCatalog;
  late MockICollapsedSectionsRepository collapsedSections;
  late MockTemporaryShareFiles shareFiles;
  late UserDataRegistry registry;

  setUp(() {
    statementText = MockIStatementTextStore();
    favorites = MockIFavoriteConnectionsRepository();
    activeConnection = MockIActiveConnectionStore();
    activeCatalog = MockIActiveCatalogStore();
    collapsedSections = MockICollapsedSectionsRepository();
    shareFiles = MockTemporaryShareFiles();
    when(() => statementText.clearSubject(any())).thenAnswer((_) async => const Success(null));
    when(() => favorites.clear(any())).thenAnswer((_) async {});
    when(() => activeConnection.write(any(), any())).thenAnswer((_) async {});
    when(() => activeCatalog.clear(any())).thenAnswer((_) async {});
    when(() => collapsedSections.clear()).thenAnswer((_) async {});
    when(() => shareFiles.clear()).thenAnswer((_) async {});
    registry = _dependencies.createUserDataRegistry(
      statementText: statementText,
      favorites: favorites,
      activeConnection: activeConnection,
      activeCatalog: activeCatalog,
      collapsedSections: collapsedSections,
      shareFiles: shareFiles,
    );
  });

  test('every class that keeps per-account data is known and is the one the app builds', () {
    final found = _implementationsOf(_perAccountInterfaces);

    expect(
      found,
      _knownImplementations.keys.toSet(),
      reason:
          'A class that keeps data of a signed-in account must be cleared by "Remove my data": add an entry to '
          'AppDependencies.createUserDataRegistry and list the class in _knownImplementations',
    );
    expect(
      [
        _dependencies.createStatementTextStore(MockISecureStorage()),
        _dependencies.createFavoriteConnectionsRepository(),
        _dependencies.createActiveConnectionStore(),
        _dependencies.createActiveCatalogStore(),
      ].map((store) => store.runtimeType.toString()).toSet(),
      _knownImplementations.keys.toSet(),
    );
  });

  test('lists the known stores, each once', () {
    expect(registry.stores.map((store) => store.name), [
      ..._knownImplementations.values,
      StorageKeys.connectionSectionsCollapsed.key,
      'share_files',
    ]);
  });

  test('each entry clears its own store for the subject and nothing else', () async {
    final cleared = <String, List<String>>{};
    void record(String name, String what) => (cleared[name] ??= []).add(what);
    when(() => statementText.clearSubject(any())).thenAnswer((invocation) async {
      record('statement_text', 'clearSubject ${invocation.positionalArguments.single}');
      return const Success(null);
    });
    when(() => favorites.clear(any())).thenAnswer((invocation) async {
      record('connection_favorites', 'clear ${invocation.positionalArguments.single}');
    });
    when(() => activeConnection.write(any(), any())).thenAnswer((invocation) async {
      record('active_connection', 'write ${invocation.positionalArguments.join(' ')}');
    });
    when(() => activeCatalog.clear(any())).thenAnswer((invocation) async {
      record('active_catalog', 'clear ${invocation.positionalArguments.single}');
    });
    when(() => collapsedSections.clear()).thenAnswer((_) async => record('connection_sections_collapsed', 'clear'));
    when(() => shareFiles.clear()).thenAnswer((_) async => record('share_files', 'clear'));

    for (final store in registry.stores) {
      cleared.clear();
      await store.clear(_subject);

      final expected = switch (store.name) {
        'statement_text' => 'clearSubject ${subjectHash(_subject)}',
        'connection_favorites' => 'clear $_subject',
        'active_connection' => 'write $_subject null',
        'active_catalog' => 'clear $_subject',
        'connection_sections_collapsed' => 'clear',
        'share_files' => 'clear',
        _ => fail('no expectation for ${store.name}'),
      };
      expect(cleared, {
        store.name: [expected],
      });
    }
  });

  test('the statement text entry throws when the store answers a failure', () async {
    when(() => statementText.clearSubject(any())).thenAnswer((_) async => const Failure(UnknownError('refused')));

    final entry = registry.stores.singleWhere((store) => store.name == 'statement_text');

    await expectLater(entry.clear(_subject), throwsA(isA<UnknownError>()));
  });

  test('the share files entry throws when the device refuses the removal', () async {
    when(() => shareFiles.clear()).thenAnswer((_) async => throw const FileSystemException('refused'));

    final entry = registry.stores.singleWhere((store) => store.name == 'share_files');

    await expectLater(entry.clear(_subject), throwsA(isA<FileSystemException>()));
  });

  // The share files hold an account's data only for one share, so the session wipe of every sign-out removes them too,
  // not only 'Remove my data'.
  test('the session wipe of every sign-out removes the share files', () async {
    final shared = await TemporaryShareFiles().write('order_totals-definition.sql', [1]);

    final result = await _dependencies.createAuthSessionRepository(_MemorySecureStorage()).clear();

    expect(result, isA<Success<void>>());
    expect(shared.existsSync(), isFalse);
  });

  test('every device preference key is either cleared by an entry or named a device preference', () {
    final registered = registry.stores.map((store) => store.name).toSet();

    for (final key in StorageKeys.values) {
      expect(
        registered.contains(key.key) != _devicePreferences.contains(key),
        isTrue,
        reason:
            '${key.name} must be either cleared by "Remove my data" (an entry named "${key.key}" in '
            'AppDependencies.createUserDataRegistry) or listed in _devicePreferences, not both',
      );
    }
  });

  // With the StorageKeys test above, these two close the other ways a store can keep data on the phone, so a new
  // per-account store behind an interface of its own fails one of them.
  test('every secure storage key is a session value, which a sign-out deletes', () async {
    expect(
      SecureStorageKeys.values.toSet(),
      _sessionValues,
      reason:
          'A new SecureStorageKeys value must be a session value deleted by AuthSessionRepository.clear, or be kept '
          'by a store that "Remove my data" clears',
    );
    final secure = _MemorySecureStorage();
    for (final key in SecureStorageKeys.values) {
      await secure.write(key.key, 'value');
    }

    await AuthSessionRepository(secureStorage: secure).clear();

    expect(secure.values, isEmpty);
  });

  test('only the listed files reach the device directories, and an entry clears each', () {
    final importer = RegExp(r'''^import\s+['"]package:path_provider/''', multiLine: true);
    final found = {
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && importer.hasMatch(file.readAsStringSync())) file.path.replaceAll(r'\', '/'),
    };

    expect(
      found,
      _directoryUsers.keys.toSet(),
      reason:
          'A file that keeps data in a device directory must be cleared by "Remove my data": add an entry to '
          'AppDependencies.createUserDataRegistry and list the file in _directoryUsers',
    );
    expect(registry.stores.map((store) => store.name), containsAll(_directoryUsers.values));
  });

  // Platform mode keeps no data of an account: a Platform file that starts to reach a device store fails here first.
  test('no Platform file reaches the secure store, the device preferences or the device directories', () {
    bool isPlatform(String path) =>
        path.startsWith('lib/features/platform_') ||
        path == 'lib/app/shell/platform_shell.dart' ||
        path == 'lib/app/shell/app_platform_identity_scope.dart';

    expect([..._storageUsers.keys, ..._directoryUsers.keys].where(isPlatform), isEmpty);
    for (final path in ['lib/app/shell/platform_shell.dart', 'lib/app/shell/app_platform_identity_scope.dart']) {
      expect(File(path).existsSync(), isTrue, reason: '$path is the file this guard names');
    }
  });

  test('every file that reaches the secure store or the device preferences is named with what it keeps', () {
    final importer = RegExp(
      r'''^import\s+['"](?:package:shared_preferences/|[^'"]*(?:/|^)(?:secure_storage|local_storage)\.dart['"])''',
      multiLine: true,
    );
    final found = {
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            !file.path.contains('/generated/') &&
            importer.hasMatch(file.readAsStringSync()))
          file.path.replaceAll(r'\', '/'),
    };

    expect(
      found,
      _storageUsers.keys.toSet(),
      reason:
          'A file that keeps data through ISecureStorage, AppLocalStorage or shared_preferences must be named in '
          '_storageUsers: with the registry entry that clears it, or as session or device storage',
    );
    final names = registry.stores.map((store) => store.name).toSet();
    for (final MapEntry(:key, :value) in _storageUsers.entries) {
      if (value case _Entry(:final name)) expect(names, contains(name), reason: key);
    }
  });
}

final _dependencies = AppDependencies(
  authMode: OidcAuthMode(OidcSettings(issuer: Uri.parse('https://id.example.test/realms/demo'), clientId: 'app')),
);

/// The names of the classes under `lib/` that implement one of [interfaces].
Set<String> _implementationsOf(List<String> interfaces) {
  final declaration = RegExp(r'class\s+(\w+)[^{]*\bimplements\s+([^{]+)\{');
  final found = <String>{};
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('/generated/')) continue;
    for (final match in declaration.allMatches(file.readAsStringSync())) {
      final implemented = match[2]!.split(',').map((type) => type.trim().split('<').first);
      if (implemented.any(interfaces.contains)) found.add(match[1]!);
    }
  }
  return found;
}

class _MemorySecureStorage implements ISecureStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}
