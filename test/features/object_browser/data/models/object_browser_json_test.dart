import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
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
      expect(() => ObjectBrowserJson.source(answer('{$text,"origin":"stored","truncated":true}')), throwsFormatException);
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

    test('refuses a source without parts', () {
      expect(() => ObjectBrowserJson.source('{"path":["v"],"kind":"view","parts":[]}'), throwsFormatException);
    });
  });

  test('keyScanPage reads the last page and skips keys of an unreadable type', () {
    final page = ObjectBrowserJson.keyScanPage('{"keys":["a"],"cursor":"0","types":{"a":7},"total":1}');

    expect(page.isLast, isTrue);
    expect(page.types, isEmpty);
  });
}
