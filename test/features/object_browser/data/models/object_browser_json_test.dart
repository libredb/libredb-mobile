import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/provider_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('providerMeta', () {
    test('an engine without containers or kinds, with a key browser', () {
      final meta = ObjectBrowserJson.providerMeta(
        '{"capabilities":{"queryLanguage":"json","keyScan":{"defaultCount":500,"maxCount":1000,"pattern":"glob"}}}',
      );

      expect(meta.isSql, isFalse);
      expect(meta.containerLevels, isEmpty);
      expect(meta.objectKinds, isEmpty);
      expect(meta.keyScan, const KeyScanSpec(defaultCount: 500, maxCount: 1000));
      expect(meta.supportsTransactions, isFalse);
    });

    test('a kind listed only by the key browser', () {
      final meta = ObjectBrowserJson.providerMeta(
        '{"capabilities":{"queryLanguage":"json","objectKinds":[{"id":"key","role":"relation","label":"Key",'
        '"labelPlural":"Keys","enumeratedBy":"key-browser"}]}}',
      );

      expect(meta.objectKinds.single.keyBrowserOnly, isTrue);
    });

    test('refuses an answer without capabilities or a query language', () {
      for (final body in ['{}', '{"capabilities":{}}', '[]']) {
        expect(() => ObjectBrowserJson.providerMeta(body), throwsFormatException, reason: body);
      }
    });
  });

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
    test('a partial, truncated part', () {
      final source = ObjectBrowserJson.source(
        '{"path":["p"],"kind":"package","parts":[{"id":"body","label":"Body","text":"BEGIN","language":"plsql",'
        '"form":"partial","origin":"stored","truncated":{"limit":1000000,"reason":"size"}}]}',
      );

      expect(
        source.parts.single,
        isA<SourceText>().having((p) => p.complete, 'complete', isFalse).having((p) => p.truncated, 'truncated', true),
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
