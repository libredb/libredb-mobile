import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/data/models/statement_text_json.dart';
import 'package:libredb_mobile/features/sql_editor/data/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/infrastructure/storage/encrypted_text_file_store.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';

import '../../../../support/printed_lines.dart';

/// A secure store in memory, which can be told to refuse a delete.
class _MemorySecureStorage implements ISecureStorage {
  final values = <String, String>{};
  bool refuseDelete = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    if (refuseDelete) throw StateError('secure storage refused the delete of $key');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() => throw UnimplementedError('the store never deletes every secure value');

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}

void main() {
  final alice = subjectHash('alice-subject');
  final bob = subjectHash('bob-subject');
  const sales = 'seed:sales';
  const billing = 'seed:billing';
  const secretText = "SELECT * FROM users WHERE email = 'jane@example.com' AND password = 'hunter2'";

  late Directory root;
  late _MemorySecureStorage secure;
  late StatementTextStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('statement_text_store_test');
    addTearDown(() => root.deleteSync(recursive: true));
    secure = _MemorySecureStorage();
    store = StatementTextStore(EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root));
  });

  Directory subjectDirectory(String hash) => Directory('${root.path}/statement_text/$hash');

  File draftFile(String hash, String connectionId) =>
      File('${subjectDirectory(hash).path}/${subjectHash(connectionId)}');

  File historyFile(String hash) => File('${subjectDirectory(hash).path}/history');

  void tamper(File file) {
    final bytes = file.readAsBytesSync();
    bytes[bytes.length - 1] ^= 0x01;
    file.writeAsBytesSync(bytes);
  }

  T data<T>(Result<T> result) => switch (result) {
    Success(:final data) => data,
    Failure(:final error) => fail('expected a success, got $error'),
  };

  Matcher failsWith(AppErrorCode code) => isA<Failure<Object?>>().having((f) => f.error.code, 'code', code.key);

  var nextId = 0;
  StatementHistoryEntry entry(String? text, {String connectionId = sales}) => StatementHistoryEntry(
    id: 'run-${nextId++}',
    connectionId: connectionId,
    connectionName: 'Sales',
    text: text,
    status: StatementRunStatus.success,
    duration: const Duration(milliseconds: 42),
    rowCount: 3,
    executedAt: DateTime.utc(2026, 10, 23, 12, nextId),
  );

  group('drafts', () {
    test('reads no draft on a fresh install', () async {
      expect(data(await store.readDraft(alice, sales)), isNull);
    });

    test('keeps one draft per connection with its catalog', () async {
      expect(
        data(await store.saveDraft(alice, sales, const StatementDraft(text: secretText, catalog: 'shop'))),
        DraftSaveOutcome.kept,
      );
      data(await store.saveDraft(alice, billing, const StatementDraft(text: 'SELECT 2')));

      expect(data(await store.readDraft(alice, sales)), const StatementDraft(text: secretText, catalog: 'shop'));
      expect(data(await store.readDraft(alice, billing)), const StatementDraft(text: 'SELECT 2'));
    });

    test('names the draft file by the SHA-256 of the connection id, and holds no plain text', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: secretText)));

      final names = subjectDirectory(alice).listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(names, [subjectHash(sales)]);
      expect(latin1.decode(draftFile(alice, sales).readAsBytesSync()), isNot(contains('hunter2')));
    });

    test('another account reads none of the drafts', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: secretText)));

      expect(data(await store.readDraft(bob, sales)), isNull);
    });

    test('keeps a draft of exactly 100,000 characters', () async {
      final text = 'x' * 100000;

      expect(data(await store.saveDraft(alice, sales, StatementDraft(text: text))), DraftSaveOutcome.kept);
      expect(data(await store.readDraft(alice, sales)), StatementDraft(text: text));
    });

    test('a 100,001-character draft is not kept and removes the saved draft of that connection', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 1')));
      data(await store.saveDraft(alice, billing, const StatementDraft(text: 'SELECT 2')));

      expect(data(await store.saveDraft(alice, sales, StatementDraft(text: 'x' * 100001))), DraftSaveOutcome.notKept);
      expect(data(await store.readDraft(alice, sales)), isNull);
      expect(draftFile(alice, sales).existsSync(), isFalse);
      expect(data(await store.readDraft(alice, billing)), const StatementDraft(text: 'SELECT 2'));
    });

    test('discardDraft removes the saved draft', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 1')));

      data(await store.discardDraft(alice, sales));

      expect(data(await store.readDraft(alice, sales)), isNull);
    });

    test('an unreadable draft answers unreadable, is never replaced by a save, and goes only on a discard', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 1')));
      tamper(draftFile(alice, sales));
      final before = draftFile(alice, sales).readAsBytesSync();

      expect(await store.readDraft(alice, sales), failsWith(AppErrorCode.editorSavedTextUnreadable));
      expect(
        await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 2')),
        failsWith(AppErrorCode.editorSavedTextUnreadable),
      );
      expect(
        await store.saveDraft(alice, sales, StatementDraft(text: 'x' * 100001)),
        failsWith(AppErrorCode.editorSavedTextUnreadable),
      );
      expect(draftFile(alice, sales).readAsBytesSync(), before);

      data(await store.discardDraft(alice, sales));
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 2')));
      expect(data(await store.readDraft(alice, sales)), const StatementDraft(text: 'SELECT 2'));
    });

    test('a draft whose content is not a draft answers unreadable', () async {
      final files = EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root);
      await files.update(alice, subjectHash(sales), (_) => const WriteFile({'catalog': 'shop'}, null));

      expect(await store.readDraft(alice, sales), failsWith(AppErrorCode.editorSavedTextUnreadable));
    });

    test('with the key gone and files left, drafts answer unreadable and no key is made', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 1')));
      secure.values.clear();

      expect(await store.readDraft(alice, sales), failsWith(AppErrorCode.editorSavedTextUnreadable));
      expect(await store.readDraft(alice, billing), failsWith(AppErrorCode.editorSavedTextUnreadable));
      expect(
        await store.saveDraft(alice, billing, const StatementDraft(text: 'SELECT 2')),
        failsWith(AppErrorCode.editorSavedTextUnreadable),
      );
      expect(secure.values, isEmpty);
    });

    test('a draft the device refuses to write answers not stored', () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 1')));
      Directory('${draftFile(alice, sales).path}.tmp').createSync();

      expect(
        await store.saveDraft(alice, sales, const StatementDraft(text: secretText)),
        failsWith(AppErrorCode.editorSavedTextNotStored),
      );
    });
  });

  group('history', () {
    /// Writes [newestFirst] as alice's history in one go, as that many appends would leave it.
    ///
    /// Each append decrypts and rewrites the whole file, so building a history near the 1,000,000-character bound
    /// from ten appends costs about 17 MB of AES-GCM and ran past the 30 s test timeout under full-suite load (#144);
    /// one write costs 1 MB.
    Future<void> seedHistory(List<StatementHistoryEntry> newestFirst) => EncryptedTextFileStore(
      secureStorage: secure,
      supportDirectory: () async => root,
    ).update(alice, 'history', (_) => WriteFile(StatementTextJson.historyToJson(newestFirst), null));

    test('reads an empty history on a fresh install', () async {
      expect(data(await store.readHistory(alice)), isEmpty);
    });

    test('keeps the entries newest first, with every field', () async {
      final first = entry('SELECT 1');
      final second = StatementHistoryEntry(
        id: 'run-x',
        connectionId: billing,
        connectionName: 'Billing',
        text: secretText,
        status: StatementRunStatus.failure,
        duration: const Duration(milliseconds: 1500),
        executedAt: DateTime.utc(2026, 10, 23, 13),
      );

      expect(data(await store.appendHistory(alice, first)), first);
      data(await store.appendHistory(alice, second));

      expect(data(await store.readHistory(alice)), [second, first]);
      expect(latin1.decode(historyFile(alice).readAsBytesSync()), isNot(contains('hunter2')));
    });

    test('another account reads none of the history', () async {
      data(await store.appendHistory(alice, entry(secretText)));

      expect(data(await store.readHistory(bob)), isEmpty);
    });

    test('keeps an entry of 100,000 characters whole', () async {
      final whole = entry('x' * 100000);

      expect(data(await store.appendHistory(alice, whole)), whole);
      expect(data(await store.readHistory(alice)), [whole]);
    });

    test('keeps a 100,001-character entry without its text, marked', () async {
      final long = entry('x' * 100001);

      final stored = data(await store.appendHistory(alice, long));

      expect(stored, long.withoutText());
      expect(stored.text, isNull);
      expect(stored.textTooLong, isTrue);
      expect(data(await store.readHistory(alice)), [long.withoutText()]);
    });

    test('the 501st entry drops the oldest', () async {
      final entries = [for (var i = 0; i < 501; i++) entry('SELECT $i')];
      // The first 500 are written in one go, as 500 appends would; each append rewrites the whole file.
      final first500 = entries.take(500).toList().reversed.toList();
      await seedHistory(first500);
      expect(data(await store.readHistory(alice)), first500);

      data(await store.appendHistory(alice, entries.last));

      final history = data(await store.readHistory(alice));
      expect(history, hasLength(500));
      expect(history.first, entries.last);
      expect(history.last, entries[1]);
    });

    test('an entry that takes the total past 1,000,000 characters drops the oldest entries until it fits', () async {
      final entries = [for (var i = 0; i < 10; i++) entry('$i' * 100000)];
      await seedHistory(entries.reversed.toList());

      final small = entry('SELECT 1');
      data(await store.appendHistory(alice, small));

      expect(data(await store.readHistory(alice)), [small, ...entries.reversed.take(9)]);

      final big = entry('y' * 100000);
      data(await store.appendHistory(alice, big));

      expect(data(await store.readHistory(alice)), [big, small, ...entries.reversed.take(8)]);
    });

    test('an entry kept without its text counts no characters toward the total', () async {
      final entries = [for (var i = 0; i < 10; i++) entry('$i' * 100000)];
      await seedHistory(entries.reversed.toList());

      final long = entry('z' * 100001);
      data(await store.appendHistory(alice, long));

      expect(data(await store.readHistory(alice)), [
        long.withoutText(),
        ...entries.reversed,
      ], reason: 'exactly 1,000,000 characters fit beside an entry kept without its text');
    });

    test('deleteHistoryEntry removes one entry', () async {
      final first = entry('SELECT 1');
      final second = entry('SELECT 2');
      data(await store.appendHistory(alice, first));
      data(await store.appendHistory(alice, second));

      data(await store.deleteHistoryEntry(alice, first.id));

      expect(data(await store.readHistory(alice)), [second]);
    });

    test('discardHistory removes the whole history', () async {
      data(await store.appendHistory(alice, entry('SELECT 1')));

      data(await store.discardHistory(alice));

      expect(data(await store.readHistory(alice)), isEmpty);
      expect(historyFile(alice).existsSync(), isFalse);
    });

    test(
      'an unreadable history answers unreadable, is never replaced by an append, and goes only on a discard',
      () async {
        data(await store.appendHistory(alice, entry('SELECT 1')));
        tamper(historyFile(alice));
        final before = historyFile(alice).readAsBytesSync();

        expect(await store.readHistory(alice), failsWith(AppErrorCode.editorSavedTextUnreadable));
        expect(await store.appendHistory(alice, entry('SELECT 2')), failsWith(AppErrorCode.editorSavedTextUnreadable));
        expect(await store.deleteHistoryEntry(alice, 'run-0'), failsWith(AppErrorCode.editorSavedTextUnreadable));
        expect(historyFile(alice).readAsBytesSync(), before);

        data(await store.discardHistory(alice));
        final next = entry('SELECT 3');
        data(await store.appendHistory(alice, next));
        expect(data(await store.readHistory(alice)), [next]);
      },
    );

    test('a history whose content is not a list of entries answers unreadable', () async {
      final files = EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root);
      await files.update(
        alice,
        'history',
        (_) => const WriteFile({
          'entries': [
            {'id': 'run-1'},
          ],
        }, null),
      );

      expect(await store.readHistory(alice), failsWith(AppErrorCode.editorSavedTextUnreadable));
    });

    test('with the key gone and the history left, an append answers unreadable and leaves the file', () async {
      data(await store.appendHistory(alice, entry('SELECT 1')));
      final before = historyFile(alice).readAsBytesSync();
      secure.values.clear();

      expect(await store.appendHistory(alice, entry('SELECT 2')), failsWith(AppErrorCode.editorSavedTextUnreadable));
      expect(historyFile(alice).readAsBytesSync(), before);
      expect(secure.values, isEmpty);
    });

    /// Three appends would already interleave if the queue let them. Each append opens and seals the history in two
    /// isolates, and with ten appends (22 isolate runs) the case took 9 s of the 30 s test timeout in a folder run while
    /// two other test runs compiled (#160); three appends take 8 isolate runs.
    test('a draft save and history appends sent together lose nothing', () async {
      final entries = [for (var i = 0; i < 3; i++) entry('SELECT $i')];
      final results = await Future.wait<Result<Object?>>([
        for (final one in entries) store.appendHistory(alice, one),
        store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT draft')),
      ]);

      // A refused write is named here, not mistaken for a lost one below.
      expect([for (final result in results) data(result)], [...entries, DraftSaveOutcome.kept]);
      expect(data(await store.readHistory(alice)), entries.reversed.toList());
      expect(data(await store.readDraft(alice, sales)), const StatementDraft(text: 'SELECT draft'));
    });
  });

  group('clears', () {
    test("clearSubject removes one account's drafts, history and key", () async {
      data(await store.saveDraft(alice, sales, const StatementDraft(text: 'SELECT 1')));
      data(await store.appendHistory(alice, entry('SELECT 1')));
      data(await store.appendHistory(bob, entry('SELECT 2')));

      data(await store.clearSubject(alice));

      expect(subjectDirectory(alice).existsSync(), isFalse);
      expect(data(await store.readDraft(alice, sales)), isNull);
      expect(data(await store.readHistory(alice)), isEmpty);
      expect(data(await store.readHistory(bob)), hasLength(1));
      expect(secure.values, hasLength(1));
    });

    test('clearSubject reports a failure', () async {
      data(await store.appendHistory(alice, entry('SELECT 1')));
      secure.refuseDelete = true;

      expect(await store.clearSubject(alice), failsWith(AppErrorCode.editorSavedTextNotStored));
    });

    test("clearAll removes every account's text", () async {
      data(await store.appendHistory(alice, entry('SELECT 1')));
      data(await store.saveDraft(bob, sales, const StatementDraft(text: 'SELECT 2')));

      data(await store.clearAll());

      expect(secure.values, isEmpty);
      expect(data(await store.readHistory(alice)), isEmpty);
      expect(data(await store.readDraft(bob, sales)), isNull);
    });

    test('clearAll reports a failure', () async {
      data(await store.appendHistory(alice, entry('SELECT 1')));
      secure.refuseDelete = true;

      expect(await store.clearAll(), failsWith(AppErrorCode.editorSavedTextNotStored));
    });
  });

  test('a subject hash that is not one answers a failure without naming it', () async {
    final result = await store.readHistory('alice-subject');

    expect(result, isA<Failure<Object?>>());
    expect(result.toString(), isNot(contains('alice-subject')));
  });

  test('no failure and no printed line carries the text, the subject hash or the path', () async {
    final results = <Result<Object?>>[];
    final lines = await printedLines(() async {
      results.add(await store.saveDraft(alice, sales, const StatementDraft(text: secretText)));
      results.add(await store.appendHistory(alice, entry(secretText)));
      tamper(draftFile(alice, sales));
      tamper(historyFile(alice));
      results.add(await store.readDraft(alice, sales));
      results.add(await store.saveDraft(alice, sales, const StatementDraft(text: secretText)));
      results.add(await store.readHistory(alice));
      results.add(await store.appendHistory(alice, entry(secretText)));
      Directory('${draftFile(alice, billing).path}.tmp').createSync(recursive: true);
      results.add(await store.saveDraft(alice, billing, const StatementDraft(text: secretText)));
      results.add(await store.discardDraft(alice, sales));
      results.add(await store.clearSubject(alice));
    });

    expect(results.whereType<Failure<Object?>>(), hasLength(5));
    for (final text in [...lines, for (final result in results) result.toString()]) {
      expect(text, isNot(contains('hunter2')));
      expect(text, isNot(contains('jane@example.com')));
      expect(text, isNot(contains(alice)));
      expect(text, isNot(contains(root.path)));
    }
  });
}
