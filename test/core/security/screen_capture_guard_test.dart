import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';

import '../../support/screen_capture.dart';

void main() {
  late RecordingScreenCapturePlatform platform;
  late ScreenCaptureProtection protection;

  setUp(() {
    platform = RecordingScreenCapturePlatform();
    protection = ScreenCaptureProtection(platform: platform, enabled: true);
  });

  Widget app(Widget home) => RepositoryProvider<ScreenCaptureProtection>.value(
    value: protection,
    child: MaterialApp(home: home),
  );

  testWidgets('takes one lease while mounted and releases it on dispose', (tester) async {
    await tester.pumpWidget(app(const ScreenCaptureGuard(child: Text('secret'))));
    expect(protection.leases, 1);
    expect(platform.calls, ['on']);

    await tester.pumpWidget(app(const Text('nothing')));
    expect(protection.leases, 0);
    expect(platform.calls, ['on', 'off']);
  });

  testWidgets('a rebuild takes no second lease', (tester) async {
    await tester.pumpWidget(app(const ScreenCaptureGuard(child: Text('a'))));
    await tester.pumpWidget(app(const ScreenCaptureGuard(child: Text('b'))));
    expect(protection.leases, 1);
    expect(platform.calls, ['on']);
  });

  testWidgets('two guards on screen hold two leases, and removing one keeps protection on', (tester) async {
    await tester.pumpWidget(
      app(
        const Column(
          children: [
            ScreenCaptureGuard(child: Text('a')),
            ScreenCaptureGuard(child: Text('b')),
          ],
        ),
      ),
    );
    expect(protection.leases, 2);

    await tester.pumpWidget(app(const Column(children: [ScreenCaptureGuard(child: Text('a'))])));
    expect(protection.leases, 1);
    expect(protection.isEngaged, isTrue);
  });

  // An offstage guard is not on screen; holding its lease would keep whatever is on screen above it from being
  // captured, so it gives the lease back while its tickers are off and takes it again when it shows.
  testWidgets('an offstage guard holds no lease and takes it again when it shows', (tester) async {
    Widget hidden(bool offstage) => app(
      Offstage(
        offstage: offstage,
        child: TickerMode(
          enabled: !offstage,
          child: const ScreenCaptureGuard(child: Text('secret')),
        ),
      ),
    );
    await tester.pumpWidget(hidden(false));
    expect(protection.leases, 1);

    await tester.pumpWidget(hidden(true));
    expect(protection.leases, 0);
    expect(platform.calls, ['on', 'off']);

    await tester.pumpWidget(hidden(false));
    expect(protection.leases, 1);
    expect(platform.calls, ['on', 'off', 'on']);
  });

  testWidgets('a guard mounted offstage takes no lease, and its dispose releases none', (tester) async {
    await tester.pumpWidget(app(const TickerMode(enabled: false, child: ScreenCaptureGuard(child: Text('secret')))));
    expect(protection.leases, 0);

    await tester.pumpWidget(app(const Text('nothing')));
    expect(protection.leases, 0);
    expect(platform.calls, isEmpty);
  });

  testWidgets('a page pushed over the guard releases its lease, and popping back takes it again', (tester) async {
    await tester.pumpWidget(app(const ScreenCaptureGuard(child: Text('secret'))));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.push(MaterialPageRoute<void>(builder: (_) => const Text('settings')));
    await tester.pumpAndSettle();
    expect(protection.leases, 0);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(protection.leases, 1);
  });

  testWidgets('a sheet over the guard keeps its lease, and closing it keeps the guard protected', (tester) async {
    await tester.pumpWidget(app(const ScreenCaptureGuard(child: Text('secret'))));
    final context = tester.element(find.text('secret'));

    showModalBottomSheet<void>(context: context, builder: (_) => const Text('sheet'));
    await tester.pumpAndSettle();
    expect(protection.leases, 1);

    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(protection.leases, 1);
    expect(platform.calls, ['on']);
  });

  testWidgets('with the switch off the guard takes no lease and never calls the platform', (tester) async {
    protection = ScreenCaptureProtection(platform: platform, enabled: false);
    await tester.pumpWidget(app(const ScreenCaptureGuard(child: Text('secret'))));
    expect(find.text('secret'), findsOneWidget);
    expect(protection.leases, 0);

    await tester.pumpWidget(app(const Text('nothing')));
    expect(platform.calls, isEmpty);
  });

  testWidgets('a guard without the protection above it fails instead of showing the value unprotected', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScreenCaptureGuard(child: Text('secret'))));
    expect(tester.takeException(), isA<ProviderNotFoundException>());
  });
}
