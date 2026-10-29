@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_banner.dart';
import 'package:libredb_mobile/app/connectivity/connectivity_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/connectivity/connectivity_service.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_durations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityCubit extends MockCubit<ConnectivityState> implements ConnectivityCubit {}

void main() {
  late MockConnectivityCubit mockCubit;

  setUp(() {
    mockCubit = MockConnectivityCubit();
  });

  Widget buildTestableWidget({required ConnectivityState state, Locale locale = const Locale('en')}) {
    when(() => mockCubit.state).thenReturn(state);
    whenListen(mockCubit, Stream<ConnectivityState>.value(state), initialState: state);

    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: BlocProvider<ConnectivityCubit>.value(
          value: mockCubit,
          child: const Column(
            children: [
              ConnectivityBanner(),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  group('ConnectivityBanner', () {
    group('when offline', () {
      testWidgets('should display offline banner content', (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.offline)),
        );
        await tester.pump();

        expect(find.text('No internet connection'), findsOneWidget);
      });

      testWidgets('should display the offline message in Turkish', (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            state: const ConnectivityState(status: ConnectivityStatus.offline),
            locale: const Locale('tr'),
          ),
        );
        await tester.pump();

        expect(find.text('İnternet bağlantısı yok'), findsOneWidget);
      });

      testWidgets('announces that the device is offline to a screen reader', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.offline)),
        );
        await tester.pump();

        const label = 'Offline: no internet connection. What is on screen was loaded earlier.';
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(tester.getSemantics(find.bySemanticsLabel(label)), isSemantics(label: label, isLiveRegion: true));
        semantics.dispose();
      });

      testWidgets('should display cloud_off icon', (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.offline)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      });

      // What the user gets, rather than which animation widget is in the tree: the banner is fully arrived when it has
      // settled at the top of the screen at its own height, with its message readable.
      testWidgets('arrives in full at the top of the screen', (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.offline)),
        );
        await tester.pumpAndSettle();

        final banner = tester.getRect(find.byType(ConnectivityBanner));
        expect(banner.height, greaterThan(0));
        expect(banner.top, 0);
        expect(tester.getRect(find.text('No internet connection')).top, greaterThanOrEqualTo(banner.top));
        expect(tester.getRect(find.text('No internet connection')).bottom, lessThanOrEqualTo(banner.bottom));
      });

      testWidgets('should use error color scheme for background', (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.offline)),
        );
        await tester.pump();

        // Find the Container with the error color decoration
        final container = tester.widget<Container>(
          find.descendant(of: find.byType(Material), matching: find.byType(Container)).first,
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.color, isNotNull);
      });
    });

    group('when online', () {
      testWidgets('should not display offline banner text', (tester) async {
        await tester.pumpWidget(buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.online)));
        await tester.pumpAndSettle();

        // When online, the child is SizedBox.shrink, so text should not be found
        expect(find.text('No internet connection'), findsNothing);
      });

      testWidgets('should not display cloud_off icon', (tester) async {
        await tester.pumpWidget(buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.online)));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      });

      // A banner nobody can see must also cost nothing: an online device gives its whole screen to the app.
      testWidgets('takes no room at all', (tester) async {
        await tester.pumpWidget(buildTestableWidget(state: const ConnectivityState(status: ConnectivityStatus.online)));
        await tester.pumpAndSettle();

        expect(tester.getSize(find.byType(ConnectivityBanner)).height, 0);
      });
    });

    group('state transitions', () {
      testWidgets('should show banner when transitioning from online to offline', (tester) async {
        const onlineState = ConnectivityState(status: ConnectivityStatus.online);
        const offlineState = ConnectivityState(status: ConnectivityStatus.offline);

        // Use whenListen with a stream that emits offline after initial online
        when(() => mockCubit.state).thenReturn(onlineState);
        whenListen(mockCubit, Stream.fromIterable([offlineState]), initialState: onlineState);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: Scaffold(
              body: BlocProvider<ConnectivityCubit>.value(
                value: mockCubit,
                child: const Column(
                  children: [
                    ConnectivityBanner(),
                    Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );

        // Let the stream event propagate and rebuild
        await tester.pump();

        // After the stream emits offline, banner should be visible
        expect(find.text('No internet connection'), findsOneWidget);
      });

      testWidgets('should hide banner when transitioning from offline to online', (tester) async {
        const offlineState = ConnectivityState(status: ConnectivityStatus.offline);
        const onlineState = ConnectivityState(status: ConnectivityStatus.online);

        when(() => mockCubit.state).thenReturn(offlineState);
        whenListen(mockCubit, Stream.fromIterable([onlineState]), initialState: offlineState);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: Scaffold(
              body: BlocProvider<ConnectivityCubit>.value(
                value: mockCubit,
                child: const Column(
                  children: [
                    ConnectivityBanner(),
                    Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );

        // Let the stream event propagate and animations settle
        await tester.pumpAndSettle();

        // After the stream emits online, banner should be hidden
        expect(find.text('No internet connection'), findsNothing);
      });
    });
  });

  group('ConnectivityState', () {
    test('initial state should be online', () {
      const state = ConnectivityState.initial();
      expect(state.isOnline, isTrue);
      expect(state.isOffline, isFalse);
      expect(state.lastOnline, isNull);
    });

    test('isOnline should return true when status is online', () {
      const state = ConnectivityState(status: ConnectivityStatus.online);
      expect(state.isOnline, isTrue);
      expect(state.isOffline, isFalse);
    });

    test('isOffline should return true when status is offline', () {
      const state = ConnectivityState(status: ConnectivityStatus.offline);
      expect(state.isOnline, isFalse);
      expect(state.isOffline, isTrue);
    });

    test('copyWith should update status', () {
      const state = ConnectivityState(status: ConnectivityStatus.online);
      final updated = state.copyWith(status: ConnectivityStatus.offline);
      expect(updated.status, ConnectivityStatus.offline);
    });

    test('copyWith should preserve unchanged fields', () {
      final now = DateTime.now();
      final state = ConnectivityState(status: ConnectivityStatus.online, lastOnline: now);
      final updated = state.copyWith(status: ConnectivityStatus.offline);
      expect(updated.lastOnline, now);
    });

    test('copyWith should update lastOnline', () {
      final now = DateTime.now();
      const state = ConnectivityState(status: ConnectivityStatus.online);
      final updated = state.copyWith(lastOnline: now);
      expect(updated.lastOnline, now);
      expect(updated.status, ConnectivityStatus.online);
    });

    test('should use Equatable for equality', () {
      const state1 = ConnectivityState(status: ConnectivityStatus.online);
      const state2 = ConnectivityState(status: ConnectivityStatus.online);
      const state3 = ConnectivityState(status: ConnectivityStatus.offline);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('props should include status and lastOnline', () {
      final now = DateTime.now();
      final state = ConnectivityState(status: ConnectivityStatus.online, lastOnline: now);
      expect(state.props, [ConnectivityStatus.online, now]);
    });
  });

  group('coming back online', () {
    const offline = ConnectivityState(status: ConnectivityStatus.offline);
    const online = ConnectivityState(status: ConnectivityStatus.online);

    /// Pumps the banner offline, then hands back the controller that puts it back online.
    Future<StreamController<ConnectivityState>> pumpGoingOnline(WidgetTester tester) async {
      final states = StreamController<ConnectivityState>();
      addTearDown(states.close);
      when(() => mockCubit.state).thenReturn(offline);
      whenListen(mockCubit, states.stream, initialState: offline);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          // No Scaffold above the banner: both shells sit it directly under the app, where the status-bar inset is
          // still in the MediaQuery. A Scaffold would have taken that inset first and hidden what this group checks.
          home: BlocProvider<ConnectivityCubit>.value(
            value: mockCubit,
            child: const Column(
              children: [
                ConnectivityBanner(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsOneWidget, reason: 'the banner has to be up before it leaves');

      when(() => mockCubit.state).thenReturn(online);
      states.add(online);
      await tester.pump();
      return states;
    }

    // The banner is wrapped in an AnimatedSlide and an AnimatedOpacity, so it is meant to leave the way it arrived.
    // It did not: the child was swapped for an empty box in the same frame the state changed, and both animations
    // then ran on nothing while the user saw the banner vanish (#367).
    testWidgets('the banner is still on screen while it animates away', (tester) async {
      await pumpGoingOnline(tester);
      await tester.pump(AppDurations.normal ~/ 2);

      expect(find.text('No internet connection'), findsOneWidget);
    });

    // SizeTransition clips the banner to its top band while SlideTransition moves the content up inside it. Together
    // they reveal the banner's *bottom* at the top of the screen, so the message rides over the status bar for the
    // length of the animation instead of staying where it was (#367).
    testWidgets('the message does not drift upward while the banner leaves', (tester) async {
      await pumpGoingOnline(tester);
      final message = find.text('No internet connection');
      final restingTop = tester.getRect(message).top;

      // Each pump advances from the last one, so a quarter at a time walks the animation a quarter, a half, and
      // three quarters of the way out.
      for (final part in [1, 2, 3]) {
        await tester.pump(AppDurations.normal ~/ 4);
        expect(
          tester.getRect(message).top,
          greaterThanOrEqualTo(restingTop - 0.5),
          reason: 'the message climbed above where it sat, $part quarter(s) of the way out',
        );
      }
      await tester.pumpAndSettle();
    });

    // Both shells hand the status-bar inset to the banner (`removePadding(removeTop: true)`), because the banner pads
    // itself below it. That hand-over used to be flipped on `isOffline`, in the same frame as the state, which was
    // only safe while the banner appeared and vanished in that frame too. Now that its height animates, the banner
    // has to hold the inset at all times or the body jumps by the height of the status bar at both ends (#367).
    testWidgets('the banner holds the status bar inset throughout', (tester) async {
      // FakeViewPadding is in physical pixels, so the ratio is pinned to read 40 logical ones.
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 40);
      addTearDown(tester.view.reset);

      await pumpGoingOnline(tester);
      final banner = find.byType(ConnectivityBanner);

      for (final part in [1, 2, 3, 4]) {
        await tester.pump(AppDurations.normal ~/ 4);
        expect(
          tester.getSize(banner).height,
          greaterThanOrEqualTo(40),
          reason: 'the banner gave the inset back $part quarter(s) of the way out, and the body jumped',
        );
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(banner).height, 40, reason: 'an online banner still owes the body the inset');
    });

    testWidgets('and is gone once the animation has run', (tester) async {
      await pumpGoingOnline(tester);
      await tester.pumpAndSettle();

      expect(find.text('No internet connection'), findsNothing);
    });
  });

  group('the status bar inset', () {
    // Both shells put the banner above the body in a bare Column, so nothing paints behind the inset; a transparent
    // one shows the black of an unpainted surface on iOS and hides the status bar (#442).
    Future<void> pumpInset(WidgetTester tester, ConnectivityState state, ThemeData theme) async {
      when(() => mockCubit.state).thenReturn(state);
      whenListen(mockCubit, Stream<ConnectivityState>.value(state), initialState: state);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 62)),
            child: child!,
          ),
          home: BlocProvider<ConnectivityCubit>.value(
            value: mockCubit,
            child: const Column(
              children: [
                ConnectivityBanner(),
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Color? insetColor(WidgetTester tester) {
      final box = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      return (box.decoration as BoxDecoration?)?.color;
    }

    for (final (name, theme) in [('light', ThemeData.light()), ('dark', ThemeData.dark())]) {
      testWidgets('is painted with the scaffold background while online ($name)', (tester) async {
        await pumpInset(tester, const ConnectivityState(status: ConnectivityStatus.online), theme);

        expect(tester.getSize(find.byType(AnimatedContainer)).height, 62);
        expect(insetColor(tester), theme.scaffoldBackgroundColor);
      });

      testWidgets('is painted with the error colour while offline ($name)', (tester) async {
        await pumpInset(tester, const ConnectivityState(status: ConnectivityStatus.offline), theme);

        expect(insetColor(tester), theme.colorScheme.error);
      });
    }
  });
}
