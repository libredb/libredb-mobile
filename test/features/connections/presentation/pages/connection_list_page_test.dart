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
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/connections/data/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/data/repositories/favorite_connections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_view.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';
import 'package:libredb_mobile/shared/widgets/studio_unreachable_status.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:libredb_mobile/shared/widgets/governance_status.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _ungoverned = ConnectionPolicy(customConnections: true, governance: false);

/// What the GovernanceStatus above the page words an outage as.
const _outageNotice = 'Governance outage notice';

/// The answer of `assets/mock/GET_connections_managed.json`, which the app shows in mock mode.
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
  late int outagesReported;
  late int recoveriesReported;

  /// Whether the shell covers the page with the refusal page.
  late ValueNotifier<bool> refused;
  late ValueNotifier<bool> studioUnreachable;
  late MockIActiveConnectionStore activeStore;
  late ActiveConnectionCubit active;

  setUp(() {
    outagesReported = 0;
    recoveriesReported = 0;
    refused = ValueNotifier(false);
    addTearDown(refused.dispose);
    studioUnreachable = ValueNotifier(false);
    addTearDown(studioUnreachable.dispose);
    activeStore = MockIActiveConnectionStore();
    when(() => activeStore.read(any())).thenAnswer((_) async => null);
    when(() => activeStore.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: activeStore);
    addTearDown(active.close);
    repository = MockIConnectionRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => repository.fetchPolicy()).thenAnswer((_) async => const Success(_ungoverned));
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

  /// The router of the page [pumpPage] showed last.
  late GoRouter router;

  /// The page under the offline banner, as the shell shows it, fed by a fake ConnectivityCubit, with the favorites of
  /// [subject] above the router as the app has them. A tap on a connection goes to a Browse placeholder.
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
    router = GoRouter(
      initialLocation: ApplicationRoutesConstants.connectionList,
      routes: [
        GoRoute(
          path: ApplicationRoutesConstants.connectionList,
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const ConnectivityBanner(),
                Expanded(
                  child: MultiBlocProvider(
                    providers: [
                      // The shell asks for the policy when it opens.
                      BlocProvider(create: (_) => ConnectionPolicyCubit(repository: repository)..load()),
                      BlocProvider(
                        create: (_) => ConnectionListBloc(
                          listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository),
                        ),
                      ),
                      BlocProvider(
                        create: (_) => CollapsedSectionsCubit(repository: CollapsedSectionsRepository())..restore(),
                      ),
                    ],
                    child: ValueListenableBuilder(
                      valueListenable: refused,
                      builder: (context, isRefused, child) => AccountRefusalStatus(isRefused: isRefused, child: child!),
                      child: ValueListenableBuilder(
                        valueListenable: studioUnreachable,
                        builder: (context, isUnreachable, child) =>
                            StudioUnreachableStatus(isUnreachable: isUnreachable, child: child!),
                        child: GovernanceStatus(
                          reportOutage: () => outagesReported++,
                          reportRecovered: () => recoveriesReported++,
                          noticeBuilder: (_) => const Text(_outageNotice),
                          child: const ConnectionListPage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: ApplicationRoutesConstants.browse,
          builder: (context, state) => const Scaffold(body: Text('browse placeholder')),
        ),
      ],
    );
    addTearDown(router.dispose);
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
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider(
              create: (_) =>
                  FavoriteConnectionsBloc(repository: FavoriteConnectionsRepository())
                    ..add(FavoriteConnectionsSubjectChanged(subject)),
            ),
          ],
          child: AppConnectivityScope(
            child: MaterialApp.router(
              routerConfig: router,
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
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Taps [target], which opens its connection in the Browse tab, and comes back to the connection list.
  Future<void> openAndComeBack(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('browse placeholder'), findsOneWidget);
    router.go(ApplicationRoutesConstants.connectionList);
    await tester.pumpAndSettle();
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

  group('on a phone held sideways', () {
    const sideways = Size(829, 393);

    testWidgets('puts the search and the environment chips on one row', (tester) async {
      answer(_mockAnswer());

      await pumpPage(tester, size: sideways);

      final field = tester.getRect(find.byType(TextField));
      final chip = tester.getRect(find.byType(FilterChip).first);
      expect(chip.left, greaterThan(field.right));
      expect(chip.top, lessThan(field.bottom));
    });

    testWidgets('puts the badge on the name line', (tester) async {
      answer(_mockAnswer());

      await pumpPage(tester, size: sideways);

      final production = find
          .ancestor(
            of: find.descendant(of: find.byType(ConnectionRow), matching: find.text('PROD')).first,
            matching: find.byType(ConnectionRow),
          )
          .first;
      final connection = tester.widget<ConnectionRow>(production).connection;
      final name = tester.getRect(find.descendant(of: production, matching: find.text(connection.name)));
      final badge = tester.getRect(find.descendant(of: production, matching: find.text('PROD')));
      expect(badge.left, greaterThan(name.right));
      expect(badge.top, lessThan(name.bottom));
    });

    testWidgets('a portrait phone keeps the chips under the search and the badge under the name', (tester) async {
      answer(_mockAnswer());

      await pumpPage(tester, size: const Size(393, 829));

      expect(
        tester.getRect(find.byType(FilterChip).first).top,
        greaterThan(tester.getRect(find.byType(TextField)).bottom),
      );
      final production = row('seed:sales-postgres');
      expect(
        tester.getRect(find.descendant(of: production, matching: find.text('PROD'))).top,
        greaterThan(tester.getRect(find.descendant(of: production, matching: find.text('Sales (PostgreSQL)'))).bottom),
      );
    });

    testWidgets('a portrait phone keeps a short chip row centered under the search', (tester) async {
      answer(
        const ManagedConnections(
          connections: [StudioConnection(id: 'seed:x', name: 'X', type: 'postgres', environment: 'production')],
        ),
      );

      await pumpPage(tester, size: const Size(393, 829));

      expect(tester.getRect(find.byType(FilterChip)).center.dx, moreOrLessEquals(393 / 2, epsilon: 1));
    });

    testWidgets('gives the search the whole row when there are no environment chips', (tester) async {
      answer(
        const ManagedConnections(
          connections: [StudioConnection(id: 'seed:x', name: 'X', type: 'postgres')],
        ),
      );

      await pumpPage(tester, size: sideways);

      expect(find.byType(FilterChip), findsNothing);
      expect(tester.getRect(find.byType(TextField)).right, moreOrLessEquals(829 - 16, epsilon: 1));
    });

    testWidgets('a rotation while typing a search keeps its text and focus', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester, size: const Size(393, 829));
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'sal');
      await tester.pump(const Duration(milliseconds: 250));

      tester.view.physicalSize = sideways;
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'sal');
      expect(field.focusNode?.hasFocus ?? tester.testTextInput.isVisible, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

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

    await tester.longPress(row('seed:sales-prod'));
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

  group('once Studio accepts the account again after the refusal page covered the list', () {
    final accountHasNoRole = Failure<ManagedConnections>(
      AuthError('No role', code: AppErrorCode.studioAccountHasNoRole.key),
    );

    testWidgets('a list that failed asks Studio again, once', (tester) async {
      refused.value = true;
      when(() => repository.listManaged()).thenAnswer((_) async => accountHasNoRole);
      await pumpPage(tester);
      verify(() => repository.listManaged()).called(1);
      answer(_mockAnswer());

      refused.value = false;
      await tester.pump();
      await tester.pump();
      await tester.pump();

      verify(() => repository.listManaged()).called(1);
      expect(row('seed:sales-postgres'), findsOneWidget);
    });

    testWidgets('a loaded list asks nothing and keeps its rows', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester);
      verify(() => repository.listManaged()).called(1);
      refused.value = true;
      await tester.pump();

      refused.value = false;
      await tester.pump();
      await tester.pump();

      verifyNever(() => repository.listManaged());
      expect(row('seed:sales-postgres'), findsOneWidget);
    });
  });

  group('once Studio answers again after its unreachable page covered the list', () {
    testWidgets('a list that failed while covered asks Studio again, once', (tester) async {
      studioUnreachable.value = true;
      when(() => repository.listManaged()).thenAnswer((_) async => const Failure(NetworkError('Connection refused')));
      await pumpPage(tester);
      verify(() => repository.listManaged()).called(1);
      answer(_mockAnswer());

      studioUnreachable.value = false;
      await tester.pump();
      await tester.pump();
      await tester.pump();

      verify(() => repository.listManaged()).called(1);
      expect(row('seed:sales-postgres'), findsOneWidget);
    });

    testWidgets('a loaded list asks nothing and keeps its rows', (tester) async {
      answer(_mockAnswer());
      await pumpPage(tester);
      verify(() => repository.listManaged()).called(1);
      studioUnreachable.value = true;
      await tester.pump();

      studioUnreachable.value = false;
      await tester.pump();
      await tester.pump();

      verifyNever(() => repository.listManaged());
      expect(row('seed:sales-postgres'), findsOneWidget);
    });
  });

  testWidgets('a failed refresh keeps the list and says why in the banner', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester, size: const Size(400, 1400));
    when(() => repository.listManaged())
        .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key)));

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(row('seed:sales-postgres'), findsOneWidget);
    final context = tester.element(find.byType(ConnectionListPage));
    expect(
      find.descendant(
        of: find.byType(StudioErrorBanner),
        matching: find.text(AppErrorCode.networkCertInvalid.resolve(context)),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
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
      await openAndComeBack(tester, row('seed:erp-oracle'));
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
        await tester.ensureVisible(row(id));
        await tester.pumpAndSettle();
        await openAndComeBack(tester, row(id));
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
      expect(find.text('browse placeholder'), findsOneWidget);
      expect(active.state.connection?.id, 'seed:billing-mysql');
      router.go(ApplicationRoutesConstants.connectionList);
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

      await tester.longPress(row('seed:erp-oracle'));
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

  testWidgets('marks the active connection with a dot', (tester) async {
    answer(_mockAnswer());
    active.select(_mockAnswer().connections.firstWhere((c) => c.id == 'seed:catalog-mongo'));
    await pumpPage(tester);

    expect(tester.getSemantics(row('seed:catalog-mongo')).label, contains(S.current.connection_active));
    expect(tester.getSemantics(row('seed:billing-mysql')).label, isNot(contains(S.current.connection_active)));
  });

  testWidgets('hands each list Studio answers to the active connection, which vanishes when it is gone', (
    tester,
  ) async {
    active.select(const StudioConnection(id: 'seed:revoked', name: 'Revoked', type: 'pg'));
    answer(_mockAnswer());
    await pumpPage(tester);

    expect(
      active.state,
      const ActiveConnectionVanished(StudioConnection(id: 'seed:revoked', name: 'Revoked', type: 'pg')),
    );
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

  group('governance and live refresh', () {
    const sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres');
    const ledger = StudioConnection(id: 'seed:ledger', name: 'Ledger', type: 'postgres');
    final governanceUnavailable = Failure<ManagedConnections>(
      ServerError('Governance unavailable', code: AppErrorCode.studioGovernanceUnavailable.key),
    );

    void policy(ConnectionPolicy policy) =>
        when(() => repository.fetchPolicy()).thenAnswer((_) async => Success(policy));

    testWidgets('a 503 after a loaded list keeps the rows greyed under the notice and recovers by itself', (
      tester,
    ) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      expect(recoveriesReported, 1);
      when(() => repository.listManaged()).thenAnswer((_) async => governanceUnavailable);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(row('seed:sales'), findsOneWidget);
      expect(find.descendant(of: row('seed:sales'), matching: find.byType(Opacity)), findsOneWidget);
      expect(find.text(_outageNotice), findsOneWidget);
      expect(find.text(S.current.connection_list_empty), findsNothing);
      expect(find.text(S.current.connection_list_empty_governed), findsNothing);
      expect(outagesReported, 1);

      // Another failed retry is the same outage.
      await tester.pump(ConnectionListBloc.unavailableRetryInterval);
      await tester.pump();
      expect(outagesReported, 1);

      answer(const ManagedConnections(connections: [sales, ledger], cacheHint: Duration(seconds: 10)));
      await tester.pump(ConnectionListBloc.unavailableRetryInterval);
      await tester.pump();

      expect(find.text(_outageNotice), findsNothing);
      expect(row('seed:ledger'), findsOneWidget);
      expect(find.descendant(of: row('seed:sales'), matching: find.byType(Opacity)), findsNothing);
      expect(recoveriesReported, 2);
    });

    testWidgets('an outage greys the stars and the recent strip too, and neither acts', (tester) async {
      Finder star(String id) => find.byKey(ValueKey('connection-star-$id'));
      Finder recent(String id) => find.byKey(ValueKey('connection-recent-$id'));
      answer(const ManagedConnections(connections: [sales, ledger], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      await tester.tap(star('seed:sales'));
      await tester.pump();
      await openAndComeBack(tester, row('seed:ledger'));
      expect(recent('seed:ledger'), findsOneWidget);
      when(() => repository.listManaged()).thenAnswer((_) async => governanceUnavailable);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(find.text(_outageNotice), findsOneWidget);
      expect(tester.widget<ActionChip>(recent('seed:ledger')).onPressed, isNull);
      await tester.tap(star('seed:sales'), warnIfMissed: false);
      await tester.pump();
      expect(header('favorites'), findsOneWidget);
      await tester.tap(row('seed:sales'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('browse placeholder'), findsNothing);
      expect(active.state.connection?.id, 'seed:ledger');
    });

    testWidgets('the first list of a page clears an outage that a page closed during it left behind', (tester) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));

      await pumpPage(tester);

      expect(row('seed:sales'), findsOneWidget);
      expect(recoveriesReported, 1);

      // Later answers on this page report nothing more, since this page reported no outage.
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(recoveriesReported, 1);
    });

    testWidgets('an identity provider 503 while unavailable keeps the rows greyed under the notice', (tester) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      when(() => repository.listManaged()).thenAnswer((_) async => governanceUnavailable);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      final recoveriesBefore = recoveriesReported;
      when(() => repository.listManaged()).thenAnswer(
        (_) async => Failure(
          ServerError('Identity provider unavailable', code: AppErrorCode.studioIdentityProviderUnavailable.key),
        ),
      );

      await tester.pump(ConnectionListBloc.unavailableRetryInterval);
      await tester.pump();

      expect(find.descendant(of: row('seed:sales'), matching: find.byType(Opacity)), findsOneWidget);
      expect(find.text(_outageNotice), findsOneWidget);
      expect(find.byType(StudioErrorBanner), findsNothing);
      expect(recoveriesReported, recoveriesBefore);
    });

    testWidgets('a 503 on a cold start covers the page with the notice and a retry, never the empty-grants text', (
      tester,
    ) async {
      policy(const ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'none'));
      when(() => repository.listManaged()).thenAnswer((_) async => governanceUnavailable);

      await pumpPage(tester);

      expect(find.byKey(const ValueKey('connection-list-unavailable')), findsOneWidget);
      expect(find.text(_outageNotice), findsOneWidget);
      expect(find.text(S.current.connection_list_empty_governed), findsNothing);
      expect(find.text(S.current.connection_list_empty), findsNothing);
      expect(outagesReported, 1);

      answer(const ManagedConnections(connections: [sales]));
      await tester.tap(find.text(S.current.retry));
      await tester.pump();
      await tester.pump();

      expect(row('seed:sales'), findsOneWidget);
      expect(recoveriesReported, 1);
    });

    testWidgets('a governed empty list says no databases were granted yet', (tester) async {
      policy(const ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'none'));
      answer(const ManagedConnections(connections: <StudioConnection>[]));

      await pumpPage(tester);

      expect(find.text(S.current.connection_list_empty_governed), findsOneWidget);
      expect(find.text(S.current.connection_list_empty), findsNothing);
    });

    testWidgets('an empty list without governance says no connections are available', (tester) async {
      answer(const ManagedConnections(connections: <StudioConnection>[]));

      await pumpPage(tester);

      expect(find.text(S.current.connection_list_empty), findsOneWidget);
      expect(find.text(S.current.connection_list_empty_governed), findsNothing);
    });

    for (final (capture, shown) in [('full', true), ('redacted', false), ('none', false), (null, false)]) {
      testWidgets('statementCapture $capture ${shown ? 'shows' : 'shows no'} statement capture note', (tester) async {
        policy(ConnectionPolicy(customConnections: false, governance: true, statementCapture: capture));
        answer(const ManagedConnections(connections: [sales]));

        await pumpPage(tester);

        expect(find.text(S.current.connection_statement_capture_full), shown ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('the statement capture note shows above an outage too', (tester) async {
      policy(const ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'full'));
      when(() => repository.listManaged()).thenAnswer((_) async => governanceUnavailable);

      await pumpPage(tester);

      expect(find.text(S.current.connection_statement_capture_full), findsOneWidget);
    });

    testWidgets('asks for the policy again with each refreshed list', (tester) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      clearInteractions(repository);
      policy(const ConnectionPolicy(customConnections: false, governance: true, statementCapture: 'full'));

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      verify(() => repository.fetchPolicy()).called(1);
      expect(find.text(S.current.connection_statement_capture_full), findsOneWidget);
    });

    testWidgets('a 429 on a refresh keeps the rows and shows the banner with the wait', (tester) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      when(() => repository.listManaged()).thenAnswer(
        (_) async => Failure(
          RateLimitedError(
            'Too many',
            code: AppErrorCode.studioRateLimited.key,
            retryAfter: const Duration(seconds: 30),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(row('seed:sales'), findsOneWidget);
      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expect(find.text(S.current.studio_error_retry_in(30)), findsOneWidget);
    });

    testWidgets('the timer stops when the app goes to the background and asks at once when it comes back', (
      tester,
    ) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      clearInteractions(repository);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 2));
      verifyNever(() => repository.listManaged());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // The return asks on a zero timer, which only a pump with a duration runs.
      await tester.pump(Duration.zero);
      await tester.pump();
      verify(() => repository.listManaged()).called(1);
    });

    testWidgets('asks nothing by itself while the device is offline', (tester) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester);
      await goTo(tester, offline);
      clearInteractions(repository);

      await tester.pump(const Duration(minutes: 2));

      verifyNever(() => repository.listManaged());
    });
  });

  // #188: the banners above the list, with the keyboard up while typing a search on a phone held sideways.
  group('a banner above the keyboard of a phone held sideways', () {
    const sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres', environment: 'production');

    // The page as the shell lays it out beside the rail and under the top bar of the 829x393 emulator (749x321), with
    // the 255 px keyboard and the 24 px bottom inset the shell's safe area keeps: 42 px of height.
    Future<void> pumpTyping(WidgetTester tester) async {
      answer(const ManagedConnections(connections: [sales], cacheHint: Duration(seconds: 10)));
      await pumpPage(tester, size: const Size(749, 321));
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 255 + 24);
      await tester.pump();
      await tester.pump();
    }

    void expectNoOverflowAndSearchShown(WidgetTester tester, Finder banner) {
      expect(tester.takeException(), isNull);
      const aboveKeyboard = 321.0 - 255 - 24;
      // The banners scroll inside the height left above the keyboard, which with the offline banner of the shell
      // above the page is only a few pixels.
      final banners = find.ancestor(of: banner, matching: find.byType(SingleChildScrollView)).first;
      expect(tester.getRect(banners).top, lessThan(aboveKeyboard), reason: 'the banners show');
      expect(tester.getRect(banners).height, greaterThan(0));
      expect(tester.testTextInput.isVisible, isTrue);
    }

    testWidgets('a failed refresh', (tester) async {
      await pumpTyping(tester);
      when(() => repository.listManaged())
          .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key)));

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(find.byType(StudioErrorBanner), findsOneWidget);
      expectNoOverflowAndSearchShown(tester, find.byType(StudioErrorBanner));
    });

    testWidgets('a governance outage', (tester) async {
      await pumpTyping(tester);
      when(() => repository.listManaged()).thenAnswer(
        (_) async => Failure(ServerError('Governance unavailable', code: AppErrorCode.studioGovernanceUnavailable.key)),
      );

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(find.text(_outageNotice), findsOneWidget);
      expectNoOverflowAndSearchShown(tester, find.byKey(const ValueKey('connection-list-outage')));
    });

    testWidgets('offline', (tester) async {
      await pumpTyping(tester);

      await goTo(tester, offline);

      expect(find.textContaining('Offline: showing what was loaded'), findsOneWidget);
      expectNoOverflowAndSearchShown(tester, find.textContaining('Offline: showing what was loaded'));
    });
  });
}
