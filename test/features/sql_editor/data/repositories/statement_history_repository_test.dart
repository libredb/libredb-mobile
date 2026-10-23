import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/statement_text_json.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/infrastructure/storage/encrypted_text_file_store.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';
import '../../../../support/printed_lines.dart';

class _MemorySecureStorage implements ISecureStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() => throw UnimplementedError('the store never deletes every secure value');

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}

void main() {
  final alice = subjectHash('alice-subject');
  final bob = subjectHash('bob-subject');
  const secretText = "SELECT * FROM users WHERE email = 'jane@example.com'";

  T data<T>(Result<T> result) => switch (result) {
    Success(:final data) => data,
    Failure(:final error) => fail('expected a success, got $error'),
  };

  FinishedRun run(
    String text, {
    String connectionId = 'seed:sales',
    StatementRunStatus status = StatementRunStatus.success,
    int? rowCount = 3,
  }) => FinishedRun(
    connectionId: connectionId,
    connectionName: 'Sales',
    text: text,
    status: status,
    duration: const Duration(milliseconds: 42),
    rowCount: rowCount,
  );

  group('over the encrypted store', () {
    late Directory root;
    late _MemorySecureStorage secure;
    late EncryptedTextFileStore files;
    late IStatementTextStore store;
    late StatementHistoryRepository repository;
    var ids = 0;
    var clock = DateTime.utc(2026, 10, 23, 12);

    setUp(() {
      root = Directory.systemTemp.createTempSync('statement_history_repository_test');
      addTearDown(() => root.deleteSync(recursive: true));
      secure = _MemorySecureStorage();
      files = EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root);
      store = StatementTextStore(files);
      ids = 0;
      clock = DateTime.utc(2026, 10, 23, 12);
      repository = StatementHistoryRepository(
        store,
        newId: () => 'entry-${++ids}',
        now: () => clock = clock.add(const Duration(seconds: 1)),
      );
    });

    test('records a run with a fresh id and the time now, and reads the history newest first', () async {
      final first = data(await repository.record(alice, run('SELECT 1')));
      data(await repository.record(alice, run('SELECT 2', status: StatementRunStatus.failure, rowCount: null)));

      expect(
        first,
        StatementHistoryEntry(
          id: 'entry-1',
          connectionId: 'seed:sales',
          connectionName: 'Sales',
          text: 'SELECT 1',
          status: StatementRunStatus.success,
          duration: const Duration(milliseconds: 42),
          rowCount: 3,
          executedAt: DateTime.utc(2026, 10, 23, 12, 0, 1),
        ),
      );
      final history = data(await repository.read(alice));
      expect(history.map((entry) => entry.text), ['SELECT 2', 'SELECT 1']);
      expect(history.first.status, StatementRunStatus.failure);
      expect(history.first.rowCount, isNull);
    });

    /// Writes [texts], newest first, as the history of [subject] in one go, as that many records would; each record
    /// rewrites the whole file, which is too slow to repeat hundreds of times in a test.
    Future<void> seed(String subject, List<String> texts) => files.update(
      subject,
      'history',
      (_) => WriteFile(
        StatementTextJson.historyToJson([
          for (final (i, text) in texts.indexed)
            StatementHistoryEntry(
              id: 'seeded-$i',
              connectionId: 'seed:sales',
              connectionName: 'Sales',
              text: text,
              status: StatementRunStatus.success,
              duration: const Duration(milliseconds: 1),
              executedAt: DateTime.utc(2026, 10, 22),
            ),
        ]),
        null,
      ),
    );

    test('the 501st entry drops the oldest', () async {
      await seed(alice, [for (var i = 500; i >= 1; i--) 'SELECT $i']);

      data(await repository.record(alice, run('SELECT 501')));

      final history = data(await repository.read(alice));
      expect(history, hasLength(500));
      expect(history.first.text, 'SELECT 501');
      expect(history.last.text, 'SELECT 2');
    });

    test('an entry that takes the total past 1,000,000 characters drops the oldest until it fits', () async {
      final big = 'x' * 99999;
      await seed(alice, [for (var i = 9; i >= 0; i--) '$i$big']);
      expect(data(await repository.read(alice)), hasLength(10));

      data(await repository.record(alice, run('SELECT 1')));

      final history = data(await repository.read(alice));
      expect(history.map((entry) => entry.text![0]), ['S', '9', '8', '7', '6', '5', '4', '3', '2', '1']);
      expect(history.fold<int>(0, (sum, entry) => sum + entry.text!.length), lessThanOrEqualTo(1000000));
    });

    test('an entry over 100,000 characters is kept without its text and marked too long', () async {
      final stored = data(await repository.record(alice, run('x' * 100001)));

      expect(stored.text, isNull);
      expect(stored.textTooLong, isTrue);
      expect(data(await repository.read(alice)).single.textTooLong, isTrue);
    });

    test('another account on the same phone sees none of it, and the first sees its own again', () async {
      data(await repository.record(alice, run(secretText)));

      expect(data(await repository.read(bob)), isEmpty);
      data(await repository.record(bob, run('SELECT 2')));

      expect(data(await repository.read(alice)).single.text, secretText);
      expect(data(await repository.read(bob)).single.text, 'SELECT 2');
    });

    test('a failed run is stored with its status only, no error text', () async {
      data(await repository.record(alice, run('SELEC 1', status: StatementRunStatus.failure, rowCount: null)));

      final entry = data(await repository.read(alice)).single;
      expect(entry.status, StatementRunStatus.failure);
      expect(entry.props, isNot(contains(contains('syntax'))));
    });

    test('delete removes one entry and clear removes them all', () async {
      data(await repository.record(alice, run('SELECT 1')));
      data(await repository.record(alice, run('SELECT 2')));
      data(await repository.record(bob, run('SELECT 3')));

      data(await repository.delete(alice, 'entry-1'));
      expect(data(await repository.read(alice)).map((entry) => entry.text), ['SELECT 2']);

      data(await repository.clear(alice));
      expect(data(await repository.read(alice)), isEmpty);
      expect(data(await repository.read(bob)), hasLength(1));
    });

    test('logs no statement text', () async {
      final lines = await printedLines(() async {
        data(await repository.record(alice, run(secretText)));
        data(await repository.read(alice));
      });

      expect(lines.join('\n'), isNot(contains('jane@example.com')));
    });
  });

  group('over a store double', () {
    late MockIStatementTextStore store;
    late StatementHistoryRepository repository;

    setUp(() {
      store = MockIStatementTextStore();
      repository = StatementHistoryRepository(store, newId: () => 'entry-1', now: () => DateTime.utc(2026, 10, 23));
    });

    test('answers the store failure of a history it cannot read', () async {
      const unreadable = Failure<List<StatementHistoryEntry>>(
        UnknownError('Could not read the history: authentication', code: 'editor.saved_text_unreadable'),
      );
      when(() => store.readHistory(any())).thenAnswer((_) async => unreadable);

      final answer = await repository.read(subjectHash('alice-subject'));

      expect(
        answer,
        isA<Failure<List<StatementHistoryEntry>>>().having(
          (f) => f.error.code,
          'code',
          AppErrorCode.editorSavedTextUnreadable.key,
        ),
      );
    });

    test('clear discards the history, readable or not', () async {
      when(() => store.discardHistory(any())).thenAnswer((_) async => const Success(null));

      data(await repository.clear('hash'));

      verify(() => store.discardHistory('hash')).called(1);
    });
  });
}
