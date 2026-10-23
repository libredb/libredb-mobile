import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Why a stored file cannot be read.
enum UnreadableReason {
  /// The subject's key is gone while its files are still there.
  keyMissing,

  /// The file failed AES-GCM authentication: changed, cut short, or copied from another subject or name.
  authentication,

  /// The file starts with a version byte this build does not know.
  version,

  /// The file decrypted, but its content is not JSON.
  format,
}

/// A stored file that cannot be read. It carries only the [reason], never the file's content, the subject or a path.
final class StoredTextUnreadableException implements Exception {
  const StoredTextUnreadableException(this.reason);

  final UnreadableReason reason;

  @override
  String toString() => 'StoredTextUnreadableException: the stored file cannot be read (${reason.name})';
}

/// The device refused a read or a write: the file system or the secure store. It names the [operation] and the type of
/// the error, never the error's message, which can hold a path.
final class StoredTextStorageException implements Exception {
  const StoredTextStorageException(this.operation, this.cause);

  final String operation;

  /// The type of the underlying error, and its OS error code when it had one.
  final String cause;

  @override
  String toString() => 'StoredTextStorageException: the device refused to $operation ($cause)';
}

/// What an [EncryptedTextFileStore.update] does with the file once it has read it.
sealed class FileChange<T> {
  const FileChange(this.result);

  /// What the update answers.
  final T result;
}

/// Replaces the file with [json].
final class WriteFile<T> extends FileChange<T> {
  const WriteFile(this.json, super.result);

  final Object? json;
}

/// Deletes the file.
final class DeleteFile<T> extends FileChange<T> {
  const DeleteFile(super.result);
}

/// Leaves the file as it is.
final class KeepFile<T> extends FileChange<T> {
  const KeepFile(super.result);
}

/// Keeps JSON values in files encrypted with AES-256-GCM, one directory per subject, under
/// `<application support>/statement_text/<subjectHash>/`.
///
/// Each subject has a random 256-bit key, in base64 in [ISecureStorage], made just before the subject's first file.
/// A file is a version byte (1), a random 12-byte nonce, the ciphertext and the 16-byte tag; the additional data is
/// `libredb.statement_text.v1`, the subject hash and the file name, joined by NUL, so a file copied under another
/// subject or name fails authentication instead of showing another account's content. This is plain AES-GCM, which
/// pointycastle reads as well, so the cipher package can be swapped without a migration.
///
/// A file that cannot be read throws [StoredTextUnreadableException] and is never replaced by a write until [delete]
/// removes it. While a subject's key is gone and any of its files is left, every read and write of that subject
/// throws it, and no new key is made over those files.
///
/// Writes go to `<name>.tmp`, flushed, and are then renamed over the file, so an interrupted write leaves the old file
/// and a `.tmp` that is never read. Every call runs in one queue per application support directory, shared by every
/// instance, so a read-modify-write is never interleaved with another. Encryption, decryption and JSON run in
/// [Isolate.run]; neither the content nor the key is kept between calls. No log line and no exception names the
/// content, the key, the subject hash or a path.
class EncryptedTextFileStore {
  EncryptedTextFileStore({required this._secureStorage, Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  static final _log = AppLogger.getLogger('EncryptedTextFileStore');

  static const _folder = 'statement_text';
  static const _version = 1;
  static const _nonceLength = 12;
  static const _tagLength = 16;
  static const _keyLength = 32;
  static const _tmpSuffix = '.tmp';

  /// Every key name of this store starts with this, so [clearAll] finds keys whose directory is gone.
  static const _keyPrefix = 'statementTextKey.';

  static final _subjectHashPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _namePattern = RegExp(r'^[a-z0-9_]{1,64}$');

  final ISecureStorage _secureStorage;
  final Future<Directory> Function() _supportDirectory;

  /// One queue per application support directory, shared by every store in the isolate, so two stores over the same
  /// files never race: two first writes would each make a key, and the second would orphan the first one's file.
  static final _queues = <String, Future<void>>{};

  Future<Directory>? _rootDirectory;

  /// The JSON value of the file [name] of [subjectHash], or null when there is none.
  Future<Object?> read(String subjectHash, String name) => _enqueue((root) async {
    _check(subjectHash, name);
    final directory = _subjectDirectory(root, subjectHash);
    final key = await _keyFor(directory, subjectHash);
    if (key == null) return null;
    return _readFile(directory, subjectHash, name, key);
  });

  /// Reads the file [name] of [subjectHash] (null when there is none), hands it to [change] and applies the change
  /// [change] answers, all in one turn of the queue.
  ///
  /// An unreadable file throws before [change] runs, so it is never replaced.
  Future<T> update<T>(String subjectHash, String name, FileChange<T> Function(Object? current) change) =>
      _enqueue((root) async {
        _check(subjectHash, name);
        final directory = _subjectDirectory(root, subjectHash);
        var key = await _keyFor(directory, subjectHash);
        final current = key == null ? null : await _readFile(directory, subjectHash, name, key);
        final next = change(current);
        switch (next) {
          case WriteFile(:final json):
            key ??= await _newKey(directory, subjectHash);
            await _writeFile(directory, subjectHash, name, key, json);
          case DeleteFile():
            await _deleteFile(directory, name);
          case KeepFile():
            break;
        }
        return next.result;
      });

  /// Deletes the file [name] of [subjectHash], readable or not, and a stale `.tmp` of it. Needs no key.
  Future<void> delete(String subjectHash, String name) => _enqueue((root) async {
    _check(subjectHash, name);
    await _deleteFile(_subjectDirectory(root, subjectHash), name);
  });

  /// Deletes the key of [subjectHash] first and its files after it, so an interrupted clear leaves only ciphertext no
  /// key opens. A key the secure store cannot delete throws, and the files are left for the next try.
  Future<void> clearSubject(String subjectHash) => _enqueue((root) async {
    _check(subjectHash, null);
    await _clear(_subjectDirectory(root, subjectHash), subjectHash);
  });

  /// [clearSubject] for each subject directory, then every key of this store left in the secure store (a key whose
  /// directory is gone, as an iOS Keychain item outlives a reinstall), then the whole `statement_text/` directory,
  /// stray entries included. Keys go before files throughout; a failure is thrown after every key was tried, and then
  /// the remaining files are left for the next try.
  Future<void> clearAll() => _enqueue((root) async {
    final folder = Directory('${root.path}/$_folder');
    final List<Directory> subjects;
    try {
      subjects = await folder.exists()
          ? await folder.list().where((entry) => entry is Directory).cast<Directory>().toList()
          : const <Directory>[];
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('list the stored subjects', _cause(e));
    }
    Object? first;
    StackTrace? firstStack;
    Future<void> attempt(Future<void> Function() step) async {
      try {
        await step();
      } catch (e, stack) {
        first ??= e;
        firstStack ??= stack;
      }
    }

    for (final directory in subjects) {
      final subjectHash = directory.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      if (_subjectHashPattern.hasMatch(subjectHash)) await attempt(() => _clear(directory, subjectHash));
    }
    await attempt(() async {
      final Set<String> names;
      try {
        names = await _secureStorage.keys();
      } catch (e) {
        throw StoredTextStorageException('list the keys', _cause(e));
      }
      for (final name in names.where((name) => name.startsWith(_keyPrefix))) {
        await attempt(() async {
          try {
            await _secureStorage.delete(name);
          } catch (e) {
            throw StoredTextStorageException('delete the key', _cause(e));
          }
        });
      }
    });
    if (first case final error?) Error.throwWithStackTrace(error, firstStack!);
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('delete the stored files', _cause(e));
    }
    _log.info('Cleared the stored text of every subject');
  });

  Future<T> _enqueue<T>(Future<T> Function(Directory root) operation) async {
    final Directory root;
    try {
      root = await (_rootDirectory ??= _root());
    } catch (_) {
      _rootDirectory = null;
      rethrow;
    }
    // Normalized, so `x`, `x/` and `x/./` name one queue.
    final path = Uri.directory(root.absolute.path).normalizePath().path;
    final result = (_queues[path] ?? Future<void>.value()).then((_) => operation(root));
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _queues[path] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_queues[path], tail)) _queues.remove(path);
      }),
    );
    return result;
  }

  void _check(String subjectHash, String? name) {
    if (!_subjectHashPattern.hasMatch(subjectHash)) {
      throw ArgumentError('the subject hash is not a lower-case SHA-256 hex digest');
    }
    if (name != null && !_namePattern.hasMatch(name)) throw ArgumentError('the file name is not a plain name');
  }

  Future<Directory> _root() async {
    try {
      return await _supportDirectory();
    } catch (e) {
      throw StoredTextStorageException('find the application support directory', _cause(e));
    }
  }

  static Directory _subjectDirectory(Directory root, String subjectHash) =>
      Directory('${root.path}/$_folder/$subjectHash');

  /// The key of [subjectHash], or null when it has none and no file needs one. A missing or malformed key while files
  /// are left throws [StoredTextUnreadableException]; a malformed key with no file left is deleted, so a discard
  /// recovers and the next write makes a new key.
  Future<Uint8List?> _keyFor(Directory directory, String subjectHash) async {
    final String? stored;
    try {
      stored = await _secureStorage.read(_keyName(subjectHash));
    } catch (e) {
      throw StoredTextStorageException('read the key', _cause(e));
    }
    if (stored != null) {
      try {
        final bytes = base64.decode(stored);
        if (bytes.length == _keyLength) return bytes;
      } on FormatException {
        // A key that is not base64 opens nothing, the same as a key of the wrong length.
      }
    }
    if (await _hasFiles(directory)) {
      _log.warn('A stored subject has files but no usable key, so they cannot be read');
      throw const StoredTextUnreadableException(UnreadableReason.keyMissing);
    }
    if (stored != null) {
      try {
        await _secureStorage.delete(_keyName(subjectHash));
      } catch (e) {
        throw StoredTextStorageException('delete a malformed key', _cause(e));
      }
      _log.warn('Deleted a malformed key of a stored subject that had no files left');
    }
    return null;
  }

  Future<bool> _hasFiles(Directory directory) async {
    try {
      if (!await directory.exists()) return false;
      return await directory.list().any((entry) => entry is File && !entry.path.endsWith(_tmpSuffix));
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('list the stored files', _cause(e));
    }
  }

  Future<Uint8List> _newKey(Directory directory, String subjectHash) async {
    final random = Random.secure();
    final key = Uint8List.fromList(List<int>.generate(_keyLength, (_) => random.nextInt(256)));
    try {
      await directory.create(recursive: true);
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('create the subject directory', _cause(e));
    }
    try {
      await _secureStorage.write(_keyName(subjectHash), base64.encode(key));
    } catch (e) {
      throw StoredTextStorageException('store the key', _cause(e));
    }
    _log.debug('Made the key of a stored subject');
    return key;
  }

  Future<Object?> _readFile(Directory directory, String subjectHash, String name, Uint8List key) async {
    final file = File('${directory.path}/$name');
    final Uint8List bytes;
    try {
      if (!await file.exists()) return null;
      bytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('read a stored file', _cause(e));
    }
    final aad = _aad(subjectHash, name);
    final opened = await _openInIsolate(key, bytes, aad);
    if (opened.reason case final reason?) {
      _log.warn('A stored file cannot be read: {}', [reason.name]);
      throw StoredTextUnreadableException(reason);
    }
    return opened.json;
  }

  Future<void> _writeFile(Directory directory, String subjectHash, String name, Uint8List key, Object? json) async {
    final aad = _aad(subjectHash, name);
    final sealed = await _sealInIsolate(key, aad, json);
    final file = File('${directory.path}/$name');
    final tmp = File('${file.path}$_tmpSuffix');
    try {
      await directory.create(recursive: true);
      await tmp.writeAsBytes(sealed, flush: true);
      await tmp.rename(file.path);
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('write a stored file', _cause(e));
    }
  }

  Future<void> _deleteFile(Directory directory, String name) async {
    try {
      for (final file in [File('${directory.path}/$name'), File('${directory.path}/$name$_tmpSuffix')]) {
        if (await file.exists()) await file.delete();
      }
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('delete a stored file', _cause(e));
    }
  }

  Future<void> _clear(Directory directory, String subjectHash) async {
    try {
      await _secureStorage.delete(_keyName(subjectHash));
    } catch (e) {
      throw StoredTextStorageException('delete the key', _cause(e));
    }
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (e) {
      throw StoredTextStorageException('delete the stored files', _cause(e));
    }
    _log.info('Cleared the stored text of a subject');
  }

  /// The secure store name of a subject's key: a SHA-256 of the subject hash, so the secure store's own log lines
  /// never print the subject hash.
  static String _keyName(String subjectHash) =>
      '$_keyPrefix${sha256.convert(utf8.encode('libredb.statement_text.key\u0000$subjectHash'))}';

  static Uint8List _aad(String subjectHash, String name) =>
      utf8.encode('libredb.statement_text.v1\u0000$subjectHash\u0000$name');

  static String _cause(Object error) => switch (error) {
    FileSystemException(:final osError?) => 'FileSystemException, OS error ${osError.errorCode}',
    _ => '${error.runtimeType}',
  };

  // Static, so the closure that crosses to the isolate holds only its arguments and never this store.
  static Future<Uint8List> _sealInIsolate(Uint8List key, Uint8List aad, Object? json) =>
      Isolate.run(() => _seal(key, aad, json));

  static Future<_Opened> _openInIsolate(Uint8List key, Uint8List bytes, Uint8List aad) =>
      Isolate.run(() => _open(key, bytes, aad));

  static Future<Uint8List> _seal(Uint8List key, Uint8List aad, Object? json) async {
    final random = Random.secure();
    final nonce = List<int>.generate(_nonceLength, (_) => random.nextInt(256));
    final box = await DartAesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(json)),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: aad,
    );
    return Uint8List.fromList([_version, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<_Opened> _open(Uint8List key, Uint8List bytes, Uint8List aad) async {
    if (bytes.length < 1 + _nonceLength + _tagLength) return const _Opened.unreadable(UnreadableReason.authentication);
    if (bytes.first != _version) return const _Opened.unreadable(UnreadableReason.version);
    final List<int> clear;
    try {
      clear = await DartAesGcm.with256bits().decrypt(
        SecretBox(
          bytes.sublist(1 + _nonceLength, bytes.length - _tagLength),
          nonce: bytes.sublist(1, 1 + _nonceLength),
          mac: Mac(bytes.sublist(bytes.length - _tagLength)),
        ),
        secretKey: SecretKey(key),
        aad: aad,
      );
    } on SecretBoxAuthenticationError {
      return const _Opened.unreadable(UnreadableReason.authentication);
    }
    try {
      return _Opened(jsonDecode(utf8.decode(clear)));
    } on FormatException {
      // The exception carries the decrypted text, so it goes no further than this.
      return const _Opened.unreadable(UnreadableReason.format);
    }
  }
}

/// What [EncryptedTextFileStore._open] answers from its isolate: the JSON value, or why there is none.
final class _Opened {
  const _Opened(this.json) : reason = null;

  const _Opened.unreadable(UnreadableReason this.reason) : json = null;

  final Object? json;
  final UnreadableReason? reason;
}
