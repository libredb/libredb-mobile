@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/connectivity/app_connectivity_scope.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_bloc.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_event.dart';
import 'package:libredb_mobile/features/platform_status/application/platform_status_state.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

void main() {
  const online = ConnectivityState(status: ConnectivityStatus.online);
  const offline = ConnectivityState(status: ConnectivityStatus.offline);
  const reconnectCheck = StudioLivenessCheckRequested(trigger: StudioLivenessCheckTrigger.reconnect);

  const platformReconnectCheck = PlatformLivenessCheckRequested(trigger: PlatformLivenessCheckTrigger.reconnect);

  late MockConnectivityCubit connectivity;
  late MockStudioStatusBloc studioStatus;
  late MockPlatformStatusBloc platformStatus;

  setUpAll(() {
    registerFallbackValue(const StudioAppPaused());
    registerFallbackValue(const PlatformAppPaused());
  });

  setUp(() {
    connectivity = MockConnectivityCubit();
    studioStatus = MockStudioStatusBloc();
    when(() => studioStatus.state).thenReturn(const StudioReachable());
    platformStatus = MockPlatformStatusBloc();
    when(() => platformStatus.state).thenReturn(const PlatformReachable());
  });

  Future<List<bool>> pumpScope(
    WidgetTester tester, {
    required ConnectivityState initial,
    List<ConnectivityState>? then,
    bool checksPlatform = false,
  }) async {
    whenListen(connectivity, Stream.fromIterable(then ?? const <ConnectivityState>[]), initialState: initial);
    final seen = <bool>[];
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ConnectivityCubit>.value(value: connectivity),
          BlocProvider<StudioStatusBloc>.value(value: studioStatus),
          BlocProvider<PlatformStatusBloc>.value(value: platformStatus),
        ],
        child: AppConnectivityScope(
          checksPlatform: checksPlatform,
          child: Builder(
            builder: (context) {
              seen.add(OfflineStatus.isOfflineOf(context));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return seen;
  }

  testWidgets('tells the screens below it that the device is offline', (tester) async {
    final seen = await pumpScope(tester, initial: offline);

    expect(seen.last, isTrue);
  });

  testWidgets('tells the screens below it when the device comes back online', (tester) async {
    final seen = await pumpScope(tester, initial: offline, then: [online]);

    expect(seen, [true, false]);
  });

  // The unreachable page shown while the device was offline clears without a manual Retry.
  testWidgets('checks Studio again once when the device comes back online while Studio is unreachable', (tester) async {
    when(() => studioStatus.state).thenReturn(StudioUnreachable(error: NetworkError('offline')));

    await pumpScope(tester, initial: online, then: [offline, online, online]);

    verify(() => studioStatus.add(reconnectCheck)).called(1);
  });

  // One probe that fails right after a reconnect must not cover a screen that was working.
  for (final (name, state) in [
    ('reachable', const StudioReachable()),
    ('in a governance outage', const StudioGovernanceUnavailable(outage: GovernanceOutage.temporary())),
  ]) {
    testWidgets('does not check Studio when the device comes back online while Studio is $name', (tester) async {
      when(() => studioStatus.state).thenReturn(state);

      await pumpScope(tester, initial: online, then: [offline, online]);

      verifyNever(() => studioStatus.add(any()));
    });
  }

  testWidgets('does not check Studio when the device goes offline or opens online', (tester) async {
    await pumpScope(tester, initial: online, then: [offline]);

    verifyNever(() => studioStatus.add(any()));
  });

  group('Platform', () {
    testWidgets('checks Platform again once when the device comes back online while Platform is unreachable', (
      tester,
    ) async {
      when(() => platformStatus.state).thenReturn(PlatformUnreachable(error: NetworkError('offline')));

      await pumpScope(tester, initial: online, then: [offline, online, online], checksPlatform: true);

      verify(() => platformStatus.add(platformReconnectCheck)).called(1);
      verifyNever(() => studioStatus.add(any()));
    });

    testWidgets('does not check Platform when the device comes back online while Platform answers', (tester) async {
      await pumpScope(tester, initial: online, then: [offline, online], checksPlatform: true);

      verifyNever(() => platformStatus.add(any()));
    });

    testWidgets('a build without a Platform target never checks Platform', (tester) async {
      when(() => platformStatus.state).thenReturn(PlatformUnreachable(error: NetworkError('offline')));

      await pumpScope(tester, initial: online, then: [offline, online]);

      verifyNever(() => platformStatus.add(any()));
    });
  });
}
