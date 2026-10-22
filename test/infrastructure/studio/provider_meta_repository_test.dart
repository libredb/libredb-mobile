import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_env.dart';

/// Against the recorded answer in assets/mock; the reader's edge cases are in provider_meta_json_test.
void main() {
  late ProviderMetaRepository repository;
  const connection = 'seed:sales-db';

  setUp(() {
    repository = ProviderMetaRepository(TestEnv.apiClient());
  });

  test('providerMeta reads the capabilities and the tree shape', () async {
    TestEnv.authenticate();

    final meta = (await repository.providerMeta(connection) as Success<ProviderMeta>).data;

    expect(meta.queryLanguage, 'sql');
    expect(meta.isSql, isTrue);
    expect(meta.supportsQueryCancel, isTrue);
    expect(meta.containerLevels, const [ContainerLevel(id: 'schema', label: 'Schema', labelPlural: 'Schemas')]);
    expect(meta.objectKinds.map((k) => k.id), ['table', 'view', 'function', 'trigger']);
    expect(meta.objectKinds.last.attachedTo, 'table');
    expect(meta.keyScan, isNull);
  });

  test('a request without a session fails with an AuthError', () async {
    final result = await repository.providerMeta(connection);

    expect(result, isA<Failure<ProviderMeta>>().having((f) => f.error, 'error', isA<AuthError>()));
  });
}
