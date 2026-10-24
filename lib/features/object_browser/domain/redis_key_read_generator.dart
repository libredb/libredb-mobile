import 'dart:convert';

import 'package:equatable/equatable.dart';

/// The statement that reads one Redis key, as Studio's key browser writes it (`generateTableQuery` for the path
/// `[key]`, `src/lib/query-generators.ts`, libredb-studio c9989a6b5).
///
/// A key whose page named exactly one of the seven types Studio reads gets that type's read (`REDIS_COMMANDS`), any
/// other key `TYPE <key>`. Studio first scans a name that ends in `:*` as a prefix group (`prefixGroup`); a key the
/// key browser lists is a key, so this reads it like any other (S-21).
class RedisKeyReadGenerator {
  const RedisKeyReadGenerator();

  /// The read of each type, from `REDIS_COMMANDS`.
  static final Map<String, List<String> Function(String key)> _reads = {
    'string': (key) => ['GET', key],
    'hash': (key) => ['HGETALL', key],
    'list': (key) => ['LRANGE', key, '0', '-1'],
    'set': (key) => ['SMEMBERS', key],
    'zset': (key) => ['ZRANGE', key, '0', '-1', 'WITHSCORES'],
    'stream': (key) => ['XRANGE', key, '-', '+', 'COUNT', '100'],
    'rejson-rl': (key) => ['JSON.GET', key],
  };

  /// The types that are read as one text value rather than as rows.
  static const textTypes = {'string', 'rejson-rl'};

  /// The one type [sample] names, lowercased, when it is one of the seven Studio reads; null for none, several or
  /// another type (`redisKeyType`, `query-generators.ts:727-737`).
  static String? keyType(String? sample) {
    final parts = (sample ?? '')
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length != 1) return null;
    return _reads.containsKey(parts.single) ? parts.single : null;
  }

  /// The read of [key] for the type a page named, [type], or `TYPE <key>` when it names none of the seven.
  RedisKeyRead read(String key, String? type) {
    final resolved = keyType(type);
    final parts = resolved == null ? ['TYPE', key] : _reads[resolved]!(key);
    return RedisKeyRead(statement: _render(parts), type: resolved);
  }

  static final _plainUnsafe = RegExp('["\'\\\\\n]');
  static final _whitespace = RegExp(r'\s');

  /// `renderRedisCommand`: the parts joined with spaces, a part that holds whitespace in double quotes, when no part
  /// holds a quote, a backslash or a newline, which the provider's plain tokenizer cannot carry; otherwise the JSON
  /// form the provider also accepts.
  static String _render(List<String> parts) {
    if (!parts.any(_plainUnsafe.hasMatch)) {
      return parts.map((part) => _whitespace.hasMatch(part) ? '"$part"' : part).join(' ');
    }
    return jsonEncode({'command': parts.first, 'args': parts.sublist(1)});
  }
}

/// A key's read: the command text, and the type it reads, null for `TYPE <key>`.
class RedisKeyRead extends Equatable {
  const RedisKeyRead({required this.statement, required this.type});

  final String statement;

  /// One of the seven types, or null when the statement asks for the key's type.
  final String? type;

  @override
  List<Object?> get props => [statement, type];

  @override
  String toString() => 'RedisKeyRead(type: $type)';
}
