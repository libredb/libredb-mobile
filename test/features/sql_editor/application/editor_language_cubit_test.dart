import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_language_cubit.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

void main() {
  late MockIProviderMetaRepository providerMeta;

  setUp(() => providerMeta = MockIProviderMetaRepository());

  blocTest<EditorLanguageCubit, EditorLanguageState>(
    'names the language of the connection from its recorded meta',
    setUp: () =>
        when(() => providerMeta.providerMeta('seed:dev-redis'))
            .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_redis')))),
    build: () => EditorLanguageCubit(providerMeta: providerMeta, connectionId: 'seed:dev-redis'),
    act: (cubit) => cubit.load(),
    expect: () => const [EditorLanguageKnown(EditorLanguage(label: 'redis', highlighting: EditorHighlighting.plain))],
  );

  blocTest<EditorLanguageCubit, EditorLanguageState>(
    'a Postgres connection is SQL',
    setUp: () =>
        when(() => providerMeta.providerMeta('seed:dev-postgres'))
            .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres')))),
    build: () => EditorLanguageCubit(providerMeta: providerMeta, connectionId: 'seed:dev-postgres'),
    act: (cubit) => cubit.load(),
    expect: () => const [EditorLanguageKnown(EditorLanguage(label: 'sql', highlighting: EditorHighlighting.sql))],
  );

  blocTest<EditorLanguageCubit, EditorLanguageState>(
    'a refused meta is said with its code',
    setUp: () => when(() => providerMeta.providerMeta('seed:dev-postgres'))
        .thenAnswer((_) async => Failure(UnknownError('refused', code: AppErrorCode.studioConnectionNotAvailable.key))),
    build: () => EditorLanguageCubit(providerMeta: providerMeta, connectionId: 'seed:dev-postgres'),
    act: (cubit) => cubit.load(),
    expect: () => const [EditorLanguageUnknown(AppErrorCode.studioConnectionNotAvailable)],
  );
}
