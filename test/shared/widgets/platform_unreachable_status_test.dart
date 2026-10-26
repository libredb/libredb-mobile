@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/platform_unreachable_status.dart';

void main() {
  group('PlatformUnreachableStatus', () {
    testWidgets('tells the screens below it whether the unreachable page covers them', (tester) async {
      late bool unreachable;
      await tester.pumpWidget(
        PlatformUnreachableStatus(
          isUnreachable: true,
          child: Builder(
            builder: (context) {
              unreachable = PlatformUnreachableStatus.isUnreachableOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(unreachable, isTrue);
    });

    testWidgets('throws when no status is above the screen', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            PlatformUnreachableStatus.isUnreachableOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  group('OnPlatformReachable', () {
    Future<void> pumpStatus(WidgetTester tester, {required bool isUnreachable, required VoidCallback onReachable}) {
      return tester.pumpWidget(
        PlatformUnreachableStatus(
          isUnreachable: isUnreachable,
          child: OnPlatformReachable(onReachable: onReachable, child: const SizedBox()),
        ),
      );
    }

    testWidgets('calls back once when the page uncovers the screen again', (tester) async {
      var reachable = 0;
      await pumpStatus(tester, isUnreachable: false, onReachable: () => reachable++);
      await pumpStatus(tester, isUnreachable: true, onReachable: () => reachable++);
      expect(reachable, 0, reason: 'covering is not a recovery');

      await pumpStatus(tester, isUnreachable: false, onReachable: () => reachable++);
      await pumpStatus(tester, isUnreachable: false, onReachable: () => reachable++);

      expect(reachable, 1);
    });

    testWidgets('does not call back when it opens uncovered', (tester) async {
      var reachable = 0;
      await pumpStatus(tester, isUnreachable: false, onReachable: () => reachable++);

      expect(reachable, 0);
    });
  });
}
