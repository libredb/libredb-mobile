@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

void main() {
  const online = ConnectivityState(status: ConnectivityStatus.online);
  const offline = ConnectivityState(status: ConnectivityStatus.offline);

  late MockIConnectionRepository repository;
  late MockConnectivityCubit connectivity;
  late MockStudioStatusBloc studioStatus;
  late StreamController<ConnectivityState> connectivityChanges;

  setUp(() {
    repository = MockIConnectionRepository();
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

  /// The page under the offline banner, as the shell shows it, fed by a fake ConnectivityCubit.
  Future<void> pumpPage(WidgetTester tester, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityCubit>.value(value: connectivity),
          BlocProvider<StudioStatusBloc>.value(value: studioStatus),
        ],
        child: AppConnectivityScope(
          child: MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  const ConnectivityBanner(),
                  Expanded(
                    child: BlocProvider(
                      create: (_) =>
                          ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository)),
                      child: const ConnectionListPage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  const sales = StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres', environment: 'production');
  final loadedAt = DateTime(2026, 10, 22, 14, 5);

  /// Opens the page online at [loadedAt] with Sales loaded.
  Future<void> pumpLoaded(WidgetTester tester) async {
    when(() => repository.listManaged())
        .thenAnswer((_) async => const Success(ManagedConnections(connections: [sales])));
    await withClock(Clock.fixed(loadedAt), () => pumpPage(tester));
    expect(find.text('Sales'), findsOneWidget);
  }

  testWidgets('asks for the connections on open and lists them', (tester) async {
    when(() => repository.listManaged()).thenAnswer(
      (_) async => const Success(
        ManagedConnections(
          connections: [
            StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres', environment: 'production'),
            StudioConnection(id: 'seed:sample', name: 'Sample', type: 'sqlite'),
          ],
        ),
      ),
    );

    await pumpPage(tester);

    verify(() => repository.listManaged()).called(1);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Sample'), findsOneWidget);
    expect(find.textContaining('postgres'), findsOneWidget);
  });

  testWidgets('shows the empty text when Studio answers no connection', (tester) async {
    when(() => repository.listManaged())
        .thenAnswer((_) async => const Success(ManagedConnections(connections: <StudioConnection>[])));

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
    // Airplane mode on the connection list.
    testWidgets('shows the banner and keeps the rows, marked as stale with the time they were loaded', (tester) async {
      await pumpLoaded(tester);

      await goTo(tester, offline);

      expect(find.text(S.current.connectivity_offline), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Offline: showing what was loaded at 2:05 PM'), findsOneWidget);
    });

    testWidgets('a pull to refresh says the device is offline and sends nothing', (tester) async {
      await pumpLoaded(tester);
      await goTo(tester, offline);

      await tester.fling(find.text('Sales'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      verify(() => repository.listManaged()).called(1);
      expect(find.widgetWithText(SnackBar, S.current.connectivity_offline), findsOneWidget);
      expect(find.text(S.current.connection_list_load_failed), findsNothing);
      expect(find.text('Sales'), findsOneWidget);
    });

    testWidgets('refreshes the list once when the device comes back online, and drops the stale marker', (
      tester,
    ) async {
      await pumpLoaded(tester);
      await goTo(tester, offline);

      await goTo(tester, online);

      verify(() => repository.listManaged()).called(2);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.textContaining('Offline:'), findsNothing);
    });

    testWidgets('online, a pull to refresh asks Studio again', (tester) async {
      await pumpLoaded(tester);

      await tester.fling(find.text('Sales'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      verify(() => repository.listManaged()).called(2);
    });

    testWidgets('leaving the page while a pull to refresh waits for Studio throws nothing', (tester) async {
      await pumpLoaded(tester);
      final answer = Completer<Result<ManagedConnections>>();
      when(() => repository.listManaged()).thenAnswer((_) => answer.future);

      await tester.fling(find.text('Sales'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      answer.complete(const Success(ManagedConnections(connections: [sales])));
      await tester.pump(const Duration(seconds: 5));
      // The closing bloc lets the pending request finish before its stream ends, outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });

    testWidgets('opened offline, says the device is offline instead of a generic failure', (tester) async {
      when(() => connectivity.state).thenReturn(offline);
      whenListen(connectivity, connectivityChanges.stream, initialState: offline);
      when(
        () => repository.listManaged(),
      ).thenAnswer((_) async => Failure(NetworkError('No Internet connection', code: AppErrorCode.networkOffline.key)));

      await pumpPage(tester);

      expect(find.text(S.current.error_network_offline), findsOneWidget);
    });
  });
}
