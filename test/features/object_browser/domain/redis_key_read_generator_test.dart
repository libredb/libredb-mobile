import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/domain/redis_key_read_generator.dart';

// Every expected command below is what Studio's generateTableQuery (src/lib/query-generators.ts, libredb-studio
// c9989a6b5) answers for the path [key] on capabilities {queryLanguage: "json", queryDialect: "redis"} with the
// columns [{name: "type", type, nullable: false, isPrimary: false}] (none for a key without a type), which is what
// onOpenKey (src/components/Studio.tsx:1158-1169) hands it. Produced by a bun test file beside a tsconfig.json whose
// paths map "@/*" to libredb-studio's src/*, so nothing is written into the Studio checkout:
//   {"compilerOptions": {"baseUrl": ".", "paths": {"@/*": ["<libredb-studio>/src/*"]}}}
//   generateTableQuery([key], {queryLanguage: "json", queryDialect: "redis"},
//     type === null ? [] : [{name: "type", type}])
//   bun test probe.test.ts

void main() {
  const generator = RedisKeyReadGenerator();

  group('the typed read of each of the seven types', () {
    for (final (key, type, command) in [
      ('cache:greeting', 'string', 'GET cache:greeting'),
      ('user:2:profile', 'string', 'GET user:2:profile'),
      ('user:2', 'hash', 'HGETALL user:2'),
      ('session:2:events', 'list', 'LRANGE session:2:events 0 -1'),
      ('user:2:roles', 'set', 'SMEMBERS user:2:roles'),
      ('cache:leaderboard', 'zset', 'ZRANGE cache:leaderboard 0 -1 WITHSCORES'),
      ('session:2:log', 'stream', 'XRANGE session:2:log - + COUNT 100'),
      ('doc:1', 'rejson-rl', 'JSON.GET doc:1'),
    ]) {
      test('$type: $command', () {
        expect(generator.read(key, type), RedisKeyRead(statement: command, type: type));
      });
    }
  });

  group('the type a page named', () {
    test('is lowercased and trimmed, as Studio normalises a hand-written sample', () {
      // Studio: GET doc:1 and HGETALL doc:1
      expect(generator.read('doc:1', 'String'), const RedisKeyRead(statement: 'GET doc:1', type: 'string'));
      expect(generator.read('doc:1', ' hash '), const RedisKeyRead(statement: 'HGETALL doc:1', type: 'hash'));
    });

    for (final (label, type) in [
      ('none', null),
      ('empty', ''),
      ('several', 'string, hash'),
      ('outside the seven', 'vectorset'),
    ]) {
      test('$label reads TYPE only', () {
        // Studio: TYPE doc:1
        expect(generator.read('doc:1', type), const RedisKeyRead(statement: 'TYPE doc:1', type: null));
      });
    }

    test('keyType answers one of the seven or null', () {
      expect(RedisKeyReadGenerator.keyType('zset'), 'zset');
      expect(RedisKeyReadGenerator.keyType('REJSON-RL'), 'rejson-rl');
      expect(RedisKeyReadGenerator.keyType('none'), isNull);
      expect(RedisKeyReadGenerator.keyType('string,'), 'string');
      expect(RedisKeyReadGenerator.keyType(null), isNull);
    });
  });

  group('a key the plain form cannot carry', () {
    test('whitespace puts the key in double quotes', () {
      expect(generator.read('my key', 'string').statement, 'GET "my key"');
      expect(generator.read('tab\tkey', 'hash').statement, 'HGETALL "tab\tkey"');
      expect(generator.read('nbsp key', 'string').statement, 'GET "nbsp key"');
      expect(generator.read('rs x', 'string').statement, 'GET "rs x"');
      expect(generator.read('İzmir key', 'stream').statement, 'XRANGE "İzmir key" - + COUNT 100');
      expect(generator.read('my key', null).statement, 'TYPE "my key"');
    });

    test('a double quote writes the JSON form', () {
      // Studio: {"command":"GET","args":["say\"hi\""]}
      expect(generator.read('say"hi"', 'string').statement, r'{"command":"GET","args":["say\"hi\""]}');
      // Studio: {"command":"TYPE","args":["q\"uote"]}
      expect(generator.read('q"uote', null).statement, r'{"command":"TYPE","args":["q\"uote"]}');
    });

    test('a single quote writes the JSON form', () {
      // Studio: {"command":"LRANGE","args":["it's","0","-1"]}
      expect(generator.read("it's", 'list').statement, '{"command":"LRANGE","args":["it\'s","0","-1"]}');
    });

    test('a backslash writes the JSON form', () {
      // Studio: {"command":"SMEMBERS","args":["back\\slash"]}
      expect(generator.read(r'back\slash', 'set').statement, r'{"command":"SMEMBERS","args":["back\\slash"]}');
    });

    test('a newline writes the JSON form', () {
      // Studio: {"command":"ZRANGE","args":["line\nbreak","0","-1","WITHSCORES"]}
      expect(
        generator.read('line\nbreak', 'zset').statement,
        r'{"command":"ZRANGE","args":["line\nbreak","0","-1","WITHSCORES"]}',
      );
    });

    test('a control character in the JSON form is escaped as JSON.stringify escapes it', () {
      // Studio: {"command":"GET","args":["ctl\u0001x\""]}
      expect(generator.read('ctl\u0001x"', 'string').statement, r'{"command":"GET","args":["ctl\u0001x\""]}');
    });
  });

  test('a key ending in :* is read like any other, where Studio scans it as a prefix group (S-21)', () {
    // Studio: SCAN 0 MATCH cache:* COUNT 50, for the type string and for none
    expect(generator.read('cache:*', 'string'), const RedisKeyRead(statement: 'GET cache:*', type: 'string'));
    expect(generator.read('cache:*', null), const RedisKeyRead(statement: 'TYPE cache:*', type: null));
  });
}
