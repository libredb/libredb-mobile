import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

ProviderMeta _meta(String language, {String? dialect}) => ProviderMeta(
  queryLanguage: language,
  queryDialect: dialect,
  schemaRefreshPattern: 'DROP',
  containerLevels: const [],
  objectKinds: const [],
);

void main() {
  group('EditorLanguage.of', () {
    test('a SQL engine is highlighted as SQL and named by its language', () {
      expect(EditorLanguage.of(_meta('sql')), const EditorLanguage(label: 'sql', highlighting: EditorHighlighting.sql));
    });

    test('JSON without a dialect, as MongoDB declares it, is highlighted as JSON', () {
      expect(
        EditorLanguage.of(_meta('json')),
        const EditorLanguage(label: 'json', highlighting: EditorHighlighting.json),
      );
    });

    test("a declared dialect wins over the language, as in Studio's tab-language.ts, and reads as plain text", () {
      expect(
        EditorLanguage.of(_meta('json', dialect: 'redis')),
        const EditorLanguage(label: 'redis', highlighting: EditorHighlighting.plain),
      );
      expect(
        EditorLanguage.of(_meta('sql', dialect: 'libredb')),
        const EditorLanguage(label: 'libredb', highlighting: EditorHighlighting.plain),
      );
    });

    test('another language reads as plain text, named as Studio names it', () {
      for (final language in ['promql', 'cypher', 'influxql', 'something-new']) {
        expect(
          EditorLanguage.of(_meta(language)),
          EditorLanguage(label: language, highlighting: EditorHighlighting.plain),
        );
      }
    });
  });
}
