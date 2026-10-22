import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an engine without containers or kinds, with a key browser', () {
    final meta = ProviderMetaJson.read(
      '{"capabilities":{"queryLanguage":"json","keyScan":{"defaultCount":500,"maxCount":1000,"pattern":"glob"}}}',
    );

    expect(meta.isSql, isFalse);
    expect(meta.containerLevels, isEmpty);
    expect(meta.objectKinds, isEmpty);
    expect(meta.keyScan, const KeyScanSpec(defaultCount: 500, maxCount: 1000));
    expect(meta.supportsTransactions, isFalse);
  });

  test('a kind listed only by the key browser', () {
    final meta = ProviderMetaJson.read(
      '{"capabilities":{"queryLanguage":"json","objectKinds":[{"id":"key","role":"relation","label":"Key",'
      '"labelPlural":"Keys","enumeratedBy":"key-browser"}]}}',
    );

    expect(meta.objectKinds.single.keyBrowserOnly, isTrue);
  });

  test('refuses an answer without capabilities or a query language', () {
    for (final body in ['{}', '{"capabilities":{}}', '[]']) {
      expect(() => ProviderMetaJson.read(body), throwsFormatException, reason: body);
    }
  });
}
