import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

void main() {
  group('searchesObjects', () {
    ProviderMeta meta(List<ObjectKind> kinds) =>
        ProviderMeta(queryLanguage: 'x', schemaRefreshPattern: 'x', containerLevels: const [], objectKinds: kinds);
    const table = ObjectKind(id: 'table', role: 'relation', label: 'Table', labelPlural: 'Tables');
    const key = ObjectKind(id: 'key', role: 'relation', label: 'Key', labelPlural: 'Keys', keyBrowserOnly: true);

    test('is true when a kind is one the search lists', () => expect(meta(const [key, table]).searchesObjects, isTrue));

    test(
      'is false when every kind only the key browser lists',
      () => expect(meta(const [key]).searchesObjects, isFalse),
    );

    test('is false for an engine that declares no kind', () => expect(meta(const []).searchesObjects, isFalse));
  });
}
