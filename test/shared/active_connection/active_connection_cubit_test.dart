import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

void main() {
  const subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';
  const sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres');
  const billing = StudioConnection(id: 'seed:billing', name: 'Billing', type: 'mysql');
  const listed = [sales, billing];

  late MockIActiveConnectionStore store;

  setUp(() {
    store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
  });

  ActiveConnectionCubit build() => ActiveConnectionCubit(store: store);

  test('starts with no connection', () {
    expect(build().state, const ActiveConnectionNone());
    expect(build().state.connection, isNull);
  });

  group('restore', () {
    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'opens the connection stored for the subject once the managed list holds it',
      setUp: () => when(() => store.read(subject)).thenAnswer((_) async => billing.id),
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.connectionsListed(listed);
      },
      expect: () => const [ActiveConnectionSelected(billing)],
      verify: (_) => verifyNever(() => store.write(any(), any())),
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'restores from a list that arrived before the stored id was read',
      setUp: () => when(() => store.read(subject)).thenAnswer((_) async => sales.id),
      build: build,
      act: (cubit) async {
        cubit.connectionsListed(listed);
        await cubit.signedIn(subject);
      },
      expect: () => const [ActiveConnectionSelected(sales)],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'opens none, without a message, when the stored connection is no longer in the managed list',
      setUp: () => when(() => store.read(subject)).thenAnswer((_) async => 'seed:gone'),
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.connectionsListed(listed);
      },
      expect: () => const <ActiveConnectionState>[],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'opens none when the stored connection cannot be read',
      setUp: () => when(() => store.read(subject)).thenThrow(const FormatException('not a map')),
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.connectionsListed(listed);
      },
      expect: () => const <ActiveConnectionState>[],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'restores only from the first list of the session, so a later list never reopens a connection',
      setUp: () => when(() => store.read(subject)).thenAnswer((_) async => billing.id),
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.connectionsListed(const [sales]);
        cubit.connectionsListed(listed);
      },
      expect: () => const <ActiveConnectionState>[],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'keeps a connection the user chose while the stored one was being read',
      setUp: () => when(() => store.read(subject)).thenAnswer((_) async => billing.id),
      build: build,
      act: (cubit) async {
        final read = cubit.signedIn(subject);
        cubit.select(sales);
        await read;
        cubit.connectionsListed(listed);
      },
      expect: () => const [ActiveConnectionSelected(sales)],
      verify: (_) => verify(() => store.write(subject, sales.id)).called(1),
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'never applies a stored id read for a session that has ended',
      build: build,
      act: (cubit) async {
        final answer = Completer<String?>();
        when(() => store.read(subject)).thenAnswer((_) => answer.future);
        final read = cubit.signedIn(subject);
        cubit.clear();
        when(() => store.read(subject)).thenAnswer((_) async => null);
        await cubit.signedIn(subject);
        answer.complete(billing.id);
        await read;
        cubit.connectionsListed(listed);
      },
      expect: () => const <ActiveConnectionState>[],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'neither reads nor stores anything when Studio names no subject',
      build: build,
      act: (cubit) async {
        await cubit.signedIn(null);
        cubit.connectionsListed(listed);
        cubit.select(sales);
      },
      expect: () => const [ActiveConnectionSelected(sales)],
      verify: (_) {
        verifyNever(() => store.read(any()));
        verifyNever(() => store.write(any(), any()));
      },
    );
  });

  group('select', () {
    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'opens the connection and stores its id for the subject',
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.select(sales);
        cubit.select(billing);
      },
      expect: () => const [ActiveConnectionSelected(sales), ActiveConnectionSelected(billing)],
      verify: (_) {
        verify(() => store.write(subject, sales.id)).called(1);
        verify(() => store.write(subject, billing.id)).called(1);
      },
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'stores a choice made before Studio named the subject once it does',
      build: build,
      act: (cubit) async {
        cubit.select(sales);
        await cubit.signedIn(subject);
      },
      expect: () => const [ActiveConnectionSelected(sales)],
      verify: (_) => verify(() => store.write(subject, sales.id)).called(1),
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'still opens the connection when the device refuses to store it',
      setUp: () => when(() => store.write(any(), any())).thenThrow(StateError('refused')),
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.select(sales);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => const [ActiveConnectionSelected(sales)],
    );

    test('reports each change of the active connection id once on connectionIds', () async {
      final cubit = build();
      final ids = <String?>[];
      final subscription = cubit.connectionIds.listen(ids.add);
      cubit.select(sales);
      cubit.connectionsListed(const [StudioConnection(id: 'seed:sales', name: 'Sales renamed', type: 'postgres')]);
      cubit.select(billing);
      cubit.connectionsListed(const [sales]);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await cubit.close();

      expect(ids, ['seed:sales', 'seed:billing', null]);
    });
  });

  group('vanish', () {
    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'clears the active connection when a list no longer holds it, and forgets it on the device',
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.select(billing);
        cubit.connectionsListed(const [sales]);
      },
      expect: () => const [ActiveConnectionSelected(billing), ActiveConnectionVanished(billing)],
      verify: (cubit) {
        expect(cubit.state.connection, isNull);
        verify(() => store.write(subject, null)).called(1);
      },
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'clears it when Studio says it is not available to the user',
      build: build,
      act: (cubit) async {
        await cubit.signedIn(subject);
        cubit.select(billing);
        cubit.reportUnavailable(billing.id);
      },
      expect: () => const [ActiveConnectionSelected(billing), ActiveConnectionVanished(billing)],
      verify: (_) => verify(() => store.write(subject, null)).called(1),
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'ignores an unavailable connection that is not the active one',
      build: build,
      act: (cubit) {
        cubit.select(billing);
        cubit.reportUnavailable(sales.id);
      },
      expect: () => const [ActiveConnectionSelected(billing)],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'keeps the active connection, with what Studio now says about it, when the list still holds it',
      build: build,
      act: (cubit) {
        cubit.select(billing);
        cubit.connectionsListed(const [
          StudioConnection(id: 'seed:billing', name: 'Billing', type: 'mysql', readOnly: true),
        ]);
      },
      expect: () => const [
        ActiveConnectionSelected(billing),
        ActiveConnectionSelected(StudioConnection(id: 'seed:billing', name: 'Billing', type: 'mysql', readOnly: true)),
      ],
    );

    blocTest<ActiveConnectionCubit, ActiveConnectionState>(
      'opens another connection after one vanished',
      build: build,
      act: (cubit) {
        cubit.select(billing);
        cubit.connectionsListed(const [sales]);
        cubit.select(sales);
      },
      expect: () => const [
        ActiveConnectionSelected(billing),
        ActiveConnectionVanished(billing),
        ActiveConnectionSelected(sales),
      ],
    );
  });

  blocTest<ActiveConnectionCubit, ActiveConnectionState>(
    'clear closes the connection when the session ends and keeps what the device stored for the next sign-in',
    build: build,
    act: (cubit) async {
      await cubit.signedIn(subject);
      cubit.select(sales);
      cubit.clear();
    },
    expect: () => const [ActiveConnectionSelected(sales), ActiveConnectionNone()],
    verify: (_) => verifyNever(() => store.write(any(), null)),
  );

  blocTest<ActiveConnectionCubit, ActiveConnectionState>(
    'after clear, the next user restores their own connection',
    build: build,
    act: (cubit) async {
      when(() => store.read('first')).thenAnswer((_) async => sales.id);
      when(() => store.read('second')).thenAnswer((_) async => billing.id);
      await cubit.signedIn('first');
      cubit.connectionsListed(listed);
      cubit.clear();
      await cubit.signedIn('second');
      cubit.connectionsListed(listed);
    },
    expect: () => const [ActiveConnectionSelected(sales), ActiveConnectionNone(), ActiveConnectionSelected(billing)],
  );
}
