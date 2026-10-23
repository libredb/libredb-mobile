import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

void main() {
  const subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';
  const server = 'seed:dev-postgres-server';
  const other = 'seed:other-server';

  late MockIActiveCatalogStore store;
  late StreamController<String?> connectionIds;

  setUp(() {
    store = MockIActiveCatalogStore();
    when(() => store.read(any(), any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any(), any())).thenAnswer((_) async {});
    connectionIds = StreamController<String?>.broadcast();
  });

  tearDown(() => connectionIds.close());

  ActiveCatalogCubit build() => ActiveCatalogCubit(store: store, connectionIds: connectionIds.stream);

  test('starts with no database', () {
    final cubit = build();
    expect(cubit.state, const ActiveCatalogNone());
    expect(cubit.catalogOf(server), isNull);
  });

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'a choice becomes the active database of its connection and is stored for the signed-in subject',
    build: build,
    act: (cubit) {
      cubit.signedIn(subject);
      cubit.choose(server, 'archive');
    },
    expect: () => const [ActiveCatalogChosen(connectionId: server, catalog: 'archive')],
    verify: (cubit) {
      expect(cubit.catalogOf(server), 'archive');
      expect(cubit.catalogOf(other), isNull);
      verify(() => store.write(subject, server, 'archive')).called(1);
    },
  );

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'choosing the active database again emits and stores nothing',
    build: build,
    seed: () => const ActiveCatalogChosen(connectionId: server, catalog: 'app'),
    act: (cubit) {
      cubit.signedIn(subject);
      cubit.choose(server, 'app');
    },
    expect: () => const <ActiveCatalogState>[],
    verify: (_) => verifyNever(() => store.write(any(), any(), any())),
  );

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'without a subject Studio named, a choice applies and nothing is stored',
    build: build,
    act: (cubit) {
      cubit.signedIn(null);
      cubit.choose(server, 'archive');
    },
    expect: () => const [ActiveCatalogChosen(connectionId: server, catalog: 'archive')],
    verify: (_) => verifyNever(() => store.write(any(), any(), any())),
  );

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'a choice the device refuses to store still applies',
    setUp: () => when(() => store.write(any(), any(), any())).thenThrow(StateError('refused')),
    build: build,
    act: (cubit) {
      cubit.signedIn(subject);
      cubit.choose(server, 'archive');
    },
    expect: () => const [ActiveCatalogChosen(connectionId: server, catalog: 'archive')],
  );

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'a switch to another connection clears the active database',
    build: build,
    seed: () => const ActiveCatalogChosen(connectionId: server, catalog: 'archive'),
    act: (_) async {
      connectionIds.add(server);
      await Future<void>.delayed(Duration.zero);
      connectionIds.add(other);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [ActiveCatalogNone()],
  );

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'closing the connection clears the active database',
    build: build,
    seed: () => const ActiveCatalogChosen(connectionId: server, catalog: 'archive'),
    act: (_) async {
      connectionIds.add(null);
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const [ActiveCatalogNone()],
  );

  blocTest<ActiveCatalogCubit, ActiveCatalogState>(
    'the end of the session clears the active database and forgets the subject',
    build: build,
    act: (cubit) async {
      cubit.signedIn(subject);
      cubit.choose(server, 'archive');
      cubit.clear();
      cubit.choose(server, 'app');
      expect(await cubit.remembered(server), isNull);
    },
    expect: () => const [
      ActiveCatalogChosen(connectionId: server, catalog: 'archive'),
      ActiveCatalogNone(),
      ActiveCatalogChosen(connectionId: server, catalog: 'app'),
    ],
    verify: (_) {
      verify(() => store.write(subject, server, 'archive')).called(1);
      verifyNever(() => store.write(any(), any(), 'app'));
      verifyNever(() => store.read(any(), any()));
    },
  );

  group('remembered', () {
    test('reads the database stored for the subject on the connection', () async {
      when(() => store.read(subject, server)).thenAnswer((_) async => 'archive');
      final cubit = build()..signedIn(subject);

      expect(await cubit.remembered(server), 'archive');
    });

    test('is null before Studio names a subject', () async {
      expect(await build().remembered(server), isNull);
      verifyNever(() => store.read(any(), any()));
    });

    test('is null when the stored value cannot be read', () async {
      when(() => store.read(subject, server)).thenThrow(const FormatException('not JSON'));
      final cubit = build()..signedIn(subject);

      expect(await cubit.remembered(server), isNull);
    });
  });
}
