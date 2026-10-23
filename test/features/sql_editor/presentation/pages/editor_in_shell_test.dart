@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/app/shell/profile/profile_sheet.dart';
import 'package:libredb_mobile/app/shell/top_bar/active_connection_title.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/sql_editor_repository.dart';
import 'package:libredb_mobile/features/sql_editor/navigation/sql_editor_routes.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_actions.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/editor_input.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// The editor inside the real shell: the write confirmation covers the shell's top bar and tab bar, so nothing there
/// can leave the tab or close the editor while the sheet waits for an answer.
void main() {
  const postgres = StudioConnection(id: 'seed:dev-postgres', name: 'Dev Postgres', type: 'postgres');

  late ActiveConnectionCubit active;
  late MockISqlEditorRepository repository;
  late MockIProviderMetaRepository providerMeta;
  late SchemaChangeNotifier schemaChanges;

  setUp(() {
    final store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store)..select(postgres);
    repository = MockISqlEditorRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(postgres.id)).thenAnswer(
      (_) async => const Success(
        ProviderMeta(queryLanguage: 'sql', schemaRefreshPattern: 'DROP', containerLevels: [], objectKinds: []),
      ),
    );
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  });

  tearDown(() async {
    await schemaChanges.dispose();
    await active.close();
  });

  Future<GoRouter> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final identity = MockStudioIdentityCubit();
    whenListen(identity, const Stream<StudioIdentityState>.empty(), initialState: const StudioIdentityLoading());
    final policy = MockConnectionPolicyCubit();
    whenListen(policy, const Stream<ConnectionPolicyState>.empty(), initialState: const ConnectionPolicyLoading());
    final connectivity = MockConnectivityCubit();
    whenListen(
      connectivity,
      const Stream<ConnectivityState>.empty(),
      initialState: const ConnectivityState(status: ConnectivityStatus.online),
    );
    final studioStatus = MockStudioStatusBloc();
    whenListen(studioStatus, const Stream<StudioStatusState>.empty(), initialState: const StudioReachable());
    final router = GoRouter(
      initialLocation: '/sql',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(state: state, child: child),
          routes: [
            GoRoute(path: '/connections', builder: (_, _) => const Text('connections page')),
            GoRoute(path: '/browse', builder: (_, _) => const Text('browse root')),
            ...SqlEditorFeatureRoutes.routes,
          ],
        ),
        GoRoute(path: '/login', builder: (_, _) => const Text('login page')),
      ],
    );
    addTearDown(router.dispose);
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
            BlocProvider<StudioIdentityCubit>.value(value: identity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<StudioStatusBloc>.value(value: studioStatus),
            BlocProvider<StudioAccountRefusalCubit>(create: (_) => StudioAccountRefusalCubit()),
            BlocProvider<ResultViewModeCubit>(create: (_) => ResultViewModeCubit(store: MockIResultViewModeStore())),
            BlocProvider<SignOutBloc>(create: (_) => SignOutBloc(logoutUseCase: LogoutUseCase(MockIAuthRepository()))),
          ],
          child: AppConnectivityScope(
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.delegate.supportedLocales,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.enterText(find.byKey(EditorInput.fieldKey), 'DELETE FROM orders WHERE false');
    await tester.pump();
    await tester.tap(find.byKey(EditorActions.runKey));
    await tester.pumpAndSettle();
    expect(find.byType(WriteConfirmationSheet), findsOneWidget);
  }

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

  testWidgets('the confirmation covers the tab bar, so a tap on another tab changes nothing', (tester) async {
    final router = await pumpShell(tester);
    await openConfirmation(tester);

    await tester.tap(find.text('Browse'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/sql');
    expect(find.text('browse root'), findsNothing);
    expect(find.byKey(EditorInput.fieldKey), findsOneWidget);
    expect(active.state.connection, postgres);
    verifyNothingSent();
  });

  // On the SQL tab the top bar shows the tab title and the profile button; the connection switcher is Browse's title.
  testWidgets('the confirmation covers the top bar, so the profile sheet with its sign-out does not open', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    expect(find.byType(ActiveConnectionTitle), findsNothing);
    await openConfirmation(tester);

    await tester.tap(find.byKey(profileButtonKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/sql');
    expect(find.byType(ProfileSheet), findsNothing);
    expect(find.byKey(EditorInput.fieldKey), findsOneWidget);
    expect(active.state.connection, postgres);
    verifyNothingSent();
  });

  // The session ends while the sheet is open, as an inactivity sign-out or an ended Studio session does: the router
  // leaves the shell for the login page, which removes the editor and the sheet above it.
  testWidgets('a session that ends while the sheet is open sends nothing and adds nothing to the closed run', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await openConfirmation(tester);

    router.go('/login');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('login page'), findsOneWidget);
    expect(find.byType(WriteConfirmationSheet), findsNothing);
    verifyNothingSent();
  });
}
