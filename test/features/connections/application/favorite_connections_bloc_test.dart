import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  const alice = 'subject-alice';
  const bob = 'subject-bob';

  late MockIFavoriteConnectionsRepository repository;

  setUp(() {
    repository = MockIFavoriteConnectionsRepository();
    when(() => repository.read(any())).thenAnswer((_) async => ConnectionFavorites.empty);
    when(() => repository.write(any(), any())).thenAnswer((_) async {});
  });

  FavoriteConnectionsBloc build() => FavoriteConnectionsBloc(repository: repository);

  test('starts without favorites, as nobody is signed in yet', () {
    expect(build().state, const FavoriteConnectionsNone());
  });

  blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
    'reads the favorites of the signed-in subject',
    setUp: () =>
        when(() => repository.read(alice))
            .thenAnswer((_) async => const ConnectionFavorites(starred: {'seed:a'}, recent: ['seed:b'])),
    build: build,
    act: (bloc) => bloc.add(const FavoriteConnectionsSubjectChanged(alice)),
    expect: () => const [
      FavoriteConnectionsLoading(),
      FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a'}, recent: ['seed:b'])),
    ],
  );

  blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
    'shows no favorites when the stored ones cannot be read',
    setUp: () => when(() => repository.read(alice)).thenThrow(const FormatException('not JSON')),
    build: build,
    act: (bloc) => bloc.add(const FavoriteConnectionsSubjectChanged(alice)),
    expect: () => const [FavoriteConnectionsLoading(), FavoriteConnectionsUnavailable()],
  );

  blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
    'shows no favorites for a user Studio names no subject for, and reads nothing',
    build: build,
    act: (bloc) => bloc.add(const FavoriteConnectionsSubjectChanged(null)),
    expect: () => const <FavoriteConnectionsState>[],
    verify: (_) => verifyNever(() => repository.read(any())),
  );

  blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
    'a second account sees its own favorites, never those of the first',
    setUp: () {
      when(() => repository.read(alice))
          .thenAnswer((_) async => const ConnectionFavorites(starred: {'seed:a'}, recent: ['seed:a']));
      when(() => repository.read(bob)).thenAnswer((_) async => ConnectionFavorites.empty);
    },
    build: build,
    act: (bloc) => bloc
      ..add(const FavoriteConnectionsSubjectChanged(alice))
      ..add(const FavoriteConnectionsSubjectChanged(null))
      ..add(const FavoriteConnectionsSubjectChanged(bob))
      ..add(const FavoriteConnectionStarToggled('seed:b')),
    expect: () => const [
      FavoriteConnectionsLoading(),
      FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a'}, recent: ['seed:a'])),
      FavoriteConnectionsNone(),
      FavoriteConnectionsLoading(),
      FavoriteConnectionsReady(ConnectionFavorites.empty),
      FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:b'}, recent: [])),
    ],
    verify: (_) {
      verify(() => repository.write(bob, const ConnectionFavorites(starred: {'seed:b'}, recent: []))).called(1);
      verifyNever(() => repository.write(alice, any()));
    },
  );

  blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
    'the same subject again keeps the favorites without reading them again',
    build: build,
    act: (bloc) => bloc
      ..add(const FavoriteConnectionsSubjectChanged(alice))
      ..add(const FavoriteConnectionsSubjectChanged(alice)),
    expect: () => const [FavoriteConnectionsLoading(), FavoriteConnectionsReady(ConnectionFavorites.empty)],
    verify: (_) => verify(() => repository.read(alice)).called(1),
  );

  group('star toggling', () {
    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'stars a connection, then unstars it, storing each change for the subject',
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionStarToggled('seed:a'))
        ..add(const FavoriteConnectionStarToggled('seed:b'))
        ..add(const FavoriteConnectionStarToggled('seed:a')),
      expect: () => const [
        FavoriteConnectionsLoading(),
        FavoriteConnectionsReady(ConnectionFavorites.empty),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a'}, recent: [])),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a', 'seed:b'}, recent: [])),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:b'}, recent: [])),
      ],
      verify: (_) {
        verifyInOrder([
          () => repository.write(alice, const ConnectionFavorites(starred: {'seed:a'}, recent: [])),
          () => repository.write(alice, const ConnectionFavorites(starred: {'seed:a', 'seed:b'}, recent: [])),
          () => repository.write(alice, const ConnectionFavorites(starred: {'seed:b'}, recent: [])),
        ]);
      },
    );

    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'keeps the star of a connection the managed list no longer has',
      setUp: () =>
          when(() => repository.read(alice))
              .thenAnswer((_) async => const ConnectionFavorites(starred: {'seed:gone'}, recent: [])),
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionStarToggled('seed:a')),
      expect: () => const [
        FavoriteConnectionsLoading(),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:gone'}, recent: [])),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:gone', 'seed:a'}, recent: [])),
      ],
    );

    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'a star the device refuses to store still shows until the app closes',
      setUp: () => when(() => repository.write(any(), any())).thenThrow(StateError('refused')),
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionStarToggled('seed:a')),
      expect: () => const [
        FavoriteConnectionsLoading(),
        FavoriteConnectionsReady(ConnectionFavorites.empty),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a'}, recent: [])),
      ],
    );

    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'a star while the favorites cannot be read changes and stores nothing',
      setUp: () => when(() => repository.read(alice)).thenThrow(const FormatException('not JSON')),
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionStarToggled('seed:a'))
        ..add(const FavoriteConnectionOpened('seed:a')),
      expect: () => const [FavoriteConnectionsLoading(), FavoriteConnectionsUnavailable()],
      verify: (_) => verifyNever(() => repository.write(any(), any())),
    );

    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'a star sent while the favorites are read applies to them once they arrive',
      setUp: () {
        final stored = Completer<ConnectionFavorites>();
        when(() => repository.read(alice)).thenAnswer((_) => stored.future);
        Future<void>.delayed(
          Duration.zero,
          () => stored.complete(const ConnectionFavorites(starred: {'seed:a'}, recent: [])),
        );
      },
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionStarToggled('seed:b')),
      wait: const Duration(milliseconds: 10),
      expect: () => const [
        FavoriteConnectionsLoading(),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a'}, recent: [])),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {'seed:a', 'seed:b'}, recent: [])),
      ],
    );
  });

  group('recent ordering', () {
    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'puts the connection opened last first and lists each connection once',
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionOpened('seed:a'))
        ..add(const FavoriteConnectionOpened('seed:b'))
        ..add(const FavoriteConnectionOpened('seed:a')),
      expect: () => const [
        FavoriteConnectionsLoading(),
        FavoriteConnectionsReady(ConnectionFavorites.empty),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {}, recent: ['seed:a'])),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {}, recent: ['seed:b', 'seed:a'])),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {}, recent: ['seed:a', 'seed:b'])),
      ],
      verify: (_) =>
          verify(() => repository.write(alice, const ConnectionFavorites(starred: {}, recent: ['seed:a', 'seed:b'])))
              .called(1),
    );

    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'opening the connection that is already first changes and stores nothing',
      setUp: () =>
          when(() => repository.read(alice))
              .thenAnswer((_) async => const ConnectionFavorites(starred: {}, recent: ['seed:a'])),
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionOpened('seed:a')),
      expect: () => const [
        FavoriteConnectionsLoading(),
        FavoriteConnectionsReady(ConnectionFavorites(starred: {}, recent: ['seed:a'])),
      ],
      verify: (_) => verifyNever(() => repository.write(any(), any())),
    );

    blocTest<FavoriteConnectionsBloc, FavoriteConnectionsState>(
      'keeps the last ${FavoriteConnectionsBloc.storedRecentLimit} opened connections and drops older ones',
      setUp: () => when(() => repository.read(alice)).thenAnswer(
        (_) async => ConnectionFavorites(
          starred: const {},
          recent: [for (var i = 0; i < FavoriteConnectionsBloc.storedRecentLimit; i++) 'seed:$i'],
        ),
      ),
      build: build,
      act: (bloc) => bloc
        ..add(const FavoriteConnectionsSubjectChanged(alice))
        ..add(const FavoriteConnectionOpened('seed:new')),
      skip: 2,
      expect: () => [
        FavoriteConnectionsReady(
          ConnectionFavorites(
            starred: const {},
            recent: ['seed:new', for (var i = 0; i < FavoriteConnectionsBloc.storedRecentLimit - 1; i++) 'seed:$i'],
          ),
        ),
      ],
    );
  });
}
