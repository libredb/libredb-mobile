import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_catalog_bloc.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/models/answered.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

void main() {
  const server = 'seed:dev-postgres-server';
  const postgres = 'seed:dev-postgres';
  const subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';
  const down = ServerError('down', code: 'studio.internal_error');

  late MockIContainersRepository containers;
  late MockIProviderMetaRepository providerMeta;
  late MockIActiveCatalogStore store;
  late ActiveCatalogCubit catalog;

  setUp(() {
    containers = MockIContainersRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(server))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres_server'))));
    when(() => providerMeta.providerMeta(postgres))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    when(() => containers.containers(server, refresh: any(named: 'refresh'))).thenAnswer(
      (_) async =>
          Success(Answered(ObjectBrowserJson.containers(_fixture('containers_postgres_server')), at: DateTime(2026))),
    );
    store = MockIActiveCatalogStore();
    when(() => store.read(any(), any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any(), any())).thenAnswer((_) async {});
    catalog = ActiveCatalogCubit(store: store, connectionIds: const Stream.empty());
  });

  tearDown(() => catalog.close());

  EditorCatalogBloc build(String connectionId) => EditorCatalogBloc(
    containers: containers,
    providerMeta: providerMeta,
    activeCatalog: catalog,
    connectionId: connectionId,
  );

  test('starts checking the engine', () {
    expect(build(server).state, const EditorCatalogChecking());
  });

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'a connection without catalogSessions lists nothing and names no database',
    build: () => build(postgres),
    act: (bloc) => bloc.add(const EditorCatalogRequested()),
    expect: () => const [EditorCatalogNotUsed()],
    verify: (bloc) {
      verifyNever(() => containers.containers(any(), refresh: any(named: 'refresh')));
      expect(bloc.state.catalogToSend(catalog.catalogOf(postgres)), isNull);
      expect(bloc.state.withholdsRun(null), isFalse);
    },
  );

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'lists the server\'s databases under the level\'s own label and makes the first listed active',
    build: () => build(server),
    act: (bloc) => bloc.add(const EditorCatalogRequested()),
    expect: () => const [
      EditorCatalogLoading(label: 'Database'),
      EditorCatalogListed(label: 'Database', catalogs: ['app', 'archive', 'postgres']),
    ],
    verify: (bloc) {
      expect(catalog.catalogOf(server), 'app');
      expect(bloc.state.catalogToSend('app'), 'app');
      expect(bloc.state.withholdsRun('app'), isFalse);
    },
  );

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'keeps the database chosen in this session while the server lists it',
    setUp: () => catalog.choose(server, 'archive'),
    build: () => build(server),
    act: (bloc) => bloc.add(const EditorCatalogRequested()),
    skip: 1,
    expect: () => const [
      EditorCatalogListed(label: 'Database', catalogs: ['app', 'archive', 'postgres']),
    ],
    verify: (_) => expect(catalog.catalogOf(server), 'archive'),
  );

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'chooses the remembered database while the server lists it',
    setUp: () {
      when(() => store.read(subject, server)).thenAnswer((_) async => 'postgres');
      catalog.signedIn(subject);
    },
    build: () => build(server),
    act: (bloc) => bloc.add(const EditorCatalogRequested()),
    skip: 1,
    expect: () => const [
      EditorCatalogListed(label: 'Database', catalogs: ['app', 'archive', 'postgres']),
    ],
    verify: (_) => expect(catalog.catalogOf(server), 'postgres'),
  );

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'a failed list keeps Run back, and a retry reads it again',
    setUp: () {
      var calls = 0;
      when(() => containers.containers(server, refresh: any(named: 'refresh'))).thenAnswer((_) async {
        if (++calls == 1) return const Failure(down);
        return Success(
          Answered(ObjectBrowserJson.containers(_fixture('containers_postgres_server')), at: DateTime(2026)),
        );
      });
    },
    build: () => build(server),
    act: (bloc) async {
      bloc.add(const EditorCatalogRequested());
      await bloc.stream.firstWhere((s) => s is EditorCatalogFailure);
      expect(bloc.state.withholdsRun(null), isTrue);
      bloc.add(const EditorCatalogRequested());
    },
    expect: () => const [
      EditorCatalogLoading(label: 'Database'),
      EditorCatalogFailure(error: down, label: 'Database'),
      EditorCatalogLoading(label: 'Database'),
      EditorCatalogListed(label: 'Database', catalogs: ['app', 'archive', 'postgres']),
    ],
  );

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'a provider-meta failure keeps Run back with a retry',
    setUp: () => when(() => providerMeta.providerMeta(server)).thenAnswer((_) async => const Failure(down)),
    build: () => build(server),
    act: (bloc) => bloc.add(const EditorCatalogRequested()),
    expect: () => const [EditorCatalogFailure(error: down)],
  );

  blocTest<EditorCatalogBloc, EditorCatalogState>(
    'a server that lists no database leaves none active and keeps Run back',
    setUp: () =>
        when(() => containers.containers(server, refresh: any(named: 'refresh')))
            .thenAnswer((_) async => Success(Answered(const [], at: DateTime(2026)))),
    build: () => build(server),
    act: (bloc) => bloc.add(const EditorCatalogRequested()),
    skip: 1,
    expect: () => const [EditorCatalogListed(label: 'Database', catalogs: [])],
    verify: (bloc) {
      expect(catalog.catalogOf(server), isNull);
      expect(bloc.state.withholdsRun(null), isTrue);
    },
  );
}
