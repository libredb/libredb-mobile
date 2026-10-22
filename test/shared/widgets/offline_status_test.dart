@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';

void main() {
  Widget app({required bool isOffline, required Widget child, Locale locale = const Locale('en')}) {
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
        body: OfflineStatus(isOffline: isOffline, child: child),
      ),
    );
  }

  final loadedAt = DateTime(2026, 10, 22, 14, 5);

  group('OfflineStatus', () {
    testWidgets('tells the screens below it whether the device is offline', (tester) async {
      late bool offline;
      await tester.pumpWidget(
        app(
          isOffline: true,
          child: Builder(
            builder: (context) {
              offline = OfflineStatus.isOfflineOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(offline, isTrue);
    });

    testWidgets('fails loudly when no OfflineStatus is above the caller', (tester) async {
      Object? error;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              OfflineStatus.isOfflineOf(context);
            } catch (e) {
              error = e;
            }
            return const SizedBox();
          },
        ),
      );

      expect(error, isA<FlutterError>());
    });
  });

  group('OfflineStaleMarker', () {
    testWidgets('offline, says the data on screen is what was loaded at its time', (tester) async {
      await tester.pumpWidget(app(isOffline: true, child: OfflineStaleMarker(loadedAt: loadedAt)));

      expect(find.text('Offline: showing what was loaded at 2:05 PM'), findsOneWidget);
    });

    testWidgets('offline, says it in Turkish', (tester) async {
      await tester.pumpWidget(
        app(
          isOffline: true,
          locale: const Locale('tr'),
          child: OfflineStaleMarker(loadedAt: loadedAt),
        ),
      );

      expect(find.text('Çevrimdışı: 14:05 itibarıyla yüklenenler gösteriliyor'), findsOneWidget);
    });

    testWidgets('online, shows nothing', (tester) async {
      await tester.pumpWidget(app(isOffline: false, child: OfflineStaleMarker(loadedAt: loadedAt)));

      expect(find.textContaining('Offline'), findsNothing);
    });
  });

  group('OnlineOnlyAction', () {
    Widget action({required bool isOffline, required VoidCallback onRun}) => app(
      isOffline: isOffline,
      child: OnlineOnlyAction(
        builder: (context, enabled) => FilledButton(onPressed: enabled ? onRun : null, child: const Text('Run')),
      ),
    );

    testWidgets('online, the action is enabled and no reason shows', (tester) async {
      var runs = 0;
      await tester.pumpWidget(action(isOffline: false, onRun: () => runs++));

      await tester.tap(find.text('Run'));

      expect(runs, 1);
      expect(find.text(S.current.offline_action_unavailable), findsNothing);
    });

    testWidgets('offline, the action is disabled with the reason shown', (tester) async {
      var runs = 0;
      await tester.pumpWidget(action(isOffline: true, onRun: () => runs++));

      await tester.tap(find.text('Run'), warnIfMissed: false);

      expect(runs, 0);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.text('Needs an internet connection'), findsOneWidget);
    });
  });

  group('OnReconnect', () {
    Future<void> pumpStatus(WidgetTester tester, {required bool isOffline, required VoidCallback onReconnect}) {
      return tester.pumpWidget(
        app(
          isOffline: isOffline,
          child: OnReconnect(onReconnect: onReconnect, child: const SizedBox()),
        ),
      );
    }

    testWidgets('calls back once when the device comes back online', (tester) async {
      var reconnects = 0;
      await pumpStatus(tester, isOffline: false, onReconnect: () => reconnects++);
      await pumpStatus(tester, isOffline: true, onReconnect: () => reconnects++);
      expect(reconnects, 0, reason: 'going offline is not a reconnect');

      await pumpStatus(tester, isOffline: false, onReconnect: () => reconnects++);
      await pumpStatus(tester, isOffline: false, onReconnect: () => reconnects++);

      expect(reconnects, 1);
    });

    testWidgets('does not call back when it opens online', (tester) async {
      var reconnects = 0;
      await pumpStatus(tester, isOffline: false, onReconnect: () => reconnects++);

      expect(reconnects, 0);
    });
  });
}
