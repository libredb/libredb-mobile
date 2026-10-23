import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

const _sales = 'seed:sales-db';
const _cache = 'seed:cache';

ProviderMeta _meta(String pattern) =>
    ProviderMeta(queryLanguage: 'sql', schemaRefreshPattern: pattern, containerLevels: const [], objectKinds: const []);

void main() {
  late MockIProviderMetaRepository providerMeta;
  late List<String> invalidated;
  late SchemaChangeNotifier notifier;

  setUp(() {
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_sales))
        .thenAnswer((_) async => Success(_meta(r'(CREATE|DROP|ALTER|TRUNCATE)\b')));
    when(() => providerMeta.providerMeta(_cache))
        .thenAnswer((_) async => Success(_meta(r'(DEL|FLUSHDB|FLUSHALL|RENAME)\b')));
    invalidated = [];
    notifier = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: invalidated.add);
  });

  tearDown(() => notifier.dispose());

  test('a statement that matches the engine pattern invalidates the connection, then tells the listeners', () async {
    final told = <String>[];
    notifier.changes.listen((connectionId) {
      expect(invalidated, [connectionId], reason: 'a screen that reloads must not get the dropped entries');
      told.add(connectionId);
    });

    final result = await notifier.statementSucceeded(_sales, 'drop table orders');
    await pumpEventQueue();

    expect(result, const Success(true));
    expect(invalidated, [_sales]);
    expect(told, [_sales]);
  });

  test("each engine's own pattern decides", () async {
    expect(await notifier.statementSucceeded(_cache, 'FLUSHDB'), const Success(true));
    expect(await notifier.statementSucceeded(_cache, 'DROP TABLE orders'), const Success(false));

    expect(invalidated, [_cache]);
  });

  test('a statement that does not match changes nothing and tells nobody', () async {
    final told = <String>[];
    notifier.changes.listen(told.add);

    final result = await notifier.statementSucceeded(_sales, 'select * from orders');
    await pumpEventQueue();

    expect(result, const Success(false));
    expect(invalidated, isEmpty);
    expect(told, isEmpty);
  });

  test(
    'a provider-meta failure after a successful statement still drops the connection and tells the listeners',
    () async {
      when(() => providerMeta.providerMeta(_sales))
          .thenAnswer((_) async => const Failure(RateLimitedError('slow down')));
      final told = <String>[];
      notifier.changes.listen((connectionId) {
        expect(invalidated, [connectionId], reason: 'a screen that reloads must not get the dropped entries');
        told.add(connectionId);
      });

      final result = await notifier.statementSucceeded(_sales, 'create table scratch_m5 (id int)');
      await pumpEventQueue();

      expect(result, isA<Failure<bool>>().having((f) => f.error, 'error', isA<RateLimitedError>()));
      expect(invalidated, [_sales]);
      expect(told, [_sales]);
    },
  );
}
