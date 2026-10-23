import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('containers', () {
    test('keeps the kinds a container holds', () {
      final containers = ObjectBrowserJson.containers(
        '[{"path":["app","public"],"name":"public","level":1,'
        '"kinds":["table","view"]}]',
      );

      expect(containers.single.path, ['app', 'public']);
      expect(containers.single.kinds, ['table', 'view']);
    });

    test('refuses a container without a path', () {
      expect(() => ObjectBrowserJson.containers('[{"name":"x","level":0}]'), throwsFormatException);
    });
  });

  test('counts refuses a count that is neither a number nor unavailable', () {
    expect(() => ObjectBrowserJson.counts('{"table":{"count":"many"}}'), throwsFormatException);
    expect(() => ObjectBrowserJson.counts('{"table":7}'), throwsFormatException);
  });

  test('objects refuse an object without a name or without a path', () {
    expect(() => ObjectBrowserJson.objects('[{"path":["public","t"],"kind":"table"}]'), throwsFormatException);
    expect(() => ObjectBrowserJson.objects('[{"name":"t","kind":"table"}]'), throwsFormatException);
  });

  test('objects leave out optional fields of an unexpected type', () {
    final object = ObjectBrowserJson.objects('[{"path":["t"],"name":"t","kind":"table","rowCount":"12"}]').single;

    expect(object.rowCount, isNull);
  });

  group('detail', () {
    test('indexes the engine could not read', () {
      final detail = ObjectBrowserJson.detail(
        '{"path":["c"],"columns":[{"name":"_id","type":"objectId","nullable":false,"isPrimary":true,'
        '"provenance":"sampled"}],"indexes":{"unavailable":"not authorized"},"foreignKeys":[]}',
      );

      expect(detail.indexes, isNull);
      expect(detail.indexesUnavailable, 'not authorized');
      expect(detail.columns.single.sampled, isTrue);
    });

    test('refuses a detail without columns', () {
      expect(() => ObjectBrowserJson.detail('{"path":["t"],"indexes":[],"foreignKeys":[]}'), throwsFormatException);
    });

    const column = '{"name":"id","type":"integer","nullable":false,"isPrimary":true}';
    String detail({
      String path = '["public","t"]',
      String columns = '[$column]',
      String? indexes = '[]',
      String? foreignKeys = '[]',
      String? exclusion,
    }) => [
      '{"path":$path,"columns":$columns',
      if (indexes != null) ',"indexes":$indexes',
      if (foreignKeys != null) ',"foreignKeys":$foreignKeys',
      if (exclusion != null) ',"exclusionConstraints":$exclusion',
      '}',
    ].join();

    test('keeps a declared type and the exclusion constraints as Studio sends them', () {
      final read = ObjectBrowserJson.detail(
        detail(
          columns:
              '[{"name":"total","type":"numeric","declaredType":"numeric(20,2)","nullable":true,"isPrimary":false}]',
          exclusion: '[{"name":"no_overlap","definition":"EXCLUDE USING gist (room WITH =)"}]',
        ),
      );

      expect(read.columns.single.declaredType, 'numeric(20,2)');
      expect(read.exclusionConstraints, const [
        ExclusionConstraintSchema(name: 'no_overlap', definition: 'EXCLUDE USING gist (room WITH =)'),
      ]);
    });

    test('an answer without exclusion constraints has none, and an unexpected type is left out', () {
      expect(ObjectBrowserJson.detail(detail()).exclusionConstraints, isEmpty);
      expect(ObjectBrowserJson.detail(detail(exclusion: '"x"')).exclusionConstraints, isEmpty);
      final column = ObjectBrowserJson.detail(
        detail(columns: '[{"name":"id","type":"integer","declaredType":7,"nullable":false,"isPrimary":true}]'),
      ).columns.single;
      expect(column.declaredType, isNull);
    });

    test('a blank declared type is left out, as no declaration', () {
      final column = ObjectBrowserJson.detail(
        detail(columns: '[{"name":"id","type":"integer","declaredType":" ","nullable":false,"isPrimary":true}]'),
      ).columns.single;

      expect(column.declaredType, isNull);
    });

    final refused = <String, String>{
      'a path that is not a list of strings': detail(path: '["public",1]'),
      'a missing path': '{"columns":[$column],"indexes":[],"foreignKeys":[]}',
      'a column without a name': detail(columns: '[{"type":"integer","nullable":false,"isPrimary":true}]'),
      'a column with a blank name': detail(
        columns: '[{"name":" ","type":"integer","nullable":false,"isPrimary":true}]',
      ),
      'a column without a type': detail(columns: '[{"name":"id","nullable":false,"isPrimary":true}]'),
      'a column with a blank type': detail(columns: '[{"name":"id","type":"","nullable":false,"isPrimary":true}]'),
      'a column without nullable': detail(columns: '[{"name":"id","type":"integer","isPrimary":true}]'),
      'a column whose isPrimary is not a bool': detail(
        columns: '[{"name":"id","type":"integer","nullable":false,"isPrimary":"yes"}]',
      ),
      'a column that is not an object': detail(columns: '["id"]'),
      // A loss notice: a sampled column says the list may lack keys, so a provenance the app cannot read is refused.
      'a provenance Studio does not send': detail(
        columns: '[{"name":"id","type":"integer","nullable":false,"isPrimary":true,"provenance":"guessed"}]',
      ),
      'a blank provenance': detail(
        columns: '[{"name":"id","type":"integer","nullable":false,"isPrimary":true,"provenance":""}]',
      ),
      'missing indexes': detail(indexes: null),
      'indexes that are neither a list nor unavailable': detail(indexes: '{"count":2}'),
      'a blank unavailable sentence': detail(indexes: '{"unavailable":" "}'),
      'an index without a name': detail(indexes: '[{"columns":["id"],"unique":true}]'),
      'an index with a blank name': detail(indexes: '[{"name":"","columns":["id"],"unique":true}]'),
      'an index without columns': detail(indexes: '[{"name":"pk","unique":true}]'),
      'an index without unique': detail(indexes: '[{"name":"pk","columns":["id"]}]'),
      'missing foreign keys': detail(foreignKeys: null),
      'a foreign key without a referenced table': detail(
        foreignKeys: '[{"columnName":"customer_id","referencedColumn":"id"}]',
      ),
      'a foreign key with a blank column': detail(
        foreignKeys: '[{"columnName":"","referencedTable":"customers","referencedColumn":"id"}]',
      ),
      'a foreign key with a blank referenced column': detail(
        foreignKeys: '[{"columnName":"customer_id","referencedTable":"customers","referencedColumn":" "}]',
      ),
      'an exclusion constraint without a definition': detail(exclusion: '[{"name":"no_overlap"}]'),
      'an exclusion constraint with a blank name': detail(exclusion: '[{"name":"","definition":"EXCLUDE"}]'),
      'an exclusion constraint that is not an object': detail(exclusion: '["no_overlap"]'),
    };
    for (final MapEntry(key: what, value: body) in refused.entries) {
      test('refuses $what', () => expect(() => ObjectBrowserJson.detail(body), throwsFormatException));
    }
  });

  group('source', () {
    String answer(String parts) => '{"path":["p"],"kind":"package","parts":[$parts]}';
    const text = '"id":"body","label":"Body","text":"BEGIN","language":"plsql","form":"complete"';

    test('a partial part keeps its origin and Studio\'s truncation, limit and reason as sent', () {
      final source = ObjectBrowserJson.source(
        answer(
          '{"id":"body","label":"Body","text":"BEGIN","language":"plsql","form":"partial","origin":"stored",'
          '"truncated":{"limit":1000000,"reason":"the source read was bounded at 1,000,000 characters by its caller"}}',
        ),
      );

      expect(
        source.parts.single,
        const SourceText(
          id: 'body',
          label: 'Body',
          text: 'BEGIN',
          language: 'plsql',
          complete: false,
          origin: SourceOrigin.stored,
          truncated: SourceTruncation(
            limit: 1000000,
            reason: 'the source read was bounded at 1,000,000 characters by its caller',
          ),
        ),
      );
    });

    test('reads each origin Studio sends', () {
      for (final origin in SourceOrigin.values) {
        final part = ObjectBrowserJson.source(answer('{$text,"origin":"${origin.name}"}')).parts.single as SourceText;

        expect(part.origin, origin);
        expect(part.truncated, isNull);
      }
    });

    test('refuses a text part without an origin, or with one Studio does not send', () {
      expect(() => ObjectBrowserJson.source(answer('{$text}')), throwsFormatException);
      expect(() => ObjectBrowserJson.source(answer('{$text,"origin":"guessed"}')), throwsFormatException);
    });

    test('refuses a truncation without its limit or its reason', () {
      expect(
        () => ObjectBrowserJson.source(answer('{$text,"origin":"stored","truncated":{"reason":"cut"}}')),
        throwsFormatException,
      );
      expect(
        () => ObjectBrowserJson.source(answer('{$text,"origin":"stored","truncated":{"limit":10}}')),
        throwsFormatException,
      );
      expect(
        () => ObjectBrowserJson.source(answer('{$text,"origin":"stored","truncated":true}')),
        throwsFormatException,
      );
    });

    test('ignores the edit affordance', () {
      final part = ObjectBrowserJson.source(
        answer('{$text,"origin":"regenerated","edit":{"offered":false,"reason":"must be owner"}}'),
      ).parts.single;

      expect(part, isA<SourceText>().having((p) => p.origin, 'origin', SourceOrigin.regenerated));
    });

    test('a refusal and a neutral statement are told apart', () {
      final parts = ObjectBrowserJson.source(
        answer(
          '{"id":"comment","label":"Comment","unavailable":"no comment is set"},'
          '{"id":"subs","label":"Subcollections","unavailable":"Studio cannot list them","statement":true}',
        ),
      ).parts;

      expect(parts, const [
        SourceUnavailable(id: 'comment', label: 'Comment', reason: 'no comment is set'),
        SourceStatement(id: 'subs', label: 'Subcollections', statement: 'Studio cannot list them'),
      ]);
    });

    test('refuses the whole answer for a statement on a readable part, as Studio\'s client does', () {
      expect(
        () => ObjectBrowserJson.source(
          answer('{"id":"c","label":"C","unavailable":"x"},{$text,"origin":"stored","statement":true}'),
        ),
        throwsFormatException,
      );
    });

    test('refuses a statement that is not true, and a part with both a text and a refusal', () {
      expect(
        () => ObjectBrowserJson.source(answer('{"id":"c","label":"C","unavailable":"x","statement":false}')),
        throwsFormatException,
      );
      expect(
        () => ObjectBrowserJson.source(answer('{$text,"origin":"stored","unavailable":"x"}')),
        throwsFormatException,
      );
    });

    test('refuses a text part without a form, or with one Studio does not send', () {
      const noForm = '"id":"b","label":"B","text":"BEGIN","language":"sql","origin":"stored"';
      expect(() => ObjectBrowserJson.source(answer('{$noForm}')), throwsFormatException);
      expect(() => ObjectBrowserJson.source(answer('{$noForm,"form":"whole"}')), throwsFormatException);
    });

    test('refuses a truncation whose reason is empty or blank, or that is null', () {
      for (final reason in ['""', '"  "']) {
        expect(
          () => ObjectBrowserJson.source(answer('{$text,"origin":"stored","truncated":{"limit":10,"reason":$reason}}')),
          throwsFormatException,
          reason: reason,
        );
      }
      expect(
        () => ObjectBrowserJson.source(answer('{$text,"origin":"stored","truncated":null}')),
        throwsFormatException,
      );
    });

    test('refuses an empty or blank id, label, text, language or refusal sentence', () {
      for (final blank in ['""', '" "']) {
        for (final field in ['id', 'label', 'text', 'language']) {
          final fields = {
            'id': '"b"',
            'label': '"B"',
            'text': '"BEGIN"',
            'language': '"sql"',
            'form': '"complete"',
            'origin': '"stored"',
          }..[field] = blank;
          final part = fields.entries.map((e) => '"${e.key}":${e.value}').join(',');
          expect(() => ObjectBrowserJson.source(answer('{$part}')), throwsFormatException, reason: '$field $blank');
        }
        expect(
          () => ObjectBrowserJson.source(answer('{"id":"c","label":"C","unavailable":$blank}')),
          throwsFormatException,
          reason: 'unavailable $blank',
        );
      }
    });

    test('refuses two parts with one id, and more than eight parts', () {
      const part = '{"id":"c","label":"C","unavailable":"x"}';
      expect(() => ObjectBrowserJson.source(answer('$part,$part')), throwsFormatException);
      final nine = [for (var i = 0; i < 9; i++) '{"id":"p$i","label":"P","unavailable":"x"}'].join(',');
      expect(() => ObjectBrowserJson.source(answer(nine)), throwsFormatException);
      final eight = [for (var i = 0; i < 8; i++) '{"id":"p$i","label":"P","unavailable":"x"}'].join(',');
      expect(ObjectBrowserJson.source(answer(eight)).parts, hasLength(8));
    });

    test('refuses a source without parts', () {
      expect(() => ObjectBrowserJson.source('{"path":["v"],"kind":"view","parts":[]}'), throwsFormatException);
    });
  });

  test('keyScanPage reads the last page and skips keys of an unreadable type', () {
    final page = ObjectBrowserJson.keyScanPage('{"keys":["a"],"cursor":"0","types":{"a":7},"total":1}');

    expect(page.isLast, isTrue);
    expect(page.types, isEmpty);
  });

  group('keyScanPage', () {
    test('reads clustered, skipped, readOutcome and prefixes', () {
      final page = ObjectBrowserJson.keyScanPage(
        '{"keys":["a/k"],"cursor":"opaque-1","types":{},"total":0,"clustered":true,'
        '"skipped":{"count":2,"reason":"not text"},'
        '"readOutcome":{"scope":"incomplete","endReason":"the server closed","provenLoss":["one message"]},'
        '"prefixes":["a/b/","a/c/"]}',
      );

      expect(page.clustered, isTrue);
      expect(page.skipped, const KeyScanSkipped(count: 2, reason: 'not text'));
      expect(
        page.readOutcome,
        const KeyReadOutcome(scope: 'incomplete', endReason: 'the server closed', provenLoss: ['one message']),
      );
      expect(page.readOutcome!.isIncomplete, isTrue);
      expect(page.prefixes, ['a/b/', 'a/c/']);
      expect(page.isLast, isFalse);
    });

    test('leaves the four optional fields out when absent', () {
      final page = ObjectBrowserJson.keyScanPage('{"keys":[],"cursor":"0","types":{},"total":0}');

      expect(page.clustered, isNull);
      expect(page.skipped, isNull);
      expect(page.readOutcome, isNull);
      expect(page.prefixes, isNull);
    });

    test('leaves out clustered and prefixes of an unexpected type', () {
      final page = ObjectBrowserJson.keyScanPage(
        '{"keys":[],"cursor":"0","types":{},"total":0,"clustered":"yes","prefixes":["a/",3]}',
      );

      expect(page.clustered, isNull);
      expect(page.prefixes, isNull);
    });

    // A loss notice is never dropped: present but malformed or blank, it fails the page (decisions.md, #59).
    for (final (what, field) in [
      ('a skipped count that is not a whole number', '"skipped":{"count":"2","reason":"x"}'),
      ('a skipped without a reason', '"skipped":{"count":2}'),
      ('a skipped with a blank reason', '"skipped":{"count":2,"reason":"  "}'),
      ('a skipped that is not an object', '"skipped":2'),
      ('a readOutcome without an endReason', '"readOutcome":{"scope":"unknown"}'),
      ('a readOutcome with a blank endReason', '"readOutcome":{"scope":"unknown","endReason":""}'),
      ('a readOutcome without a scope', '"readOutcome":{"endReason":"x"}'),
      (
        'a readOutcome whose provenLoss is not a list of text',
        '"readOutcome":{"scope":"incomplete","endReason":"x","provenLoss":[1]}',
      ),
      ('a readOutcome that is not an object', '"readOutcome":"short"'),
    ]) {
      test('refuses $what', () {
        expect(
          () => ObjectBrowserJson.keyScanPage('{"keys":[],"cursor":"0","types":{},"total":0,$field}'),
          throwsFormatException,
        );
      });
    }

    test('refuses an empty cursor, which Studio would refuse on the next page', () {
      expect(
        () => ObjectBrowserJson.keyScanPage('{"keys":[],"cursor":"","types":{},"total":0}'),
        throwsFormatException,
      );
    });

    test('refuses a page whose types is missing or not an object', () {
      expect(() => ObjectBrowserJson.keyScanPage('{"keys":[],"cursor":"0","total":0}'), throwsFormatException);
      expect(
        () => ObjectBrowserJson.keyScanPage('{"keys":[],"cursor":"0","types":[],"total":0}'),
        throwsFormatException,
      );
    });

    test('reads a readOutcome without provenLoss as an empty list', () {
      final page = ObjectBrowserJson.keyScanPage(
        '{"keys":[],"cursor":"0","types":{},"total":0,"readOutcome":{"scope":"unknown","endReason":"no end"}}',
      );

      expect(page.readOutcome, const KeyReadOutcome(scope: 'unknown', endReason: 'no end'));
      expect(page.readOutcome!.isIncomplete, isFalse);
    });

    test('refuses a page without a cursor', () {
      expect(() => ObjectBrowserJson.keyScanPage('{"keys":[],"types":{},"total":0}'), throwsFormatException);
    });
  });
}
