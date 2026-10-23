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
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/navigation/object_browser_routes.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/utils/schema_change_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

/// The Browse tab inside the real shell and its real routes, on mocktail repositories that answer what each test
/// gives them, for the Browse widget and router tests.
class BrowseHarness {
  BrowseHarness() {
    final store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store);
    entry = SessionDefaultEntry(active.connectionIds);
    schemaChanges = SchemaChangeNotifier(providerMeta: providerMeta, invalidateConnection: (_) {});
  }

  final repository = MockIObjectBrowserRepository();
  final providerMeta = MockIProviderMetaRepository();
  final statements = MockIStatementRepository();
  late final ActiveConnectionCubit active;
  late final SessionDefaultEntry entry;
  late final SchemaChangeNotifier schemaChanges;
  final _connectivity = StreamController<ConnectivityState>.broadcast();
  late GoRouter router;

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
  ).thenAnswer((_) async => Success(containers));

  void answerCounts(String connectionId, List<String> container, Map<String, KindCount> counts) => when(
    () => repository.counts(
      connectionId,
      container: container,
      refresh: any(named: 'refresh'),
    ),
  ).thenAnswer((_) async => Success(counts));

  /// The location the router shows, path and query.
  String get location => router.state.uri.toString();

  /// Pumps the app on [location], online unless [offline].
  Future<void> pump(
    WidgetTester tester, {
    String location = ApplicationRoutesConstants.browse,
    bool offline = false,
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
          ],
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      await entry.dispose();
      await schemaChanges.dispose();
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
            BlocProvider<StudioIdentityCubit>.value(value: identity),
            BlocProvider<ConnectionPolicyCubit>.value(value: policy),
            BlocProvider<ConnectivityCubit>.value(value: connectivity),
            BlocProvider<StudioStatusBloc>.value(value: studioStatus),
            BlocProvider<StudioAccountRefusalCubit>(create: (_) => StudioAccountRefusalCubit()),
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
  }

  /// Takes the device offline, or back online.
  Future<void> setOffline(WidgetTester tester, bool offline) async {
    _connectivity.add(offline ? _offline : _online);
    await tester.pumpAndSettle();
  }
}
