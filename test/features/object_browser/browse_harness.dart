import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/app/shell/app_shell.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/application/sign_out_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/auth/application/usecases/logout_usecase.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/object_browser/application/session_default_entry.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/navigation/object_browser_routes.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/editor_open_request.dart';
import 'package:libredb_mobile/shared/models/object_container.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:libredb_mobile/shared/widgets/result_view/result_view_mode_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';
import 'browse_answers.dart';

/// The Browse tab inside the real shell and its real routes, on mocktail repositories that answer what each test
/// gives them, for the Browse widget and router tests.
class BrowseHarness {
  BrowseHarness() {
    final store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store);
    final catalogStore = MockIActiveCatalogStore();
    when(() => catalogStore.read(any(), any())).thenAnswer((_) async => null);
    when(() => catalogStore.write(any(), any(), any())).thenAnswer((_) async {});
    catalog = ActiveCatalogCubit(store: catalogStore, connectionIds: active.connectionIds);
    entry = SessionDefaultEntry(active.connectionIds);
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  }

  final repository = MockIObjectBrowserRepository();
  final providerMeta = MockIProviderMetaRepository();
  final statements = MockIStatementRepository();
  late final ActiveConnectionCubit active;
  late final ActiveCatalogCubit catalog;
  late final SessionDefaultEntry entry;
  late final SchemaChangeNotifier schemaChanges;
  final _connectivity = StreamController<ConnectivityState>.broadcast();
  late GoRouter router;

  /// The open requests the SQL tab received, in order; the tab itself is a stand-in, since the editor is not under
  /// test.
  final editorRequests = <EditorOpenRequest>[];

  static const _online = ConnectivityState(status: ConnectivityStatus.online);
  static const _offline = ConnectivityState(status: ConnectivityStatus.offline);

  void answerMeta(String connectionId, ProviderMeta meta) =>
      when(() => providerMeta.providerMeta(connectionId)).thenAnswer((_) async => Success(meta));

  void answerContainers(String connectionId, List<String>? parent, List<ObjectContainer> containers) => when(
    () => repository.containers(
      connectionId,
      parent: parent,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => answered(containers));

  void answerCounts(String connectionId, List<String> container, Map<String, KindCount> counts) => when(
    () => repository.counts(
      connectionId,
      container: container,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => answered(counts));

  /// The location the router shows, path and query.
  String get location => router.state.uri.toString();

  /// Pumps the app on [location], online unless [offline], in [locale] (English by default).
  Future<void> pump(
    WidgetTester tester, {
    String location = ApplicationRoutesConstants.browse,
    bool offline = false,
    Locale? locale,
    bool settle = true,
  }) async {
    final identity = MockStudioIdentityCubit();
    whenListen(identity, const Stream<StudioIdentityState>.empty(), initialState: const StudioIdentityLoading());
    final policy = MockConnectionPolicyCubit();
    whenListen(policy, const Stream<ConnectionPolicyState>.empty(), initialState: const ConnectionPolicyLoading());
    final connectivity = MockConnectivityCubit();
    whenListen(connectivity, _connectivity.stream, initialState: offline ? _offline : _online);
    final studioStatus = MockStudioStatusBloc();
    whenListen(studioStatus, const Stream<StudioStatusState>.empty(), initialState: const StudioReachable());
    router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(state: state, child: child),
          routes: [
            GoRoute(path: ApplicationRoutesConstants.connectionList, builder: (_, _) => const Text('connections page')),
            ...ObjectBrowserFeatureRoutes.routes,
            GoRoute(
              path: ApplicationRoutesConstants.sql,
              builder: (_, state) {
                if (state.extra case final EditorOpenDelivery delivery) {
                  if (delivery.take() case final request?) editorRequests.add(request);
                }
                return const Text('sql page');
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await entry.dispose();
      await schemaChanges.dispose();
      await catalog.close();
      await active.close();
      await _connectivity.close();
    });
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IObjectBrowserRepository>.value(value: repository),
          RepositoryProvider<IProviderMetaRepository>.value(value: providerMeta),
          RepositoryProvider<IStatementRepository>.value(value: statements),
          RepositoryProvider<SchemaChangeNotifier>.value(value: schemaChanges),
          RepositoryProvider<SessionDefaultEntry>.value(value: entry),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: active),
            BlocProvider<ActiveCatalogCubit>.value(value: catalog),
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
              locale: locale,
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
    // A page still loading shows a spinner that never settles.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  /// Takes the device offline, or back online.
  Future<void> setOffline(WidgetTester tester, bool offline) async {
    _connectivity.add(offline ? _offline : _online);
    await tester.pumpAndSettle();
  }
}
