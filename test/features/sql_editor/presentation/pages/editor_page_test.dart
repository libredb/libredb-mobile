@Tags(['widget'])
library;

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/sql_page.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_bloc.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

QueryResult _recorded(String name) => QueryResultJson.read(_fixture(name));

const _postgres = StudioConnection(
  id: 'seed:dev-postgres',
  name: 'Dev Postgres',
  type: 'postgres',
  environment: 'development',
);
const _production = StudioConnection(
  id: 'seed:dev-postgres-prod',
  name: 'Prod Postgres',
  type: 'postgres',
  environment: 'production',
);
const _redis = StudioConnection(id: 'seed:dev-redis', name: 'Dev Redis', type: 'redis', environment: 'development');

const _rolledBack = QueryResult(
  fields: [],
  rows: [],
  rowCount: 0,
  executionTime: Duration(milliseconds: 1),
  openTransactionRolledBack: true,
);

void main() {
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockActiveConnectionCubit active;
  late SchemaChangeNotifier schemaChanges;

  setUp(() {
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    for (final connection in [_postgres, _production]) {
      when(() => providerMeta.providerMeta(connection.id))
          .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    }
    when(() => providerMeta.providerMeta(_redis.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_redis'))));
    active = MockActiveConnectionCubit();
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  });

  tearDown(() => schemaChanges.dispose());

  void answerRun(String sql, Result<QueryResult> Function() answer, {QueryPage? page}) => when(
    () => repository.run(
      any(),
      sql,
      queryId: any(named: 'queryId'),
      page: page ?? any(named: 'page'),
    ),
  ).thenAnswer((_) async => answer());

  int runsOf(String sql) => verify(
    () => repository.run(
      any(),
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
    ),
  ).callCount;

  void verifyNothingSent() => verifyNever(
    () => repository.run(
      any(),
      any(),
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      params: any(named: 'params'),
      catalog: any(named: 'catalog'),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    StudioConnection? connection = _postgres,
    bool offline = false,
    bool recordsInFull = false,
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    whenListen(
      active,
      const Stream<ActiveConnectionState>.empty(),
      initialState: connection == null ? const ActiveConnectionNone() : ActiveConnectionSelected(connection),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ISqlEditorRepository>.value(value: repository),
          RepositoryProvider<IProviderMetaRepository>.value(value: providerMeta),
          RepositoryProvider<SchemaChangeNotifier>.value(value: schemaChanges),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider<ResultViewModeCubit>(create: (_) => ResultViewModeCubit(store: MockIResultViewModeStore())),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: Scaffold(
              body: StudioRoleScope(
                role: const StudioUserRole(),
                child: StatementCaptureScope(
                  recordsInFull: recordsInFull,
                  child: OfflineStatus(isOffline: offline, child: const SqlPage()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder runButton() => find.byKey(EditorActions.runKey);

  bool runEnabled(WidgetTester tester) => tester.widget<ButtonStyleButton>(runButton()).enabled;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(EditorInput.fieldKey), text);
    await tester.pump();
  }

  Future<void> run(WidgetTester tester) async {
    await tester.tap(runButton());
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Run').last);
    await tester.pumpAndSettle();
  }

  testWidgets('asks the user to pick a connection while none is open', (tester) async {
    await pump(tester, connection: null);

    expect(find.byType(PickConnectionFirst), findsOneWidget);
    expect(find.byKey(EditorInput.fieldKey), findsNothing);
  });

  testWidgets('says that statements are recorded in full only while governance records them so', (tester) async {
    await pump(tester, recordsInFull: true);
    expect(find.text("Statements you run are recorded in full in this server's query log."), findsOneWidget);

    await pump(tester);
    expect(find.text("Statements you run are recorded in full in this server's query log."), findsNothing);
  });

  testWidgets('Run is disabled while the text is empty', (tester) async {
    await pump(tester);

    expect(runEnabled(tester), isFalse);
    await type(tester, 'SELECT 1');
    expect(runEnabled(tester), isTrue);
  });

  testWidgets('offline, Run is disabled with the reason', (tester) async {
    await pump(tester, offline: true);
    await type(tester, 'SELECT 1');

    expect(runEnabled(tester), isFalse);
    expect(find.text('Needs an internet connection'), findsOneWidget);
  });

  testWidgets('a read runs without a prompt and shows masked rows', (tester) async {
    answerRun('SELECT * FROM customers', () => Success(_recorded('query_preview_postgres_customers')));
    await pump(tester);
    await type(tester, 'SELECT * FROM customers');

    await run(tester);

    expect(find.byType(WriteConfirmationSheet), findsNothing);
    expect(find.textContaining('Ada Lovelace'), findsWidgets);
    expect(find.textContaining('ada@example.com'), findsNothing);
    expect(runsOf('SELECT * FROM customers'), 1);
  });

  testWidgets('a text of several statements is refused with the one-statement message, and nothing is sent', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, 'SELECT 1; SELECT 2');

    await run(tester);

    expect(find.text('This text holds more than one statement. Run one statement at a time.'), findsOneWidget);
    verifyNothingSent();
  });

  group('a text that may write', () {
    const delete = 'DELETE FROM orders WHERE false';

    testWidgets('asks, and a cancel sends nothing', (tester) async {
      await pump(tester);
      await type(tester, delete);

      await run(tester);
      expect(find.byType(WriteConfirmationSheet), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(WriteConfirmationSheet), findsNothing);
      verifyNothingSent();
      expect(runEnabled(tester), isTrue);
    });

    testWidgets('runs the confirmed text once, and shows the rows it changed', (tester) async {
      answerRun(
        delete,
        () => const Success(QueryResult(fields: [], rows: [], rowCount: 3, executionTime: Duration(milliseconds: 2))),
      );
      await pump(tester);
      await type(tester, delete);

      await run(tester);
      await confirm(tester);

      expect(find.text('3 rows affected'), findsOneWidget);
      expect(runsOf(delete), 1);
    });

    testWidgets('on a production connection Run needs the typed name', (tester) async {
      answerRun(delete, () => const Success(_rolledBack));
      await pump(tester, connection: _production);
      await type(tester, delete);

      await run(tester);
      final sheetRun = find.widgetWithText(FilledButton, 'Run').last;
      expect(tester.widget<FilledButton>(sheetRun).enabled, isFalse);
      await tester.enterText(find.byKey(WriteConfirmationSheet.nameFieldKey), 'Prod Postgres');
      await tester.pump();
      expect(tester.widget<FilledButton>(sheetRun).enabled, isTrue);
      await confirm(tester);

      expect(runsOf(delete), 1);
    });
  });

  testWidgets('on a connection marked read only the confirmation says the write will be refused', (tester) async {
    const readOnly = StudioConnection(
      id: 'seed:dev-postgres',
      name: 'Dev Postgres',
      type: 'postgres',
      environment: 'development',
      readOnly: true,
    );
    await pump(tester, connection: readOnly);
    await type(tester, 'DELETE FROM orders WHERE false');

    await run(tester);

    expect(
      find.text(
        'This connection is set read only by its operator, so Studio or the database will refuse a write here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets("a confirmed write the database refuses shows Studio's refusal and runs once", (tester) async {
    const delete = 'DELETE FROM orders WHERE false';
    answerRun(
      delete,
      () => const Failure(
        AuthError('Permission denied: permission denied for table orders', code: 'studio.permission_denied'),
      ),
    );
    await pump(tester);
    await type(tester, delete);

    await run(tester);
    await confirm(tester);

    expect(find.byType(StudioErrorBanner), findsOneWidget);
    expect(find.textContaining('permission denied for table orders'), findsNothing);
    expect(runsOf(delete), 1);
  });

  group('Load more', () {
    const ledger = 'SELECT * FROM sales.ledger';
    const flagged = 'SELECT * FROM sales.ledger -- note: update';
    final second = QueryPage.after(_recorded('query_page_postgres_first').pagination!);

    Finder loadMore() => find.textContaining('Load 50 more');

    Future<void> scrollToLoadMore(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('result-load-more')));
      await tester.pumpAndSettle();
    }

    testWidgets('of a text that ran without asking pages without asking', (tester) async {
      answerRun(ledger, () => Success(_recorded('query_page_postgres_first')), page: QueryPage.first);
      answerRun(ledger, () => Success(_recorded('query_page_postgres_second')), page: second);
      await pump(tester);
      await type(tester, ledger);
      await run(tester);

      await scrollToLoadMore(tester);
      await tester.tap(loadMore());
      await tester.pumpAndSettle();

      expect(find.byType(WriteConfirmationSheet), findsNothing);
      expect(runsOf(ledger), 2);
    });

    testWidgets('of a confirmed text asks again before the page, and sends it only on confirm', (tester) async {
      answerRun(flagged, () => Success(_recorded('query_page_postgres_first')), page: QueryPage.first);
      answerRun(flagged, () => Success(_recorded('query_page_postgres_second')), page: second);
      await pump(tester, connection: _production);
      await type(tester, flagged);
      await run(tester);
      await tester.enterText(find.byKey(WriteConfirmationSheet.nameFieldKey), 'Prod Postgres');
      await tester.pump();
      await confirm(tester);
      expect(runsOf(flagged), 1);

      // The footer's spinner turns while the sheet is open, so the sheet's opening is pumped, not settled.
      await scrollToLoadMore(tester);
      await tester.tap(loadMore());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(WriteConfirmationSheet), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(WriteConfirmationSheet.nameFieldKey)).controller!.text,
        isEmpty,
        reason: 'the typed name is asked again at each opening',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(
        () => repository.run(
          any(),
          flagged,
          queryId: any(named: 'queryId'),
          page: second,
        ),
      );

      await scrollToLoadMore(tester);
      await tester.tap(loadMore());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byKey(WriteConfirmationSheet.nameFieldKey), 'Prod Postgres');
      await tester.pump();
      await confirm(tester);

      verify(
        () => repository.run(
          any(),
          flagged,
          queryId: any(named: 'queryId'),
          page: second,
        ),
      ).called(1);
    });
  });

  testWidgets("a database error shows the database's words and places the cursor at its position", (tester) async {
    answerRun(
      'SELECT 1 FORM t',
      () => const Failure(ValidationError('syntax error at or near "FORM"', code: 'studio.query_error', position: 10)),
    );
    await pump(tester);
    await type(tester, 'SELECT 1 FORM t');

    await run(tester);

    expect(find.text('syntax error at or near "FORM"'), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(EditorInput.fieldKey));
    expect(field.controller!.selection, const TextSelection.collapsed(offset: 9));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('a rate limit shows the countdown, Run stays disabled until it ends, and nothing is retried', (
    tester,
  ) async {
    answerRun(
      'SELECT 1',
      () => const Failure(RateLimitedError('slow', code: 'studio.rate_limited', retryAfter: Duration(seconds: 2))),
    );
    await pump(tester);
    await type(tester, 'SELECT 1');

    await run(tester);
    expect(find.text('You can try again in 2 s.'), findsOneWidget);
    expect(runEnabled(tester), isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(runEnabled(tester), isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(runEnabled(tester), isTrue);
    expect(runsOf('SELECT 1'), 1);
  });

  group('the rolled-back notice', () {
    testWidgets('advises COMMIT on a SQL engine', (tester) async {
      answerRun('BEGIN', () => const Success(_rolledBack));
      await pump(tester);
      await type(tester, 'BEGIN');
      await run(tester);
      await confirm(tester);

      expect(find.textContaining('Add COMMIT to keep them.'), findsOneWidget);
    });

    testWidgets('advises EXEC on Redis', (tester) async {
      answerRun('MULTI', () => const Success(_rolledBack));
      await pump(tester, connection: _redis);
      await type(tester, 'MULTI');
      await run(tester);
      await confirm(tester);

      expect(find.textContaining('Add EXEC to keep them.'), findsOneWidget);
    });
  });

  testWidgets('a rotation keeps the text, its selection and the result', (tester) async {
    answerRun('SELECT * FROM customers', () => Success(_recorded('query_preview_postgres_customers')));
    await pump(tester, size: const Size(400, 800));
    await type(tester, 'SELECT * FROM customers');
    await run(tester);
    final field = tester.widget<TextField>(find.byKey(EditorInput.fieldKey));
    field.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.pump();
    final results = BlocProvider.of<ResultViewBloc>(tester.element(find.textContaining('Ada Lovelace').first));

    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rotated = tester.widget<TextField>(find.byKey(EditorInput.fieldKey));
    expect(rotated.controller!.text, 'SELECT * FROM customers');
    expect(rotated.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 6));
    expect(find.textContaining('Ada Lovelace'), findsWidgets);
    expect(BlocProvider.of<ResultViewBloc>(tester.element(find.textContaining('Ada Lovelace').first)), same(results));
    expect(runsOf('SELECT * FROM customers'), 1);
  });
}
