import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/dart.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/storage/encrypted_text_file_store.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';

import '../../support/printed_lines.dart';

/// A secure store in memory that records each call, and the files of the subject directory at the moment of a delete,
/// and can be told to refuse a write or a delete.
class _MemorySecureStorage implements ISecureStorage {
  _MemorySecureStorage(this.root);

  final Directory root;
  final values = <String, String>{};
  final calls = <String>[];

  /// Every value written, kept after a delete.
  final written = <String>[];
  bool refuseWrite = false;
  bool refuseDelete = false;

  /// For each delete, whether the statement text directory still held files then.
  final filesAtDelete = <bool>[];

  @override
  Future<String?> read(String key) async {
    calls.add('read');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    calls.add('write');
    if (refuseWrite) throw StateError('secure storage refused the write of $key');
    values[key] = value;
    written.add(value);
  }

  @override
  Future<void> delete(String key) async {
    calls.add('delete');
    final folder = Directory('${root.path}/statement_text');
    filesAtDelete.add(folder.existsSync() && folder.listSync(recursive: true).whereType<File>().isNotEmpty);
    if (refuseDelete) throw StateError('secure storage refused the delete of $key');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() => throw UnimplementedError('the store never deletes every secure value');

  @override
  Future<Set<String>> keys() async {
    calls.add('keys');
    return values.keys.toSet();
  }
}

String _hash(String subject) => sha256.convert(utf8.encode(subject)).toString();

void main() {
  final alice = _hash('alice-subject');
  final bob = _hash('bob-subject');
  const statement = "UPDATE users SET email = 'jane@example.com' WHERE password = 'hunter2'";

  late Directory root;
  late _MemorySecureStorage secure;
  late EncryptedTextFileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('statement_text_test');
    addTearDown(() => root.deleteSync(recursive: true));
    secure = _MemorySecureStorage(root);
    store = EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root);
  });

  File fileOf(String subjectHash, String name) => File('${root.path}/statement_text/$subjectHash/$name');

  Matcher unreadable(UnreadableReason reason) =>
      isA<StoredTextUnreadableException>().having((e) => e.reason, 'reason', reason);

  Future<void> write(String subjectHash, String name, Object? json) =>
      store.update(subjectHash, name, (_) => WriteFile(json, null));

  group('isolation', () {
    test('a fresh install reads nothing', () async {
      expect(await store.read(alice, 'history'), isNull);
      expect(secure.values, isEmpty, reason: 'a read never makes a key');
    });

    test('reads back what it wrote for the same subject and name', () async {
      await write(alice, 'history', {'text': statement});

      final again = EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root);
      expect(await again.read(alice, 'history'), {'text': statement});
    });

    test('text written for one subject is not readable for another', () async {
      await write(alice, 'history', {'text': statement});

      expect(await store.read(bob, 'history'), isNull);
    });

    test('the bytes on disk hold neither the text nor the key, and start with the version byte', () async {
      await write(alice, 'history', statement);

      final bytes = fileOf(alice, 'history').readAsBytesSync();
      final plain = utf8.encode(jsonEncode(statement));
      expect(bytes.first, 1);
      expect(bytes.length, 1 + 12 + plain.length + 16);
      expect(latin1.decode(bytes), isNot(contains('hunter2')));
      expect(latin1.decode(bytes), isNot(contains('jane@example.com')));
      expect(secure.values.values.single, isNot(contains('hunter2')));
    });

    test('the key is 32 random bytes in base64, one per subject, under a name that does not hold the hash', () async {
      await write(alice, 'history', 'a');
      await write(bob, 'history', 'b');

      expect(secure.values, hasLength(2));
      for (final MapEntry(:key, :value) in secure.values.entries) {
        expect(base64.decode(value), hasLength(32));
        expect(key, isNot(contains(alice)));
        expect(key, isNot(contains(bob)));
      }
      expect(secure.values.values.toSet(), hasLength(2));
    });

    test('two writes of the same text use two nonces', () async {
      await write(alice, 'history', statement);
      final first = fileOf(alice, 'history').readAsBytesSync();
      await write(alice, 'history', statement);
      final second = fileOf(alice, 'history').readAsBytesSync();

      expect(first.sublist(1, 13), isNot(second.sublist(1, 13)));
    });

    test('makes the key before the subject first file and reuses it after that', () async {
      await write(alice, 'history', 'a');
      final key = secure.values.values.single;
      await write(alice, 'other', 'b');

      expect(secure.calls.where((call) => call == 'write'), hasLength(1));
      expect(secure.values.values.single, key);
    });
  });

  group('unreadable', () {
    test('a file copied under another subject reads as unreadable, never as the other text', () async {
      await write(alice, 'history', statement);
      await write(bob, 'history', 'bob text');
      fileOf(alice, 'history').copySync(fileOf(bob, 'history').path);

      await expectLater(store.read(bob, 'history'), throwsA(unreadable(UnreadableReason.authentication)));
    });

    test('a file copied under another name reads as unreadable', () async {
      await write(alice, 'history', statement);
      fileOf(alice, 'history').copySync(fileOf(alice, 'other').path);

      await expectLater(store.read(alice, 'other'), throwsA(unreadable(UnreadableReason.authentication)));
    });

    test('a tampered byte reads as unreadable', () async {
      await write(alice, 'history', statement);
      final file = fileOf(alice, 'history');
      final bytes = file.readAsBytesSync();
      bytes[20] ^= 0x01;
      file.writeAsBytesSync(bytes);

      await expectLater(store.read(alice, 'history'), throwsA(unreadable(UnreadableReason.authentication)));
    });

    test('an unknown version byte reads as unreadable', () async {
      await write(alice, 'history', statement);
      final file = fileOf(alice, 'history');
      final bytes = file.readAsBytesSync();
      bytes[0] = 2;
      file.writeAsBytesSync(bytes);

      await expectLater(store.read(alice, 'history'), throwsA(unreadable(UnreadableReason.version)));
    });

    test('a file too short for a nonce and a tag reads as unreadable', () async {
      await write(alice, 'history', statement);
      fileOf(alice, 'history').writeAsBytesSync([1, 2, 3]);

      await expectLater(store.read(alice, 'history'), throwsA(unreadable(UnreadableReason.authentication)));
    });

    test('an empty file reads as unreadable, not as an unknown version', () async {
      await write(alice, 'history', statement);
      fileOf(alice, 'history').writeAsBytesSync([]);

      await expectLater(store.read(alice, 'history'), throwsA(unreadable(UnreadableReason.authentication)));
    });

    test('text that decrypts but is not JSON reads as unreadable, and the error does not carry the text', () async {
      await write(alice, 'history', 'a');
      final key = SecretKey(base64.decode(secure.values.values.single));
      final nonce = List<int>.generate(12, (_) => Random.secure().nextInt(256));
      final box = await DartAesGcm.with256bits().encrypt(
        utf8.encode('not json $statement'),
        secretKey: key,
        nonce: nonce,
        aad: utf8.encode('libredb.statement_text.v1\u0000$alice\u0000history'),
      );
      fileOf(alice, 'history').writeAsBytesSync([1, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);

      final error = await store.read(alice, 'history').then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, unreadable(UnreadableReason.format));
      expect(error.toString(), isNot(contains('hunter2')));
      expect(error.toString(), isNot(contains('not json')));
    });

    test('with the key removed and files present, a read is unreadable', () async {
      await write(alice, 'history', statement);
      secure.values.clear();

      await expectLater(store.read(alice, 'history'), throwsA(unreadable(UnreadableReason.keyMissing)));
      await expectLater(store.read(alice, 'absent'), throwsA(unreadable(UnreadableReason.keyMissing)));
    });

    test('with the key removed and files present, a write leaves the files as they are and makes no new key', () async {
      await write(alice, 'history', statement);
      final before = fileOf(alice, 'history').readAsBytesSync();
      secure.values.clear();
      var changed = false;

      await expectLater(
        store.update(alice, 'history', (_) {
          changed = true;
          return const WriteFile('new', null);
        }),
        throwsA(unreadable(UnreadableReason.keyMissing)),
      );
      await expectLater(write(alice, 'other', 'new'), throwsA(unreadable(UnreadableReason.keyMissing)));

      expect(changed, isFalse);
      expect(fileOf(alice, 'history').readAsBytesSync(), before);
      expect(fileOf(alice, 'other').existsSync(), isFalse);
      expect(secure.values, isEmpty);
    });

    for (final (label, malformed) in [
      ('not base64', 'not base64!'),
      ('not 32 bytes', base64.encode(List.filled(16, 1))),
    ]) {
      test('a key that is $label, while the subject has no files, is deleted and replaced on the next write', () async {
        await write(alice, 'history', statement);
        await store.delete(alice, 'history');
        final name = secure.values.keys.single;
        secure.values[name] = malformed;

        expect(await store.read(alice, 'history'), isNull);
        await write(alice, 'history', 'new');

        expect(await store.read(alice, 'history'), 'new');
        expect(base64.decode(secure.values[name]!), hasLength(32));
      });

      test('a key that is $label, while files are left, is unreadable and stays', () async {
        await write(alice, 'history', statement);
        final name = secure.values.keys.single;
        secure.values[name] = malformed;

        await expectLater(store.read(alice, 'history'), throwsA(unreadable(UnreadableReason.keyMissing)));
        await expectLater(write(alice, 'other', 'new'), throwsA(unreadable(UnreadableReason.keyMissing)));
        expect(secure.values[name], malformed);
      });
    }

    test('a write never replaces a file that cannot be read', () async {
      await write(alice, 'history', statement);
      final file = fileOf(alice, 'history');
      final bytes = file.readAsBytesSync();
      bytes[0] = 9;
      file.writeAsBytesSync(bytes);

      await expectLater(write(alice, 'history', 'new'), throwsA(unreadable(UnreadableReason.version)));
      await expectLater(
        store.update(alice, 'history', (_) => const DeleteFile(null)),
        throwsA(unreadable(UnreadableReason.version)),
      );
      expect(file.readAsBytesSync(), bytes);
    });

    test('a delete removes an unreadable file, and then a new key is made only once no file is left', () async {
      await write(alice, 'history', statement);
      await write(alice, 'other', statement);
      secure.values.clear();

      await store.delete(alice, 'history');
      expect(fileOf(alice, 'history').existsSync(), isFalse);
      await expectLater(write(alice, 'history', 'new'), throwsA(unreadable(UnreadableReason.keyMissing)));

      await store.delete(alice, 'other');
      await write(alice, 'history', 'new');
      expect(await store.read(alice, 'history'), 'new');
      expect(secure.values, hasLength(1));
    });
  });

  group('writes', () {
    test('a stale .tmp from an interrupted write is never read', () async {
      fileOf(alice, 'history').parent.createSync(recursive: true);
      fileOf(alice, 'history.tmp').writeAsStringSync('garbage');
      expect(await store.read(alice, 'history'), isNull);

      await write(alice, 'history', 'kept');
      fileOf(alice, 'history.tmp').writeAsStringSync('garbage');
      expect(await store.read(alice, 'history'), 'kept');
    });

    test('a stale .tmp does not count as a file that needs the lost key', () async {
      fileOf(alice, 'history').parent.createSync(recursive: true);
      fileOf(alice, 'history.tmp').writeAsStringSync('garbage');

      await write(alice, 'history', 'new');
      expect(await store.read(alice, 'history'), 'new');
    });

    test('a write leaves no .tmp behind', () async {
      await write(alice, 'history', 'a');

      expect(fileOf(alice, 'history').parent.listSync().map((e) => e.uri.pathSegments.last), ['history']);
    });

    test('a delete in an update removes the file and answers the result', () async {
      await write(alice, 'history', 'a');

      expect(await store.update(alice, 'history', (current) => DeleteFile(current)), 'a');
      expect(fileOf(alice, 'history').existsSync(), isFalse);
    });

    test('a keep in an update leaves the file and answers the result', () async {
      await write(alice, 'history', 'a');
      final before = fileOf(alice, 'history').readAsBytesSync();

      expect(await store.update(alice, 'history', (_) => const KeepFile(7)), 7);
      expect(fileOf(alice, 'history').readAsBytesSync(), before);
    });

    test('updates sent together run one after another, so no append is lost', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++)
          store.update(alice, 'history', (current) => WriteFile([...?current as List<Object?>?, i], null)),
      ]);

      expect(await store.read(alice, 'history'), List.generate(20, (i) => i));
    });

    test('two stores over the same directory share one queue, so they never make two keys', () async {
      final other = EncryptedTextFileStore(secureStorage: secure, supportDirectory: () async => root);

      await Future.wait([write(alice, 'a', 'first'), other.update(alice, 'b', (_) => const WriteFile('second', null))]);

      expect(secure.written, hasLength(1));
      expect(await store.read(alice, 'a'), 'first');
      expect(await other.read(alice, 'b'), 'second');
    });

    test('a store over the same directory written with a trailing slash shares the queue', () async {
      final other = EncryptedTextFileStore(
        secureStorage: secure,
        supportDirectory: () async => Directory('${root.path}/'),
      );

      await Future.wait([write(alice, 'a', 'first'), other.update(alice, 'b', (_) => const WriteFile('second', null))]);

      expect(secure.written, hasLength(1));
      expect(await store.read(alice, 'a'), 'first');
      expect(await other.read(alice, 'b'), 'second');
    });

    test('a write the device refuses throws a storage error that names no path', () async {
      await write(alice, 'history', 'a');
      Directory(fileOf(alice, 'history.tmp').path).createSync();

      final error = await write(alice, 'history', statement).then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<StoredTextStorageException>());
      expect(error.toString(), isNot(contains(alice)));
      expect(error.toString(), isNot(contains(root.path)));
      expect(error.toString(), isNot(contains('hunter2')));
      expect(await store.read(alice, 'history'), 'a');
    });

    test('a key the secure store refuses throws a storage error and writes no file', () async {
      secure.refuseWrite = true;

      await expectLater(write(alice, 'history', 'a'), throwsA(isA<StoredTextStorageException>()));
      expect(fileOf(alice, 'history').existsSync(), isFalse);
    });

    test('refuses a subject hash or a name that is not a plain file name, naming neither', () async {
      for (final (subjectHash, name) in [('../x', 'history'), (alice.toUpperCase(), 'history'), (alice, '../x')]) {
        final error = await store.read(subjectHash, name).then<Object?>((_) => null, onError: (Object e) => e);
        expect(error, isA<ArgumentError>());
        expect(error.toString(), isNot(contains('../x')));
        expect(error.toString(), isNot(contains(alice.toUpperCase())));
      }
    });
  });

  group('clears', () {
    test('clearSubject removes the key before the files, and only that subject', () async {
      await write(alice, 'history', 'a');
      await write(alice, 'draft', 'b');
      await write(bob, 'history', 'c');

      await store.clearSubject(alice);

      expect(secure.filesAtDelete, [true], reason: 'the key goes while the files are still there');
      expect(Directory('${root.path}/statement_text/$alice').existsSync(), isFalse);
      expect(await store.read(alice, 'history'), isNull);
      expect(await store.read(bob, 'history'), 'c');
      expect(secure.values, hasLength(1));
    });

    test('clearSubject reports a key it cannot delete and leaves the files for the next try', () async {
      await write(alice, 'history', 'a');
      secure.refuseDelete = true;

      final error = await store.clearSubject(alice).then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<StoredTextStorageException>());
      expect(error.toString(), isNot(contains(alice)));
      expect(fileOf(alice, 'history').existsSync(), isTrue);
    });

    test('clearSubject of a subject with nothing stored succeeds', () async {
      await store.clearSubject(alice);

      expect(secure.values, isEmpty);
    });

    test('clearAll removes every subject key and files', () async {
      await write(alice, 'history', 'a');
      await write(bob, 'history', 'b');

      await store.clearAll();

      expect(secure.values, isEmpty);
      expect(Directory('${root.path}/statement_text').existsSync(), isFalse);
      expect(secure.filesAtDelete.first, isTrue);
    });

    test(
      'clearAll removes a key whose folder is gone and a stray folder, keys first, and no other secure value',
      () async {
        await write(alice, 'history', 'a');
        Directory('${root.path}/statement_text/$alice').deleteSync(recursive: true);
        final stray = File('${root.path}/statement_text/stray/leftover');
        stray.createSync(recursive: true);
        secure.values['jwtToken'] = 'session';

        await store.clearAll();

        expect(secure.values.keys, ['jwtToken']);
        expect(secure.filesAtDelete, isNotEmpty);
        expect(secure.filesAtDelete, everyElement(isTrue), reason: 'every key goes before the files');
        expect(Directory('${root.path}/statement_text').existsSync(), isFalse);
      },
    );

    test('clearAll reports a key it cannot delete and leaves the files for the next try', () async {
      await write(alice, 'history', 'a');
      Directory('${root.path}/statement_text/$alice').deleteSync(recursive: true);
      File('${root.path}/statement_text/stray/leftover').createSync(recursive: true);
      secure.refuseDelete = true;

      await expectLater(store.clearAll(), throwsA(isA<StoredTextStorageException>()));
      expect(File('${root.path}/statement_text/stray/leftover').existsSync(), isTrue);
    });

    test('clearAll on a fresh install succeeds', () async {
      await store.clearAll();
    });
  });

  test('no printed line carries the text, the key, the subject hash or the path', () async {
    final lines = await printedLines(() async {
      await write(alice, 'history', statement);
      await store.read(alice, 'history');
      fileOf(alice, 'history').writeAsBytesSync([9, ...List.filled(40, 0)]);
      await store.read(alice, 'history').catchError((Object _) => null);
      await store.delete(alice, 'history');
      await write(alice, 'history', statement);
      await store.clearSubject(alice);
      await store.clearAll();
    });

    expect(secure.written, isNotEmpty);
    for (final line in lines) {
      expect(line, isNot(contains('hunter2')));
      expect(line, isNot(contains(alice)));
      expect(line, isNot(contains(root.path)));
      for (final key in secure.written) {
        expect(line, isNot(contains(key)));
      }
    }
  });
}
