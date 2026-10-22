@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/connections/data/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// The answer of `assets/mock/GET_connections_managed.json`, which the app shows in local mode.
ManagedConnections _mockAnswer() =>
    ManagedConnectionsModel.read(File('assets/mock/GET_connections_managed.json').readAsStringSync());

/// The identity provider's subjects of two accounts that sign in on the same phone.
const _alice = 'subject-alice';
const _bob = 'subject-bob';

void main() {
  const online = ConnectivityState(status: ConnectivityStatus.online);
  const offline = ConnectivityState(status: ConnectivityStatus.offline);

  late MockIConnectionRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late MockConnectivityCubit connectivity;
  late MockStudioStatusBloc studioStatus;
  late StreamController<ConnectivityState> connectivityChanges;

  setUp(() {
    repository = MockIConnectionRepository();
    providerMeta = MockIProviderMetaRepository();
    connectivity = MockConnectivityCubit();
    studioStatus = MockStudioStatusBloc();
    when(() => studioStatus.state).thenReturn(const StudioReachable());
    connectivityChanges = StreamController<ConnectivityState>();
    whenListen(connectivity, connectivityChanges.stream, initialState: online);
  });

  tearDown(() => connectivityChanges.close());

  /// The device's connectivity changes to [state], as the app's ConnectivityCubit reports it.
  Future<void> goTo(WidgetTester tester, ConnectivityState state) async {
    when(() => connectivity.state).thenReturn(state);
    connectivityChanges.add(state);
    await tester.pump();
    await tester.pump();
  }

  /// The page opens with the device already offline.
  void startOffline() {
    when(() => connectivity.state).thenReturn(offline);
    whenListen(connectivity, connectivityChanges.stream, initialState: offline);
  }

  void answer(ManagedConnections managed) =>
      when(() => repository.listManaged()).thenAnswer((_) async => Success(managed));

  /// The page under the offline banner, as the shell shows it, fed by a fake ConnectivityCubit.
  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    ThemeData? theme,
    double textScale = 1,
    String? subject = _alice,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IConnectionRepository>.value(value: repository),
          RepositoryProvider<IProviderMetaRepository>.value(value: providerMeta),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<StudioStatusBloc>.value(value: studioStatus),
          ],
          child: AppConnectivityScope(
            child: MaterialApp(
              theme: theme ?? AppTheme.light(),
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
                body: Column(
                  children: [
                    const ConnectivityBanner(),
                    Expanded(
                      child: MultiBlocProvider(
                        providers: [
                          BlocProvider(
                            create: (_) => ConnectionListBloc(
                              listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository),
                            ),
                          ),
                          BlocProvider(
                            create: (_) => CollapsedSectionsCubit(repository: CollapsedSectionsRepository())..restore(),
                          ),
                          BlocProvider(
                            create: (_) =>
                                FavoriteConnectionsBloc(repository: FavoriteConnectionsRepository())
                                  ..add(FavoriteConnectionsSubjectChanged(subject)),
                          ),
                        ],
                        child: const ConnectionListPage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder row(String id) => find.byKey(ValueKey('connection-row-$id'));
  Finder header(String key) => find.byKey(ValueKey('connection-section-$key'));

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  testWidgets('shows the mock data in Analytics, Catalog, Finance and Sales sections, with Other last', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester);

    verify(() => repository.listManaged()).called(1);
    final titles = ['Analytics', 'Catalog', 'Finance', 'Sales', S.current.connection_group_other];
    final tops = [
      for (final key in ['group:Analytics', 'group:Catalog', 'group:Finance', 'group:Sales', 'other'])
        tester.getTopLeft(header(key)).dy,
    ];
    expect(tops, [...tops]..sort());
    for (final title in titles) {
      expect(
        find.descendant(of: find.byKey(const ValueKey('connection-sections')), matching: find.text(title)),
        findsWidgets,
      );
    }
    expect(find.descendant(of: header('other'), matching: find.text(S.current.connection_group_other)), findsOneWidget);
    expect(find.descendant(of: row('seed:sandbox-sqlite'), matching: find.text('Sandbox (SQLite)')), findsOneWidget);
  });

  testWidgets('shows the database, or the host when there is none, under the name', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:sales-postgres'), matching: find.text('sales')), findsOneWidget);
    expect(find.descendant(of: row('seed:erp-oracle'), matching: find.text('oracle.erp.internal')), findsOneWidget);
  });

  for (final (name, theme) in [('light', AppTheme.light()), ('dark', AppTheme.dark())]) {
    testWidgets('shows the PROD badge with its text and semantics on every production row, $name theme', (
      tester,
    ) async {
      final managed = _mockAnswer();
      answer(managed);
      final handle = tester.ensureSemantics();

      await pumpPage(tester, theme: theme);

      final production = managed.connections.where((c) => c.environment == 'production').toList();
      expect(production, hasLength(3));
      for (final connection in production) {
        expect(find.descendant(of: row(connection.id), matching: find.text('PROD')), findsOneWidget);
        // A screen reader reads the badge with the row it belongs to.
        expect(tester.getSemantics(row(connection.id)).label, contains(S.current.connection_environment_badge('PROD')));
      }
      expect(find.descendant(of: row('seed:catalog-mongo'), matching: find.text('STAGING')), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('shows no badge for the environment other, as Studio does', (tester) async {
    answer(
      const ManagedConnections(
        connections: [StudioConnection(id: 'seed:x', name: 'X', type: 'postgres', environment: 'other')],
      ),
    );

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:x'), matching: find.byType(EnvironmentBadge)), findsNothing);
  });

  testWidgets('shows the read-only chip only on a read-only row', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:billing-mysql'), matching: find.byType(ReadOnlyChip)), findsOneWidget);
    expect(find.byType(ReadOnlyChip), findsOneWidget);
    expect(
      find.descendant(of: row('seed:billing-mysql'), matching: find.text(S.current.connection_read_only)),
      findsOneWidget,
    );
  });

  testWidgets('shows the read-only chip on a read grant of a governed Studio', (tester) async {
    answer(
      const ManagedConnections(
        connections: [
          StudioConnection(
            id: 'seed:sales-dev',
            name: 'Sales (development)',
            type: 'postgres',
            access: StudioAccess.write,
          ),
          StudioConnection(
            id: 'seed:sales-prod',
            name: 'Sales (production)',
            type: 'postgres',
            access: StudioAccess.read,
          ),
        ],
      ),
    );

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:sales-prod'), matching: find.byType(ReadOnlyChip)), findsOneWidget);
    expect(find.byType(ReadOnlyChip), findsOneWidget);

    await tester.tap(row('seed:sales-prod'));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ReadOnlyChip)), findsOneWidget);
  });

  testWidgets('collapses a section, remembers it on the device and expands it again', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.tap(header('group:Finance'));
    await tester.pump();

    expect(row('seed:billing-mysql'), findsNothing);
    expect(row('seed:erp-oracle'), findsNothing);
    expect(row('seed:sales-postgres'), findsOneWidget);

    // A new page on the same device opens with the section still collapsed.
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester);
    expect(row('seed:billing-mysql'), findsNothing);

    await tester.tap(header('group:Finance'));
    await tester.pump();
    expect(row('seed:billing-mysql'), findsOneWidget);
  });

  testWidgets('search narrows across sections, folding the Turkish i', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await search(tester, 'İNTERNAL');
    expect(row('seed:sales-postgres'), findsOneWidget);
    expect(row('seed:sandbox-sqlite'), findsNothing);

    await search(tester, 'fınance');
    expect(row('seed:billing-mysql'), findsOneWidget);
    expect(row('seed:erp-oracle'), findsOneWidget);
    expect(row('seed:sales-postgres'), findsNothing);
    expect(header('group:Sales'), findsNothing);
    expect(header('group:Finance'), findsOneWidget);
  });

  testWidgets('a search shows the matches of a collapsed section and clearing it collapses the section again', (
    tester,
  ) async {
    answer(_mockAnswer());
    await pumpPage(tester);
    await tester.tap(header('group:Finance'));
    await tester.pump();
    expect(row('seed:billing-mysql'), findsNothing);

    await search(tester, 'billing');
    expect(row('seed:billing-mysql'), findsOneWidget);
    expect(find.text(S.current.connection_search_no_match), findsNothing);
    // While searching the header does not toggle, so the stored state stays as the user left it.
    await tester.tap(header('group:Finance'));
    await tester.pump();
    expect(row('seed:billing-mysql'), findsOneWidget);

    await search(tester, '  ');
    expect(row('seed:billing-mysql'), findsNothing);
    expect(row('seed:erp-oracle'), findsNothing);
  });

  testWidgets("an empty search result says 'No connections match' and clearing brings the rows back", (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await search(tester, 'no such connection');
    expect(find.text(S.current.connection_search_no_match), findsOneWidget);
    expect(find.text('No connections match'), findsOneWidget);

    await tester.tap(find.byTooltip(S.current.connection_search_clear));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text(S.current.connection_search_no_match), findsNothing);
    expect(row('seed:sales-postgres'), findsOneWidget);
  });

  testWidgets('the environment chips narrow the list to one environment', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'DEV'));
    await tester.pump();

    expect(row('seed:reporting-mssql'), findsOneWidget);
    expect(row('seed:sales-postgres'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'DEV'));
    await tester.pump();
    expect(row('seed:sales-postgres'), findsOneWidget);
  });

  testWidgets('a pull to refresh asks Studio again', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => repository.listManaged()).called(2);
  });

  testWidgets('a failed refresh keeps the list and says why', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);
    when(() => repository.listManaged())
        .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key)));

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(row('seed:sales-postgres'), findsOneWidget);
    final context = tester.element(find.byType(ConnectionListPage));
    expect(find.text(AppErrorCode.networkCertInvalid.resolve(context)), findsOneWidget);
  });

  testWidgets('a search typed during a refresh that then fails keeps the pull indicator, the query and the message', (
    tester,
  ) async {
    answer(_mockAnswer());
    await pumpPage(tester);
    final pending = Completer<Result<ManagedConnections>>();
    when(() => repository.listManaged()).thenAnswer((_) => pending.future);

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await search(tester, 'billing');

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    pending.complete(Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(row('seed:billing-mysql'), findsOneWidget);
    expect(row('seed:sales-postgres'), findsNothing);
    final context = tester.element(find.byType(ConnectionListPage));
    expect(find.text(AppErrorCode.networkCertInvalid.resolve(context)), findsOneWidget);
  });

  Future<void> expectBillingDetails(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Billing (MySQL)')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('mysql')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Finance')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('mysql.billing.internal:3306')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('billing')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.byKey(const ValueKey('connection-check'))), findsOneWidget);
    verifyNever(() => repository.test(any()));
    verifyZeroInteractions(providerMeta);
  }

  testWidgets('tapping a row opens its details, without checking the connection', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.tap(row('seed:billing-mysql'));
    await expectBillingDetails(tester);
  });

  testWidgets('a long press on a row opens its details', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.longPress(row('seed:billing-mysql'));
    await expectBillingDetails(tester);
  });

  testWidgets('the Check of the details sheet shows the latency Studio measured', (tester) async {
    answer(_mockAnswer());
    when(() => providerMeta.providerMeta('seed:billing-mysql')).thenAnswer(
      (_) async => const Success(
        ProviderMeta(queryLanguage: 'sql', schemaRefreshPattern: 'x', containerLevels: [], objectKinds: []),
      ),
    );
    when(() => repository.test('seed:billing-mysql')).thenAnswer(
      (_) async =>
          const Success(ConnectionTestResult(message: 'Connection successful', latency: Duration(milliseconds: 42))),
    );
    await pumpPage(tester);
    await tester.longPress(row('seed:billing-mysql'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('connection-check')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Reachable, 42 ms'), findsOneWidget);
    verify(() => repository.test('seed:billing-mysql')).called(1);
  });

  group('favorites', () {
    Finder star(String id) => find.byKey(ValueKey('connection-star-$id'));

    /// The tooltip of the star button [finder] finds, which says what a tap does.
    String? starTooltip(WidgetTester tester, Finder finder) =>
        tester.widget<IconButton>(find.descendant(of: finder, matching: find.byType(IconButton))).tooltip;
    Finder recent(String id) => find.byKey(ValueKey('connection-recent-$id'));
    final favoritesHeader = header('favorites');

    /// The ids of the rows on screen, top to bottom.
    List<String> rowIds(WidgetTester tester) {
      const prefix = 'connection-row-';
      final keys = [
        for (final element in find.byWidgetPredicate((w) => w.key is ValueKey<String>).evaluate())
          if ((element.widget.key! as ValueKey<String>).value.startsWith(prefix))
            element.widget.key! as ValueKey<String>,
      ]..sort((a, b) => tester.getTopLeft(find.byKey(a)).dy.compareTo(tester.getTopLeft(find.byKey(b)).dy));
      return [for (final key in keys) key.value.substring(prefix.length)];
    }

    testWidgets('starring a row moves it to Favorites on top, and the star survives a restart', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester);
      expect(favoritesHeader, findsNothing);

      await tester.tap(star('seed:sandbox-sqlite'));
      await tester.pump();
      await tester.tap(star('seed:billing-mysql'));
      await tester.pump();

      expect(favoritesHeader, findsOneWidget);
      expect(find.descendant(of: favoritesHeader, matching: find.text(S.current.connection_favorites)), findsOneWidget);
      expect(rowIds(tester).take(2), ['seed:billing-mysql', 'seed:sandbox-sqlite']);
      expect(tester.getTopLeft(favoritesHeader).dy, lessThan(tester.getTopLeft(header('group:Analytics')).dy));
      expect(
        tester.getTopLeft(row('seed:sandbox-sqlite')).dy,
        lessThan(tester.getTopLeft(header('group:Analytics')).dy),
      );
      // The rows moved: Other had only the sandbox and is gone, Finance keeps the Oracle row.
      expect(header('other'), findsNothing);
      expect(find.descendant(of: header('group:Finance'), matching: find.text('1')), findsOneWidget);

      // The app starts again on the same phone for the same account.
      await tester.pumpWidget(const SizedBox());
      await pumpPage(tester);

      expect(favoritesHeader, findsOneWidget);
      expect(rowIds(tester).take(2), ['seed:billing-mysql', 'seed:sandbox-sqlite']);
      expect(starTooltip(tester, star('seed:billing-mysql')), S.current.connection_unstar);
      expect(starTooltip(tester, star('seed:erp-oracle')), S.current.connection_star);

      await tester.tap(star('seed:sandbox-sqlite'));
      await tester.pump();
      expect(header('other'), findsOneWidget);
      expect(rowIds(tester).first, 'seed:billing-mysql');
    });

    testWidgets('a second account on the same phone sees no stars from the first', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester, subject: _alice);
      await tester.tap(star('seed:sales-postgres'));
      await tester.pump();
      await tester.tap(row('seed:erp-oracle'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(favoritesHeader, findsOneWidget);
      expect(recent('seed:erp-oracle'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pumpPage(tester, subject: _bob);

      expect(favoritesHeader, findsNothing);
      expect(find.byKey(const ValueKey('connection-recent')), findsNothing);
      expect(starTooltip(tester, star('seed:sales-postgres')), S.current.connection_star);

      await tester.pumpWidget(const SizedBox());
      await pumpPage(tester, subject: _alice);
      expect(favoritesHeader, findsOneWidget);
      expect(recent('seed:erp-oracle'), findsOneWidget);
    });

    testWidgets('the Recent strip shows the last three opened connections, last opened first', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('connection-recent')), findsNothing);

      for (final id in ['seed:sales-postgres', 'seed:billing-mysql', 'seed:erp-oracle', 'seed:catalog-mongo']) {
        await tester.tap(row(id));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      final strip = find.byKey(const ValueKey('connection-recent'));
      expect(find.descendant(of: strip, matching: find.text(S.current.connection_recent)), findsOneWidget);
      final chips = ['seed:catalog-mongo', 'seed:erp-oracle', 'seed:billing-mysql'];
      final lefts = [for (final id in chips) tester.getTopLeft(recent(id)).dx];
      expect(lefts, [...lefts]..sort());
      expect(recent('seed:sales-postgres'), findsNothing);
      expect(find.descendant(of: recent('seed:erp-oracle'), matching: find.text('ERP (Oracle)')), findsOneWidget);

      // A recent connection opens like its row, and moves to the front.
      await tester.ensureVisible(recent('seed:billing-mysql'));
      await tester.pumpAndSettle();
      await tester.tap(recent('seed:billing-mysql'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Billing (MySQL)')), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(recent('seed:billing-mysql')).dx,
        lessThan(tester.getTopLeft(recent('seed:catalog-mongo')).dx),
      );

      // A search hides the strip, which is a shortcut to the whole list.
      await search(tester, 'sales');
      expect(strip, findsNothing);
    });

    testWidgets('hides the star and the recent entry of a connection the list no longer has, and keeps them', (
      tester,
    ) async {
      await AppLocalStorage().save(
        StorageKeys.connectionFavorites.key,
        '{"$_alice": {"starred": ["seed:gone"], "recent": ["seed:gone"]}}',
      );
      answer(_mockAnswer());

      await pumpPage(tester);

      expect(favoritesHeader, findsNothing);
      expect(find.byKey(const ValueKey('connection-recent')), findsNothing);
      await tester.tap(star('seed:sales-postgres'));
      await tester.pump();
      expect(rowIds(tester).first, 'seed:sales-postgres');
      expect((await FavoriteConnectionsRepository().read(_alice)).starred, {'seed:gone', 'seed:sales-postgres'});
    });

    testWidgets('shows the list without favorites when the stored ones cannot be read', (tester) async {
      await AppLocalStorage().save(StorageKeys.connectionFavorites.key, 'not JSON');
      answer(_mockAnswer());

      await pumpPage(tester);

      expect(row('seed:sales-postgres'), findsOneWidget);
      expect(star('seed:sales-postgres'), findsNothing);
      expect(favoritesHeader, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the list without favorites for an account Studio names no subject for', (tester) async {
      answer(_mockAnswer());

      await pumpPage(tester, subject: null);

      expect(row('seed:sales-postgres'), findsOneWidget);
      expect(star('seed:sales-postgres'), findsNothing);
    });

    testWidgets('the detail sheet stars and unstars the connection', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester);

      await tester.tap(row('seed:erp-oracle'));
      await tester.pumpAndSettle();
      final sheetStar = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byKey(const ValueKey('connection-detail-star')),
      );
      expect(starTooltip(tester, sheetStar), S.current.connection_star);

      await tester.tap(sheetStar);
      await tester.pump();

      expect(starTooltip(tester, sheetStar), S.current.connection_unstar);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(favoritesHeader, findsOneWidget);
      expect(rowIds(tester).first, 'seed:erp-oracle');
    });
  });

  testWidgets('never offers to add a connection', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('rows are at least 48 dp tall and lay out without overflow at a large text size', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester, textScale: 2, size: const Size(360, 2400));

    expect(tester.takeException(), isNull);
    for (final id in ['seed:sales-postgres', 'seed:billing-mysql', 'seed:sandbox-sqlite']) {
      expect(tester.getSize(row(id)).height, greaterThanOrEqualTo(48), reason: id);
    }
    expect(tester.getSize(header('group:Sales')).height, greaterThanOrEqualTo(48));
    final name = tester.renderObject<RenderParagraph>(
      find.descendant(of: row('seed:sales-postgres'), matching: find.text('Sales (PostgreSQL)')),
    );
    expect(name.textScaler, const TextScaler.linear(2));
  });

  testWidgets('shows the empty text when Studio answers no connection', (tester) async {
    answer(const ManagedConnections(connections: <StudioConnection>[]));

    await pumpPage(tester);

    expect(find.text(S.current.connection_list_empty), findsOneWidget);
  });

  testWidgets('shows a failure with a retry that asks again', (tester) async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Failure(NetworkError('down')));

    await pumpPage(tester);

    expect(find.text(S.current.connection_list_load_failed), findsOneWidget);
    await tester.tap(find.text(S.current.refresh));
    await tester.pump();
    await tester.pump();
    verify(() => repository.listManaged()).called(2);
  });

  group('offline', () {
    const sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres', environment: 'production');
    final loadedAt = DateTime(2026, 10, 22, 14, 5);

    /// Opens the page online at [loadedAt] with Sales loaded.
    Future<void> pumpLoaded(WidgetTester tester) async {
      answer(const ManagedConnections(connections: [sales]));
      await withClock(Clock.fixed(loadedAt), () => pumpPage(tester));
      expect(row('seed:sales'), findsOneWidget);
    }

    Future<void> pull(WidgetTester tester, Finder from) async {
      await tester.fling(from, const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    // Airplane mode on the connection list.
    testWidgets('shows the banner and keeps the rows, marked as stale with the time they were loaded', (tester) async {
      await pumpLoaded(tester);

      await withClock(Clock.fixed(loadedAt.add(const Duration(hours: 1))), () => goTo(tester, offline));

      expect(find.text(S.current.connectivity_offline), findsOneWidget);
      expect(row('seed:sales'), findsOneWidget);
      expect(find.text('Offline: showing what was loaded at 2:05 PM'), findsOneWidget);
    });

    testWidgets('a pull to refresh says the device is offline and sends nothing', (tester) async {
      await pumpLoaded(tester);
      await goTo(tester, offline);

      await pull(tester, find.byKey(const ValueKey('connection-sections')));

      verify(() => repository.listManaged()).called(1);
      expect(find.widgetWithText(SnackBar, S.current.connectivity_offline), findsOneWidget);
      expect(find.text(S.current.connection_list_load_failed), findsNothing);
      expect(row('seed:sales'), findsOneWidget);
    });

    // The pull works where there are no rows to drag, too.
    testWidgets('on an empty list, a pull to refresh says the device is offline', (tester) async {
      answer(const ManagedConnections(connections: <StudioConnection>[]));
      await pumpPage(tester);
      await goTo(tester, offline);

      await pull(tester, find.text(S.current.connection_list_empty));

      verify(() => repository.listManaged()).called(1);
      expect(find.widgetWithText(SnackBar, S.current.connectivity_offline), findsOneWidget);
    });

    testWidgets('on a failed list, a pull to refresh says the device is offline', (tester) async {
      startOffline();
      when(
        () => repository.listManaged(),
      ).thenAnswer((_) async => Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key)));
      await pumpPage(tester);

      await pull(tester, find.text(S.current.error_network_offline));

      verify(() => repository.listManaged()).called(1);
      expect(find.widgetWithText(SnackBar, S.current.connectivity_offline), findsOneWidget);
    });

    testWidgets('on a failed list online, a pull to refresh asks Studio again', (tester) async {
      when(() => repository.listManaged()).thenAnswer((_) async => const Failure(NetworkError('down')));
      await pumpPage(tester);

      await pull(tester, find.text(S.current.connection_list_load_failed));

      verify(() => repository.listManaged()).called(2);
    });

    testWidgets('refreshes the list once when the device comes back online, and drops the stale marker', (
      tester,
    ) async {
      await pumpLoaded(tester);
      await goTo(tester, offline);

      await goTo(tester, online);

      verify(() => repository.listManaged()).called(2);
      expect(row('seed:sales'), findsOneWidget);
      expect(find.textContaining('Offline:'), findsNothing);
    });

    testWidgets('keeps the search and the filter on screen offline', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester);
      await search(tester, 'sales');
      await goTo(tester, offline);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('sales'), findsWidgets);
      expect(row('seed:sales-postgres'), findsOneWidget);
      expect(find.textContaining('Offline:'), findsOneWidget);
    });

    testWidgets('leaving the page while a pull to refresh waits for Studio throws nothing', (tester) async {
      await pumpLoaded(tester);
      final pending = Completer<Result<ManagedConnections>>();
      when(() => repository.listManaged()).thenAnswer((_) => pending.future);

      await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      pending.complete(const Success(ManagedConnections(connections: [sales])));
      await tester.pump(const Duration(seconds: 5));
      // The closing bloc lets the pending request finish before its stream ends, outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });

    testWidgets('opened offline, says the device is offline instead of a generic failure', (tester) async {
      startOffline();
      when(
        () => repository.listManaged(),
      ).thenAnswer((_) async => Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key)));

      await pumpPage(tester);

      expect(find.text(S.current.error_network_offline), findsOneWidget);
    });
  });
}
