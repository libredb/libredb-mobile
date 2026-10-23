@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/sql_page.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_catalog_chip.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/answered.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
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
const _server = StudioConnection(
  id: 'seed:dev-postgres-server',
  name: 'Dev Postgres server',
  type: 'postgres',
  environment: 'development',
);

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
  late MockIContainersRepository containers;
  late MockIActiveCatalogStore catalogStore;
  late ActiveCatalogCubit catalog;

  setUp(() {
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    for (final connection in [_postgres, _production]) {
      when(() => providerMeta.providerMeta(connection.id))
          .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    }
    when(() => providerMeta.providerMeta(_redis.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_redis'))));
    when(() => providerMeta.providerMeta(_server.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres_server'))));
    containers = MockIContainersRepository();
    catalogStore = MockIActiveCatalogStore();
    when(() => catalogStore.read(any(), any())).thenAnswer((_) async => null);
    when(() => catalogStore.write(any(), any(), any())).thenAnswer((_) async {});
    catalog = ActiveCatalogCubit(store: catalogStore, connectionIds: const Stream.empty());
    active = MockActiveConnectionCubit();
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  });

  tearDown(() async {
    await schemaChanges.dispose();
    await catalog.close();
  });

  void answerRun(String sql, Result<QueryResult> Function() answer, {QueryPage? page}) => when(
    () => repository.run(
      any(),
      sql,
      queryId: any(named: 'queryId'),
      page: page ?? any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
    ),
  ).thenAnswer((_) async => answer());

  int runsOf(String sql) => verify(
    () => repository.run(
      any(),
      sql,
      queryId: any(named: 'queryId'),
      page: any(named: 'page'),
      cancelSignal: any(named: 'cancelSignal'),
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
      cancelSignal: any(named: 'cancelSignal'),
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    StudioConnection? connection = _postgres,
    bool offline = false,
    bool recordsInFull = false,
    Size? size,
    Locale? locale,
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
          RepositoryProvider<IContainersRepository>.value(value: containers),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider<ActiveCatalogCubit>.value(value: catalog),
            BlocProvider<ResultViewModeCubit>(create: (_) => ResultViewModeCubit(store: MockIResultViewModeStore())),
          ],
          child: MaterialApp(
            locale: locale,
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
    expect(find.text('The database did not allow this. You may lack a privilege on this object.'), findsOneWidget);
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
          cancelSignal: any(named: 'cancelSignal'),
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
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).called(1);
    });
  });

  group('the database of a server-level connection', () {
    const sql = 'SELECT current_database()';
    const subject = '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10';

    Finder chip() => find.byKey(EditorCatalogChip.chipKey);

    void answerDatabases() => when(() => containers.containers(_server.id, refresh: any(named: 'refresh'))).thenAnswer(
      (_) async =>
          Success(Answered(ObjectBrowserJson.containers(_fixture('containers_postgres_server')), at: DateTime(2026))),
    );

    void answerCurrentDatabase() =>
        when(
          () => repository.run(
            _server.id,
            sql,
            queryId: any(named: 'queryId'),
            page: any(named: 'page'),
            cancelSignal: any(named: 'cancelSignal'),
            catalog: any(named: 'catalog'),
          ),
        ).thenAnswer((invocation) async {
          // The recorded answer of `archive`, as the database Studio ran in names itself.
          final database = invocation.namedArguments[#catalog] as String;
          return Success(
            QueryResultJson.read(_fixture('query_catalog_postgres_server').replaceAll('"archive"', '"$database"')),
          );
        });

    List<Object?> sentCatalogs() => verify(
      () => repository.run(
        any(),
        any(),
        queryId: any(named: 'queryId'),
        page: any(named: 'page'),
        cancelSignal: any(named: 'cancelSignal'),
        catalog: captureAny(named: 'catalog'),
      ),
    ).captured;

    Future<void> pick(WidgetTester tester, String database) async {
      await tester.tap(chip());
      await tester.pumpAndSettle();
      expect(find.text('Run statements in'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(database)));
      await tester.pumpAndSettle();
    }

    testWidgets('on seed:dev-postgres no chip shows and no database is sent', (tester) async {
      answerRun('SELECT 1', () => Success(_recorded('query_preview_postgres_customers')));
      await pump(tester);
      await tester.pumpAndSettle();

      expect(chip(), findsNothing);
      await type(tester, 'SELECT 1');
      await run(tester);

      expect(sentCatalogs(), [null]);
      verifyNever(() => containers.containers(any(), refresh: any(named: 'refresh')));
    });

    testWidgets('runs in the first listed database, then in the picked one, keeping the text', (tester) async {
      answerDatabases();
      answerCurrentDatabase();
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();

      expect(find.descendant(of: chip(), matching: find.text('Database: app')), findsOneWidget);
      await type(tester, sql);
      await run(tester);
      expect(find.text('app'), findsWidgets);

      await pick(tester, 'archive');
      expect(find.descendant(of: chip(), matching: find.text('Database: archive')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(EditorInput.fieldKey)).controller!.text, sql);
      await run(tester);

      expect(sentCatalogs(), ['app', 'archive']);
      expect(find.text('archive'), findsWidgets);
      expect(catalog.catalogOf(_server.id), 'archive');
    });

    testWidgets('shows the database opened in Browse', (tester) async {
      answerDatabases();
      catalog.choose(_server.id, 'archive');
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();

      expect(find.descendant(of: chip(), matching: find.text('Database: archive')), findsOneWidget);
    });

    testWidgets('chooses the remembered database again while the server lists it', (tester) async {
      answerDatabases();
      when(() => catalogStore.read(subject, _server.id)).thenAnswer((_) async => 'archive');
      catalog.signedIn(subject);
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();

      expect(find.descendant(of: chip(), matching: find.text('Database: archive')), findsOneWidget);
    });

    testWidgets('chooses the first listed when the server no longer lists the remembered one', (tester) async {
      answerDatabases();
      when(() => catalogStore.read(subject, _server.id)).thenAnswer((_) async => 'gone');
      catalog.signedIn(subject);
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();

      expect(find.descendant(of: chip(), matching: find.text('Database: app')), findsOneWidget);
      verify(() => catalogStore.write(subject, _server.id, 'app')).called(1);
    });

    testWidgets('a failed list shows its error with a retry, and Run waits for a database', (tester) async {
      when(() => containers.containers(_server.id, refresh: any(named: 'refresh')))
          .thenAnswer((_) async => const Failure(ServerError('down', code: 'studio.internal_error')));
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();
      await type(tester, sql);

      expect(find.text('The databases to run statements in could not be listed.'), findsOneWidget);
      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(runEnabled(tester), isFalse);

      answerDatabases();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.descendant(of: chip(), matching: find.text('Database: app')), findsOneWidget);
      expect(runEnabled(tester), isTrue);
    });

    testWidgets('Run waits while the engine is still read, so nothing is sent without a database', (tester) async {
      final meta = Completer<Result<ProviderMeta>>();
      when(() => providerMeta.providerMeta(_server.id)).thenAnswer((_) => meta.future);
      answerDatabases();
      await pump(tester, connection: _server);
      await type(tester, sql);

      expect(runEnabled(tester), isFalse);
      expect(chip(), findsNothing);

      meta.complete(Success(ProviderMetaJson.read(_fixture('meta_postgres_server'))));
      await tester.pumpAndSettle();

      expect(find.descendant(of: chip(), matching: find.text('Database: app')), findsOneWidget);
      expect(runEnabled(tester), isTrue);
    });

    testWidgets('a provider-meta failure on an ordinary connection shows Studio\'s error with a retry, no databases', (
      tester,
    ) async {
      var calls = 0;
      when(() => providerMeta.providerMeta(_postgres.id)).thenAnswer((_) async {
        if (++calls == 1) return const Failure(ServerError('down', code: 'studio.internal_error'));
        return Success(ProviderMetaJson.read(_fixture('meta_postgres')));
      });
      await pump(tester);
      await tester.pumpAndSettle();
      await type(tester, 'SELECT 1');

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.text('The databases to run statements in could not be listed.'), findsNothing);
      expect(runEnabled(tester), isFalse);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(StudioErrorBanner), findsNothing);
      expect(chip(), findsNothing);
      expect(runEnabled(tester), isTrue);
    });

    testWidgets('a server that lists no database offers no Run', (tester) async {
      when(() => containers.containers(_server.id, refresh: any(named: 'refresh')))
          .thenAnswer((_) async => Success(Answered(const [], at: DateTime(2026))));
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();
      await type(tester, sql);

      expect(find.text('The server lists no database to run statements in.'), findsOneWidget);
      expect(runEnabled(tester), isFalse);
    });

    testWidgets('Load more sends the same database as the first page', (tester) async {
      const orders = 'SELECT * FROM public.orders';
      answerDatabases();
      when(
        () => repository.run(
          _server.id,
          orders,
          queryId: any(named: 'queryId'),
          page: QueryPage.first,
          cancelSignal: any(named: 'cancelSignal'),
          catalog: any(named: 'catalog'),
        ),
      ).thenAnswer((_) async => Success(_recorded('query_page_postgres_first')));
      when(
        () => repository.run(
          _server.id,
          orders,
          queryId: any(named: 'queryId'),
          page: QueryPage.after(_recorded('query_page_postgres_first').pagination!),
          cancelSignal: any(named: 'cancelSignal'),
          catalog: any(named: 'catalog'),
        ),
      ).thenAnswer((_) async => Success(_recorded('query_page_postgres_second')));
      await pump(tester, connection: _server);
      await tester.pumpAndSettle();
      await pick(tester, 'archive');
      await type(tester, orders);
      await run(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('result-load-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Load 50 more'));
      await tester.pumpAndSettle();

      expect(sentCatalogs(), ['archive', 'archive']);
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

  testWidgets('a cancelled confirmation after a database error leaves the cursor where the user put it', (
    tester,
  ) async {
    answerRun(
      'SELECT 1 FORM t',
      () => const Failure(ValidationError('syntax error at or near "FORM"', code: 'studio.query_error', position: 10)),
    );
    await pump(tester);
    await type(tester, 'SELECT 1 FORM t');
    await run(tester);
    final controller = tester.widget<TextField>(find.byKey(EditorInput.fieldKey)).controller!;
    expect(controller.selection, const TextSelection.collapsed(offset: 9));

    await type(tester, 'DELETE FROM orders WHERE id = 1234567890');
    controller.selection = const TextSelection.collapsed(offset: 30);
    await tester.pump();
    await run(tester);
    expect(find.byType(WriteConfirmationSheet), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.selection, const TextSelection.collapsed(offset: 30));
    expect(runsOf('SELECT 1 FORM t'), 1);
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

  group('Cancel', () {
    /// Holds the run of [sql] until the returned completer answers, or fails it as cancelled once its request is
    /// dropped, as ApiClient does.
    Completer<Result<QueryResult>> holdRun(String sql) {
      final answer = Completer<Result<QueryResult>>();
      when(
        () => repository.run(
          any(),
          sql,
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((invocation) {
        final signal = invocation.namedArguments[#cancelSignal] as CancelSignal?;
        return Future.any([
          answer.future,
          if (signal != null)
            signal.whenCancelled.then((_) => const Failure<QueryResult>(RequestCancelledError('Request cancelled'))),
        ]);
      });
      return answer;
    }

    String buttonLabel(WidgetTester tester) =>
        tester.widget<Text>(find.descendant(of: runButton(), matching: find.byType(Text))).data!;

    Future<void> startRun(WidgetTester tester, {StudioConnection connection = _postgres, Locale? locale}) async {
      holdRun('SELECT pg_sleep(30)');
      await pump(tester, connection: connection, locale: locale);
      await type(tester, 'SELECT pg_sleep(30)');
      await tester.tap(runButton());
      await tester.pump();
      if (connection == _redis) {
        // Redis is not SQL, so the text asks first; the run's spinner never settles, so the sheet's exit is pumped.
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Run').last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
    }

    testWidgets('Run reads Cancel while the statement runs, and a confirmed cancel says Cancelled, not an error', (
      tester,
    ) async {
      when(() => repository.cancel(any(), any())).thenAnswer((_) async => const Success(true));
      await startRun(tester);

      expect(buttonLabel(tester), 'Cancel');
      expect(runEnabled(tester), isTrue);
      await tester.tap(runButton());
      await tester.pump();
      await tester.pump();

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byType(StudioErrorBanner), findsNothing);
      expect(buttonLabel(tester), 'Run');
      verify(() => repository.cancel(_postgres.id, any())).called(1);
    });

    testWidgets('says Studio could not confirm the cancel when it answers cancelled: false', (tester) async {
      when(() => repository.cancel(any(), any())).thenAnswer((_) async => const Success(false));
      await startRun(tester);

      await tester.tap(runButton());
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Studio could not confirm the cancel.'), findsOneWidget);
      expect(find.textContaining('may still run on the server'), findsOneWidget);
    });

    testWidgets('reads Cancelling and is disabled while the cancel is posted', (tester) async {
      final cancelled = Completer<Result<bool>>();
      when(() => repository.cancel(any(), any())).thenAnswer((_) => cancelled.future);
      await startRun(tester);

      await tester.tap(runButton());
      await tester.pump();

      expect(buttonLabel(tester), 'Cancelling');
      expect(runEnabled(tester), isFalse);
      cancelled.complete(const Success(true));
      await tester.pump();
    });

    testWidgets('an engine without cancel reads Stop waiting, posts nothing, and says the statement may still run', (
      tester,
    ) async {
      await startRun(tester, connection: _redis);

      expect(buttonLabel(tester), 'Stop waiting');
      await tester.tap(runButton());
      await tester.pump();

      expect(find.textContaining('Stopped waiting.'), findsOneWidget);
      expect(find.textContaining('may still run on the server'), findsOneWidget);
      verifyNever(() => repository.cancel(any(), any()));
    });

    testWidgets('a rate limit on the cancel shows the countdown, keeps the run, and Cancel waits for it', (
      tester,
    ) async {
      when(() => repository.cancel(any(), any())).thenAnswer(
        (_) async =>
            const Failure(RateLimitedError('slow', code: 'studio.rate_limited', retryAfter: Duration(seconds: 2))),
      );
      await startRun(tester);

      await tester.tap(runButton());
      await tester.pump();
      await tester.pump();

      expect(find.text('You can try again in 2 s.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(buttonLabel(tester), 'Cancel');
      expect(runEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(runEnabled(tester), isTrue);
      verify(() => repository.cancel(any(), any())).called(1);
    });

    testWidgets('after a cancel that failed otherwise, offers Stop waiting beside Cancel, which posts nothing more', (
      tester,
    ) async {
      when(() => repository.cancel(any(), any()))
          .thenAnswer((_) async => const Failure(NetworkError('No Internet connection')));
      await startRun(tester);

      await tester.tap(runButton());
      await tester.pump();
      await tester.pump();

      expect(buttonLabel(tester), 'Cancel');
      expect(runEnabled(tester), isTrue);
      final stopWaiting = find.byKey(EditorActions.stopWaitingKey);
      expect(find.descendant(of: stopWaiting, matching: find.text('Stop waiting')), findsOneWidget);
      await tester.tap(stopWaiting);
      await tester.pump();

      expect(find.textContaining('Stopped waiting.'), findsOneWidget);
      expect(find.byKey(EditorActions.stopWaitingKey), findsNothing);
      verify(() => repository.cancel(any(), any())).called(1);
    });

    testWidgets('after a rate limit on the cancel offers no Stop waiting', (tester) async {
      when(() => repository.cancel(any(), any())).thenAnswer(
        (_) async =>
            const Failure(RateLimitedError('slow', code: 'studio.rate_limited', retryAfter: Duration(seconds: 2))),
      );
      await startRun(tester);

      await tester.tap(runButton());
      await tester.pump();
      await tester.pump();

      expect(find.byKey(EditorActions.stopWaitingKey), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    });

    testWidgets('the labels are in Turkish', (tester) async {
      when(() => repository.cancel(any(), any())).thenAnswer((_) async => const Success(true));
      await startRun(tester, locale: const Locale('tr'));

      expect(buttonLabel(tester), 'İptal et');
      await tester.tap(runButton());
      await tester.pump();
      await tester.pump();

      expect(find.text('İptal edildi'), findsOneWidget);
    });
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
