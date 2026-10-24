import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/di/app_dependencies.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
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
};

const _subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';

void main() {
  late MockIStatementTextStore statementText;
  late MockIFavoriteConnectionsRepository favorites;
  late MockIActiveConnectionStore activeConnection;
  late MockIActiveCatalogStore activeCatalog;
  late MockICollapsedSectionsRepository collapsedSections;
  late UserDataRegistry registry;

  setUp(() {
    statementText = MockIStatementTextStore();
    favorites = MockIFavoriteConnectionsRepository();
    activeConnection = MockIActiveConnectionStore();
    activeCatalog = MockIActiveCatalogStore();
    collapsedSections = MockICollapsedSectionsRepository();
    when(() => statementText.clearSubject(any())).thenAnswer((_) async => const Success(null));
    when(() => favorites.clear(any())).thenAnswer((_) async {});
    when(() => activeConnection.write(any(), any())).thenAnswer((_) async {});
    when(() => activeCatalog.clear(any())).thenAnswer((_) async {});
    when(() => collapsedSections.clear()).thenAnswer((_) async {});
    registry = _dependencies.createUserDataRegistry(
      statementText: statementText,
      favorites: favorites,
      activeConnection: activeConnection,
      activeCatalog: activeCatalog,
      collapsedSections: collapsedSections,
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

    for (final store in registry.stores) {
      cleared.clear();
      await store.clear(_subject);

      final expected = switch (store.name) {
        'statement_text' => 'clearSubject ${subjectHash(_subject)}',
        'connection_favorites' => 'clear $_subject',
        'active_connection' => 'write $_subject null',
        'active_catalog' => 'clear $_subject',
        'connection_sections_collapsed' => 'clear',
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
