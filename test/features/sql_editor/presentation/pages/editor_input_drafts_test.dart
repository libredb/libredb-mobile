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
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/sql_editor/domain/editor_language.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_text_store.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/pages/sql_page.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_accessory_row.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_draft_notice.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_language_label.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_result_area.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/highlighting_text_controller.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/studio/provider_meta_json.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/answered.dart';
import 'package:libredb_mobile/shared/models/containers_repository.dart';
import 'package:libredb_mobile/shared/models/object_container.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/utils/source_highlighter.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';
import 'package:libredb_mobile/shared/widgets/studio_subject_scope.dart';
import 'package:libredb_mobile/shared/utils/app_lifecycle_source.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

String _fixture(String name) => File('test/fixtures/studio/$name.json').readAsStringSync();

const _postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev Postgres', type: 'postgres');
const _redis = StudioConnection(id: 'seed:dev-redis', name: 'Dev Redis', type: 'redis');
const _server = StudioConnection(id: 'seed:dev-postgres-server', name: 'Dev Postgres server', type: 'postgres');
const _alice = 'alice-hash';
const _bob = 'bob-hash';

Failure<T> _failure<T>(AppErrorCode code) => Failure<T>(UnknownError('store', code: code.key));

/// The editor's input aids and its drafts: highlighting with the language label, the accessory row, and the draft of
/// each connection kept through `IStatementTextStore` for the signed-in account.
void main() {
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockIStatementTextStore store;
  late MockActiveConnectionCubit active;
  late StreamController<ActiveConnectionState> connections;
  late SchemaChangeNotifier schemaChanges;
  late MockIStatementHistoryRepository history;
  late MockIContainersRepository containers;
  late ActiveCatalogCubit catalog;

  setUp(() {
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(_postgres.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres'))));
    when(() => providerMeta.providerMeta(_redis.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_redis'))));
    store = MockIStatementTextStore();
    when(() => store.readDraft(any(), any())).thenAnswer((_) async => const Success(null));
    when(() => store.saveDraft(any(), any(), any())).thenAnswer((_) async => const Success(DraftSaveOutcome.kept));
    when(() => store.discardDraft(any(), any())).thenAnswer((_) async => const Success(null));
    active = MockActiveConnectionCubit();
    connections = StreamController<ActiveConnectionState>();
    when(() => providerMeta.providerMeta(_server.id))
        .thenAnswer((_) async => Success(ProviderMetaJson.read(_fixture('meta_postgres_server'))));
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
    history = MockIStatementHistoryRepository();
    when(() => history.record(any(), any())).thenAnswer(
      (invocation) async => Success(
        StatementHistoryEntry(
          id: 'entry',
          connectionId: _postgres.id,
          connectionName: _postgres.name,
          text: (invocation.positionalArguments[1] as FinishedRun).text,
          status: StatementRunStatus.success,
          duration: Duration.zero,
          executedAt: DateTime.utc(2026, 10, 23),
        ),
      ),
    );
    containers = MockIContainersRepository();
    when(() => containers.containers(_server.id, refresh: any(named: 'refresh'))).thenAnswer(
      (_) async =>
          Success(Answered(ObjectBrowserJson.containers(_fixture('containers_postgres_server')), at: DateTime(2026))),
    );
    final catalogStore = MockIActiveCatalogStore();
    when(() => catalogStore.read(any(), any())).thenAnswer((_) async => null);
    when(() => catalogStore.write(any(), any(), any())).thenAnswer((_) async {});
    catalog = ActiveCatalogCubit(store: catalogStore, connectionIds: const Stream.empty());
  });

  tearDown(() async {
    await schemaChanges.dispose();
    await connections.close();
    await catalog.close();
  });

  /// Shows the SQL tab, or [other] in its place when [showEditor] is false, as leaving the tab does.
  Widget app({required ValueNotifier<bool> showEditor, String? subject, double textScale = 1}) =>
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ISqlEditorRepository>.value(value: repository),
          RepositoryProvider<IProviderMetaRepository>.value(value: providerMeta),
          RepositoryProvider<IStatementTextStore>.value(value: store),
          RepositoryProvider<IAppLifecycleSource>(
            create: (_) => BindingAppLifecycleSource(),
            dispose: (source) => (source as BindingAppLifecycleSource).dispose(),
          ),
          RepositoryProvider<IBackgroundRunTime>.value(value: const NoBackgroundRunTime()),
          RepositoryProvider<SchemaChangeNotifier>.value(value: schemaChanges),
          RepositoryProvider<IStatementHistoryRepository>.value(value: history),
          RepositoryProvider<IContainersRepository>.value(value: containers),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider<ActiveCatalogCubit>.value(value: catalog),
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: StudioSubjectScope(
                subjectHash: subject,
                child: StudioRoleScope(
                  role: const StudioUserRole(),
                  child: StatementCaptureScope(
                    recordsInFull: false,
                    child: OfflineStatus(
                      isOffline: false,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: showEditor,
                        builder: (context, show, _) => show ? const SqlPage() : const Text('browse root'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<ValueNotifier<bool>> pump(
    WidgetTester tester, {
    StudioConnection connection = _postgres,
    String? subject = _alice,
    double textScale = 1,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(active, connections.stream, initialState: ActiveConnectionSelected(connection));
    final showEditor = ValueNotifier(true);
    addTearDown(showEditor.dispose);
    await tester.pumpWidget(app(showEditor: showEditor, subject: subject, textScale: textScale));
    await tester.pump();
    await tester.pump();
    return showEditor;
  }

  Finder field() => find.byKey(EditorInput.fieldKey);

  HighlightingTextController controller(WidgetTester tester) =>
      tester.widget<TextField>(field()).controller! as HighlightingTextController;

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field(), text);
    await tester.pump();
  }

  List<StatementDraft> saved(String connectionId, {String subject = _alice}) =>
      verify(() => store.saveDraft(subject, connectionId, captureAny())).captured.cast<StatementDraft>();

  group('highlighting', () {
    /// The token kinds the field paints for its text, keyword pieces only.
    List<String> keywords(WidgetTester tester) {
      final context = tester.element(field());
      final span = controller(tester).buildTextSpan(context: context, style: const TextStyle(), withComposing: false);
      final keyword = HighlightingTextController.stylesOf(
        Theme.of(context).colorScheme,
        const TextStyle(),
      )[SourceTokenKind.keyword]!;
      return [
        for (final child in span.children ?? const <InlineSpan>[])
          if ((child as TextSpan).style == keyword) child.text!,
      ];
    }

    testWidgets('select * from orders shows select and from as keywords on Postgres, with the language label', (
      tester,
    ) async {
      await pump(tester);
      await type(tester, 'select * from orders');

      expect(controller(tester).highlighting, EditorHighlighting.sql);
      expect(keywords(tester), ['select', 'from']);
      expect(find.byKey(EditorLanguageLabel.labelKey), findsOneWidget);
      expect(find.text('Language: sql'), findsOneWidget);
    });

    testWidgets('the same text is plain on Redis, named by its dialect', (tester) async {
      await pump(tester, connection: _redis);
      await type(tester, 'select * from orders');

      expect(controller(tester).highlighting, EditorHighlighting.plain);
      expect(keywords(tester), isEmpty);
      expect(find.text('Language: redis'), findsOneWidget);
    });

    testWidgets('a meta Studio refused leaves the text plain and says why', (tester) async {
      when(
        () => providerMeta.providerMeta(_postgres.id),
      ).thenAnswer((_) async => Failure(UnknownError('refused', code: AppErrorCode.studioConnectionNotAvailable.key)));
      await pump(tester);
      await type(tester, 'select 1');

      expect(controller(tester).highlighting, EditorHighlighting.plain);
      expect(find.textContaining('could not be read, so the text is not highlighted'), findsOneWidget);
    });
  });

  group('the accessory row', () {
    testWidgets('shows while the field has focus, and inserts at the cursor or in place of the selection', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(EditorAccessoryRow), findsNothing);

      await tester.showKeyboard(field());
      await type(tester, 'select  from t');
      controller(tester).selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();
      expect(find.byType(EditorAccessoryRow), findsOneWidget);

      await tester.tap(find.byKey(EditorAccessoryRow.symbolKey('*')));
      await tester.pump();
      expect(controller(tester).text, 'select * from t');
      expect(controller(tester).selection, const TextSelection.collapsed(offset: 8));
      expect(tester.testTextInput.isVisible, isTrue);

      controller(tester).selection = const TextSelection(baseOffset: 14, extentOffset: 15);
      await tester.ensureVisible(find.byKey(EditorAccessoryRow.symbolKey(';')));
      await tester.tap(find.byKey(EditorAccessoryRow.symbolKey(';')));
      await tester.pump();
      expect(controller(tester).text, 'select * from ;');
    });

    testWidgets('Undo and Redo walk the edits', (tester) async {
      await pump(tester);
      await tester.showKeyboard(field());
      await type(tester, 'select 1');
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(EditorAccessoryRow.tabKey));
      await tester.tap(find.byKey(EditorAccessoryRow.tabKey));
      await tester.pump(const Duration(seconds: 1));
      expect(controller(tester).text, 'select 1  ');

      await tester.ensureVisible(find.byKey(EditorAccessoryRow.undoKey));
      await tester.tap(find.byKey(EditorAccessoryRow.undoKey));
      await tester.pump();
      expect(controller(tester).text, 'select 1');

      await tester.tap(find.byKey(EditorAccessoryRow.redoKey));
      await tester.pump();
      expect(controller(tester).text, 'select 1  ');
    });

    testWidgets('at the largest text scale with the keyboard up, overlaps neither the field nor the result', (
      tester,
    ) async {
      when(
        () => repository.run(
          any(),
          any(),
          queryId: any(named: 'queryId'),
          page: any(named: 'page'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer((_) async => Success(QueryResultJson.read(_fixture('query_preview_postgres_customers'))));
      await pump(tester, textScale: 3.2);
      await type(tester, 'SELECT * FROM customers');
      await tester.tap(find.byKey(EditorActions.runKey));
      await tester.pumpAndSettle();
      await tester.showKeyboard(field());
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(EditorAccessoryRow));
      final input = tester.getRect(field());
      final result = tester.getRect(find.byType(EditorResultArea));
      expect(row.overlaps(input), isFalse);
      expect(row.overlaps(result), isFalse);
      expect(row.bottom, lessThanOrEqualTo(800 - 250));
      for (final key in [
        for (final symbol in EditorAccessoryRow.symbols) EditorAccessoryRow.symbolKey(symbol),
        EditorAccessoryRow.tabKey,
        EditorAccessoryRow.undoKey,
        EditorAccessoryRow.redoKey,
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pump();
        expect(tester.getRect(find.byKey(key)).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('drafts', () {
    testWidgets("opening the editor restores the connection's draft for the signed-in account", (tester) async {
      when(() => store.readDraft(_alice, _postgres.id))
          .thenAnswer((_) async => const Success(StatementDraft(text: 'select 42')));
      await pump(tester);

      expect(controller(tester).text, 'select 42');
      verify(() => store.readDraft(_alice, _postgres.id)).called(1);
      await tester.pump(const Duration(seconds: 2));
      verifyNever(() => store.saveDraft(any(), any(), any()));
    });

    testWidgets('another account reads only its own drafts', (tester) async {
      await pump(tester, subject: _bob);

      verify(() => store.readDraft(_bob, _postgres.id)).called(1);
      verifyNever(() => store.readDraft(_alice, any()));
    });

    testWidgets('until Studio names the account the field stays editable, says no text is kept, and keeps none', (
      tester,
    ) async {
      await pump(tester, subject: null);

      expect(tester.widget<TextField>(field()).readOnly, isFalse);
      expect(find.text('Text is not kept until Studio names your account.'), findsOneWidget);
      await type(tester, 'select 1');
      await tester.pump(const Duration(seconds: 2));
      verifyZeroInteractions(store);
    });

    testWidgets('with an account the first frame says nothing about a missing account', (tester) async {
      whenListen(active, connections.stream, initialState: const ActiveConnectionSelected(_postgres));
      final showEditor = ValueNotifier(true);
      addTearDown(showEditor.dispose);
      await tester.pumpWidget(app(showEditor: showEditor, subject: _alice));

      expect(find.byKey(EditorInput.fieldKey), findsOneWidget);
      expect(find.text('Text is not kept until Studio names your account.'), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(find.text('Text is not kept until Studio names your account.'), findsNothing);
    });

    group('a text typed before Studio names the account, with a saved draft', () {
      Future<void> nameTheAccount(WidgetTester tester) async {
        when(() => store.readDraft(_alice, _postgres.id))
            .thenAnswer((_) async => const Success(StatementDraft(text: 'saved draft')));
        final showEditor = await pump(tester, subject: null);
        await type(tester, 'typed early');
        await tester.pumpWidget(app(showEditor: showEditor, subject: _alice));
        await tester.pumpAndSettle();
      }

      testWidgets('asks, and Replace restores the saved draft and saves nothing', (tester) async {
        await nameTheAccount(tester);
        expect(find.text("Replace the editor's text?"), findsOneWidget);
        expect(controller(tester).text, 'typed early');

        await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));

        expect(controller(tester).text, 'saved draft');
        verifyNever(() => store.saveDraft(any(), any(), any()));
      });

      testWidgets('asks, and Cancel keeps the typed text, which is then saved as the draft', (tester) async {
        await nameTheAccount(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        expect(controller(tester).text, 'typed early');
        expect(saved(_postgres.id), [const StatementDraft(text: 'typed early')]);
      });
    });

    testWidgets('once Studio names the account the saved draft is restored and the field opens', (tester) async {
      when(() => store.readDraft(_alice, _postgres.id))
          .thenAnswer((_) async => const Success(StatementDraft(text: 'select 14')));
      final showEditor = await pump(tester, subject: null);

      await tester.pumpWidget(app(showEditor: showEditor, subject: _alice));
      await tester.pump();
      await tester.pump();

      expect(controller(tester).text, 'select 14');
      expect(tester.widget<TextField>(field()).readOnly, isFalse);
      expect(find.text('Text is not kept until Studio names your account.'), findsNothing);
    });

    testWidgets('a save refused as the editor closes is said on the app messenger', (tester) async {
      when(() => store.saveDraft(any(), any(), any()))
          .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextNotStored));
      final showEditor = await pump(tester);
      await type(tester, 'select 15');

      showEditor.value = false;
      await tester.pump();
      await tester.pump();

      expect(find.text('browse root'), findsOneWidget);
      expect(find.textContaining('The text could not be saved on this phone.'), findsOneWidget);
    });

    testWidgets('typing is saved once it pauses for a second', (tester) async {
      await pump(tester);
      await type(tester, 'select 1');
      await tester.pump(const Duration(milliseconds: 500));
      verifyNever(() => store.saveDraft(any(), any(), any()));

      await tester.pump(const Duration(milliseconds: 600));
      expect(saved(_postgres.id), [const StatementDraft(text: 'select 1')]);
    });

    testWidgets('leaving the tab saves the text at once, and coming back restores it', (tester) async {
      final showEditor = await pump(tester);
      await type(tester, 'select 2');

      showEditor.value = false;
      await tester.pump();
      expect(saved(_postgres.id), [const StatementDraft(text: 'select 2')]);

      when(() => store.readDraft(_alice, _postgres.id))
          .thenAnswer((_) async => const Success(StatementDraft(text: 'select 2')));
      showEditor.value = true;
      await tester.pump();
      await tester.pump();
      expect(controller(tester).text, 'select 2');
    });

    testWidgets("switching the connection saves the current draft first and opens the other connection's", (
      tester,
    ) async {
      when(() => store.readDraft(_alice, _redis.id))
          .thenAnswer((_) async => const Success(StatementDraft(text: 'GET key')));
      await pump(tester);
      await type(tester, 'select 3');

      connections.add(const ActiveConnectionSelected(_redis));
      await tester.pump();
      await tester.pump();

      expect(saved(_postgres.id), [const StatementDraft(text: 'select 3')]);
      expect(controller(tester).text, 'GET key');
      verify(() => store.readDraft(_alice, _redis.id)).called(1);
    });

    testWidgets('a vanished connection keeps its draft', (tester) async {
      await pump(tester);
      await type(tester, 'select 4');

      connections.add(const ActiveConnectionVanished(_postgres));
      await tester.pump();

      expect(saved(_postgres.id), [const StatementDraft(text: 'select 4')]);
    });

    testWidgets('the app going to the background saves the text at once', (tester) async {
      await pump(tester);
      await type(tester, 'select 5');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(saved(_postgres.id), [const StatementDraft(text: 'select 5')]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      verifyNever(() => store.saveDraft(any(), any(), any()));
    });

    testWidgets('a save the phone refuses is shown with its reason', (tester) async {
      when(() => store.saveDraft(any(), any(), any()))
          .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextNotStored));
      await pump(tester);
      await type(tester, 'select 6');
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('The text could not be saved on this phone.'), findsOneWidget);
      expect(find.textContaining('Check its free storage'), findsOneWidget);
      // The editor saves again as the test closes it, which the app's messenger, gone by then, could not say.
      when(() => store.saveDraft(any(), any(), any())).thenAnswer((_) async => const Success(DraftSaveOutcome.kept));
    });

    testWidgets('a text over 100,000 characters is not kept, and the page says so once', (tester) async {
      when(() => store.saveDraft(any(), any(), any())).thenAnswer(
        (invocation) async => Success(
          (invocation.positionalArguments[2] as StatementDraft).text.length > IStatementTextStore.maxTextLength
              ? DraftSaveOutcome.notKept
              : DraftSaveOutcome.kept,
        ),
      );
      await pump(tester);
      final long = 'x' * (IStatementTextStore.maxTextLength + 1);
      await type(tester, long);
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('longer than 100,000 characters'), findsOneWidget);
      await type(tester, '${long}y');
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('longer than 100,000 characters'), findsOneWidget);

      await type(tester, 'select 7');
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('longer than 100,000 characters'), findsNothing);
    });

    testWidgets('an unreadable saved draft shows the message with Discard, and keeps nothing until it is discarded', (
      tester,
    ) async {
      when(() => store.readDraft(_alice, _postgres.id))
          .thenAnswer((_) async => _failure(AppErrorCode.editorSavedTextUnreadable));
      await pump(tester);

      expect(find.textContaining('cannot be read'), findsOneWidget);
      expect(find.textContaining('New text is not kept until you discard the saved text.'), findsOneWidget);
      await type(tester, 'select 8');
      await tester.pump(const Duration(seconds: 2));
      verifyNever(() => store.saveDraft(any(), any(), any()));

      await tester.tap(find.byKey(EditorDraftNotice.discardKey));
      await tester.pumpAndSettle();
      expect(find.text('Discard the saved text?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => store.discardDraft(any(), any()));

      await tester.tap(find.byKey(EditorDraftNotice.discardKey));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      verify(() => store.discardDraft(_alice, _postgres.id)).called(1);
      expect(find.textContaining('cannot be read'), findsNothing);
      expect(saved(_postgres.id), [const StatementDraft(text: 'select 8')]);
    });

    group('on a server-level connection', () {
      testWidgets('a restored draft keeps its database while the databases cannot be listed', (tester) async {
        when(
          () => containers.containers(_server.id, refresh: any(named: 'refresh')),
        ).thenAnswer((_) async => Failure(UnknownError('down', code: AppErrorCode.studioConnectionNotAvailable.key)));
        when(() => store.readDraft(_alice, _server.id))
            .thenAnswer((_) async => const Success(StatementDraft(text: 'select 16', catalog: 'archive')));
        await pump(tester, connection: _server);
        await tester.pumpAndSettle();
        expect(controller(tester).text, 'select 16');

        await type(tester, 'select 17');
        await tester.pump(const Duration(seconds: 1));

        expect(saved(_server.id), [const StatementDraft(text: 'select 17', catalog: 'archive')]);
      });

      testWidgets('leaving before the databases are listed keeps the restored draft and its database', (tester) async {
        final listed = Completer<Result<Answered<List<ObjectContainer>>>>();
        when(() => containers.containers(_server.id, refresh: any(named: 'refresh'))).thenAnswer((_) => listed.future);
        when(() => store.readDraft(_alice, _server.id))
            .thenAnswer((_) async => const Success(StatementDraft(text: 'select 18', catalog: 'archive')));
        final showEditor = await pump(tester, connection: _server);
        await tester.pump();
        expect(controller(tester).text, 'select 18');

        showEditor.value = false;
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        verifyNever(() => store.saveDraft(any(), any(), any()));
      });

      testWidgets('the draft is saved with the active database', (tester) async {
        await pump(tester, connection: _server);
        await tester.pumpAndSettle();
        expect(catalog.catalogOf(_server.id), 'app');

        await type(tester, 'select 10');
        await tester.pump(const Duration(seconds: 1));

        expect(saved(_server.id), [const StatementDraft(text: 'select 10', catalog: 'app')]);
      });

      testWidgets('restoring the draft makes its database active again while the server lists it', (tester) async {
        when(() => store.readDraft(_alice, _server.id))
            .thenAnswer((_) async => const Success(StatementDraft(text: 'select 11', catalog: 'archive')));
        await pump(tester, connection: _server);
        await tester.pumpAndSettle();

        expect(controller(tester).text, 'select 11');
        expect(catalog.catalogOf(_server.id), 'archive');
        await tester.pump(const Duration(seconds: 2));
        verifyNever(() => store.saveDraft(any(), any(), any()));
      });

      testWidgets('a database the server no longer lists keeps the default, and the draft takes it', (tester) async {
        when(() => store.readDraft(_alice, _server.id))
            .thenAnswer((_) async => const Success(StatementDraft(text: 'select 12', catalog: 'gone')));
        await pump(tester, connection: _server);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        expect(controller(tester).text, 'select 12');
        expect(catalog.catalogOf(_server.id), 'app');
        expect(saved(_server.id), [const StatementDraft(text: 'select 12', catalog: 'app')]);
      });

      testWidgets('choosing another database saves the draft with it', (tester) async {
        await pump(tester, connection: _server);
        await tester.pumpAndSettle();
        await type(tester, 'select 13');
        await tester.pump(const Duration(seconds: 1));

        catalog.choose(_server.id, 'postgres');
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(saved(_server.id), [
          const StatementDraft(text: 'select 13', catalog: 'app'),
          const StatementDraft(text: 'select 13', catalog: 'postgres'),
        ]);
      });
    });

    testWidgets('a draft read that fails otherwise is shown with Retry', (tester) async {
      var calls = 0;
      when(() => store.readDraft(_alice, _postgres.id)).thenAnswer(
        (_) async => calls++ == 0 ? _failure(AppErrorCode.generic) : const Success(StatementDraft(text: 'select 9')),
      );
      await pump(tester);
      expect(find.textContaining('could not be read, so new text is not kept'), findsOneWidget);

      await tester.tap(find.byKey(EditorDraftNotice.retryKey));
      await tester.pump();
      await tester.pump();
      expect(controller(tester).text, 'select 9');
    });
  });

  testWidgets('a rotation keeps the scroll position of a long text', (tester) async {
    await pump(tester);
    final text = List.generate(200, (index) => 'select $index;').join('\n');
    await type(tester, text);
    final scrollable = find.descendant(of: field(), matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(600);
    await tester.pump();

    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller(tester).text, text);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 600);
  });
}
