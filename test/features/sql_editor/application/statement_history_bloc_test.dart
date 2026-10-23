import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/application/statement_history_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

const _account = 'account-hash';
const _sales = 'seed:sales';
const _billing = 'seed:billing';

StatementHistoryEntry _entry(
  String id,
  String? text, {
  String connectionId = _sales,
  String connectionName = 'Sales',
  StatementRunStatus status = StatementRunStatus.success,
}) => StatementHistoryEntry(
  id: id,
  connectionId: connectionId,
  connectionName: connectionName,
  text: text,
  textTooLong: text == null,
  status: status,
  duration: const Duration(milliseconds: 5),
  executedAt: DateTime.utc(2026, 10, 23),
);

final _newest = _entry('3', 'SELECT * FROM orders');
final _billingRun = _entry('2', 'SELECT * FROM invoices', connectionId: _billing, connectionName: 'Billing İstanbul');
final _failed = _entry('1', 'SELEC 1', status: StatementRunStatus.failure);
final _history = [_newest, _billingRun, _failed];

void main() {
  late MockIStatementHistoryRepository repository;

  setUp(() => repository = MockIStatementHistoryRepository());

  StatementHistoryBloc build() =>
      StatementHistoryBloc(repository: repository, subjectHash: _account, activeConnectionId: _sales);

  void answerRead(Result<List<StatementHistoryEntry>> answer) =>
      when(() => repository.read(_account)).thenAnswer((_) async => answer);

  List<StatementHistoryEntry> visible(StatementHistoryBloc bloc) => switch (bloc.state) {
    StatementHistoryLoaded(:final visible) => visible,
    final other => fail('expected a loaded history, got $other'),
  };

  group('load', () {
    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'reads the account history and shows the active connection by default',
      setUp: () => answerRead(Success(_history)),
      build: build,
      act: (bloc) => bloc.add(const StatementHistoryLoadRequested()),
      expect: () => [
        const StatementHistoryLoading(),
        StatementHistoryLoaded(entries: _history, activeConnectionId: _sales),
      ],
      verify: (bloc) => expect(visible(bloc), [_newest, _failed]),
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'a history the store cannot read is unreadable, never empty',
      setUp: () => answerRead(const Failure(UnknownError('Could not read', code: 'editor.saved_text_unreadable'))),
      build: build,
      act: (bloc) => bloc.add(const StatementHistoryLoadRequested()),
      expect: () => [const StatementHistoryLoading(), const StatementHistoryUnreadable()],
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'another failure shows its code',
      setUp: () => answerRead(const Failure(UnknownError('io'))),
      build: build,
      act: (bloc) => bloc.add(const StatementHistoryLoadRequested()),
      expect: () => [const StatementHistoryLoading(), const StatementHistoryFailure(errorCode: AppErrorCode.generic)],
    );
  });

  group('filters', () {
    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'All connections shows every connection',
      setUp: () => answerRead(Success(_history)),
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistoryScopeChanged(allConnections: true)),
      skip: 2,
      verify: (bloc) => expect(visible(bloc), _history),
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'search folds case and the Turkish dotted I, over the text and the connection name',
      setUp: () => answerRead(Success(_history)),
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistoryScopeChanged(allConnections: true))
        ..add(const StatementHistorySearchChanged('istanbul')),
      verify: (bloc) => expect(visible(bloc), [_billingRun]),
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'search reads the statement text',
      setUp: () => answerRead(Success(_history)),
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistorySearchChanged('ORDERS')),
      verify: (bloc) => expect(visible(bloc), [_newest]),
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'the status filter keeps the failed runs or the successful ones',
      setUp: () => answerRead(Success(_history)),
      build: build,
      act: (bloc) async {
        bloc.add(const StatementHistoryLoadRequested());
        bloc.add(const StatementHistoryStatusFilterChanged(HistoryStatusFilter.failure));
        await Future<void>.delayed(Duration.zero);
        expect(visible(bloc), [_failed]);
        bloc.add(const StatementHistoryStatusFilterChanged(HistoryStatusFilter.success));
      },
      verify: (bloc) => expect(visible(bloc), [_newest]),
    );
  });

  group('delete', () {
    test('removes the entry from the list once the store removed it, and answers true', () async {
      answerRead(Success(_history));
      final removal = Completer<Result<void>>();
      when(() => repository.delete(_account, '3')).thenAnswer((_) => removal.future);
      final bloc = build();
      addTearDown(bloc.close);
      bloc.add(const StatementHistoryLoadRequested());
      await bloc.stream.firstWhere((s) => s is StatementHistoryLoaded);
      final done = Completer<bool>();

      bloc.add(StatementHistoryEntryDeleted('3', done: done));
      await pumpEventQueue();
      expect(visible(bloc), contains(_newest), reason: 'the entry stays until the store removed it');

      removal.complete(const Success(null));
      expect(await done.future, isTrue);
      expect(bloc.state, StatementHistoryLoaded(entries: [_billingRun, _failed], activeConnectionId: _sales));
    });

    test('a delete the store refuses keeps the entry, says so and answers false', () async {
      answerRead(Success(_history));
      when(() => repository.delete(_account, '3'))
          .thenAnswer((_) async => const Failure(UnknownError('io', code: 'editor.saved_text_not_stored')));
      final bloc = build();
      addTearDown(bloc.close);
      bloc.add(const StatementHistoryLoadRequested());
      await bloc.stream.firstWhere((s) => s is StatementHistoryLoaded);
      final done = Completer<bool>();

      bloc.add(StatementHistoryEntryDeleted('3', done: done));

      expect(await done.future, isFalse);
      expect(
        bloc.state,
        StatementHistoryLoaded(
          entries: _history,
          activeConnectionId: _sales,
          actionFailure: AppErrorCode.editorSavedTextNotStored,
        ),
      );
    });
  });

  group('clear', () {
    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'Clear all empties the history and keeps the filters',
      setUp: () {
        answerRead(Success(_history));
        when(() => repository.clear(_account)).thenAnswer((_) async => const Success(null));
      },
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistoryScopeChanged(allConnections: true))
        ..add(const StatementHistoryClearRequested()),
      skip: 3,
      expect: () => [const StatementHistoryLoaded(entries: [], activeConnectionId: _sales, allConnections: true)],
      verify: (_) => verify(() => repository.clear(_account)).called(1),
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'discarding an unreadable history leaves an empty one',
      setUp: () {
        answerRead(const Failure(UnknownError('Could not read', code: 'editor.saved_text_unreadable')));
        when(() => repository.clear(_account)).thenAnswer((_) async => const Success(null));
      },
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistoryClearRequested()),
      skip: 2,
      expect: () => [const StatementHistoryLoaded(entries: [], activeConnectionId: _sales)],
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'a discard the store refuses stays unreadable and says why',
      setUp: () {
        answerRead(const Failure(UnknownError('Could not read', code: 'editor.saved_text_unreadable')));
        when(() => repository.clear(_account))
            .thenAnswer((_) async => const Failure(UnknownError('io', code: 'editor.saved_text_not_stored')));
      },
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistoryClearRequested()),
      skip: 2,
      expect: () => [const StatementHistoryUnreadable(actionFailure: AppErrorCode.editorSavedTextNotStored)],
    );

    blocTest<StatementHistoryBloc, StatementHistoryState>(
      'a Clear all the store refuses keeps the entries and says so',
      setUp: () {
        answerRead(Success(_history));
        when(() => repository.clear(_account))
            .thenAnswer((_) async => const Failure(UnknownError('io', code: 'editor.saved_text_not_stored')));
      },
      build: build,
      act: (bloc) => bloc
        ..add(const StatementHistoryLoadRequested())
        ..add(const StatementHistoryClearRequested()),
      skip: 2,
      expect: () => [
        StatementHistoryLoaded(
          entries: _history,
          activeConnectionId: _sales,
          actionFailure: AppErrorCode.editorSavedTextNotStored,
        ),
      ],
    );
  });

  test('a loaded state prints no statement text', () {
    final state = StatementHistoryLoaded(entries: _history, activeConnectionId: _sales, query: 'orders');

    expect(state.toString(), isNot(contains('SELECT')));
    expect(state.toString(), isNot(contains('orders')));
    expect(const StatementHistorySearchChanged('orders').toString(), isNot(contains('orders')));
  });
}
