import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/settings/application/remove_my_data_bloc.dart';
import 'package:libredb_mobile/shared/user_data/user_data_registry.dart';

import '../../../support/printed_lines.dart';

const _subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';

/// A store that records each subject it clears, and throws [error] while one is set.
class _FakeStore {
  _FakeStore(this.name);

  final String name;
  Object? error;
  final cleared = <String>[];

  /// Completes the clear when given, so a test can hold one in flight.
  Completer<void>? hold;

  UserDataStore get entry => UserDataStore(
    name: name,
    clear: (subject) async {
      cleared.add(subject);
      await hold?.future;
      final failure = error;
      if (failure != null) throw failure;
    },
  );
}

void main() {
  late _FakeStore drafts;
  late _FakeStore favorites;
  late _FakeStore catalog;

  setUp(() {
    drafts = _FakeStore('statement_text');
    favorites = _FakeStore('connection_favorites');
    catalog = _FakeStore('active_catalog');
  });

  RemoveMyDataBloc build() =>
      RemoveMyDataBloc(registry: UserDataRegistry([drafts.entry, favorites.entry, catalog.entry]));

  test('the states compare by value', () {
    expect(const RemoveMyDataIdle(), const RemoveMyDataIdle());
    expect(const RemoveMyDataInProgress(), const RemoveMyDataInProgress());
    expect(const RemoveMyDataDone(), const RemoveMyDataDone());
    expect(
      const RemoveMyDataFailure(errorCode: AppErrorCode.settingsUserDataNotRemoved),
      const RemoveMyDataFailure(errorCode: AppErrorCode.settingsUserDataNotRemoved),
    );
    expect(const RemoveMyDataFailure(errorCode: AppErrorCode.generic), isNot(const RemoveMyDataDone()));
  });

  test('starts idle', () => expect(build().state, const RemoveMyDataIdle()));

  blocTest<RemoveMyDataBloc, RemoveMyDataState>(
    'clears every store for the subject, then is done',
    build: build,
    act: (bloc) => bloc.add(const RemoveMyDataRequested(subject: _subject)),
    expect: () => const [RemoveMyDataInProgress(), RemoveMyDataDone()],
    verify: (_) {
      expect(drafts.cleared, [_subject]);
      expect(favorites.cleared, [_subject]);
      expect(catalog.cleared, [_subject]);
    },
  );

  blocTest<RemoveMyDataBloc, RemoveMyDataState>(
    'still tries every store when one fails, and then fails',
    setUp: () => favorites.error = StateError('the device refused to store connection_favorites'),
    build: build,
    act: (bloc) => bloc.add(const RemoveMyDataRequested(subject: _subject)),
    expect: () => const [
      RemoveMyDataInProgress(),
      RemoveMyDataFailure(errorCode: AppErrorCode.settingsUserDataNotRemoved),
    ],
    verify: (_) {
      expect(drafts.cleared, [_subject]);
      expect(favorites.cleared, [_subject]);
      expect(catalog.cleared, [_subject], reason: 'the store after the failed one is still cleared');
    },
  );

  blocTest<RemoveMyDataBloc, RemoveMyDataState>(
    'a retry after the cause is gone clears every store again and is done',
    setUp: () => drafts.error = StateError('refused'),
    build: build,
    act: (bloc) async {
      bloc.add(const RemoveMyDataRequested(subject: _subject));
      await bloc.stream.firstWhere((state) => state is RemoveMyDataFailure);
      drafts.error = null;
      bloc.add(const RemoveMyDataRequested(subject: _subject));
    },
    expect: () => const [
      RemoveMyDataInProgress(),
      RemoveMyDataFailure(errorCode: AppErrorCode.settingsUserDataNotRemoved),
      RemoveMyDataInProgress(),
      RemoveMyDataDone(),
    ],
    verify: (_) {
      expect(drafts.cleared, [_subject, _subject]);
      expect(catalog.cleared, [_subject, _subject]);
    },
  );

  blocTest<RemoveMyDataBloc, RemoveMyDataState>(
    'drops a second request while the first is clearing',
    setUp: () => drafts.hold = Completer<void>(),
    build: build,
    act: (bloc) async {
      bloc.add(const RemoveMyDataRequested(subject: _subject));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const RemoveMyDataRequested(subject: _subject));
      await Future<void>.delayed(Duration.zero);
      drafts.hold!.complete();
    },
    expect: () => const [RemoveMyDataInProgress(), RemoveMyDataDone()],
    verify: (_) {
      expect(drafts.cleared, [_subject]);
      expect(favorites.cleared, [_subject]);
    },
  );

  test('logs the store and the error type of a failure, never the error text or the subject', () async {
    favorites.error = StateError('jane@example.com starred seed:payroll');
    final lines = await printedLines(() async {
      final bloc = build();
      bloc.add(const RemoveMyDataRequested(subject: _subject));
      await bloc.stream.firstWhere((state) => state is RemoveMyDataFailure);
      await bloc.close();
    });

    final log = lines.join('\n');
    expect(lines.where((line) => line.contains('connection_favorites') && line.contains('StateError')), hasLength(1));
    expect(log, isNot(contains('jane')));
    expect(log, isNot(contains('payroll')));
    expect(log, isNot(contains(_subject)));
  });
}
