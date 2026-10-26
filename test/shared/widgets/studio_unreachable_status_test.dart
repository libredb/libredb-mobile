@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/studio_unreachable_status.dart';

void main() {
  group('StudioUnreachableStatus', () {
    testWidgets('tells the screens below it whether the unreachable page covers them', (tester) async {
      late bool unreachable;
      await tester.pumpWidget(
        StudioUnreachableStatus(
          isUnreachable: true,
          child: Builder(
            builder: (context) {
              unreachable = StudioUnreachableStatus.isUnreachableOf(context);
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
            StudioUnreachableStatus.isUnreachableOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  group('OnStudioReachable', () {
    Future<void> pumpStatus(WidgetTester tester, {required bool isUnreachable, required VoidCallback onReachable}) {
      return tester.pumpWidget(
        StudioUnreachableStatus(
          isUnreachable: isUnreachable,
          child: OnStudioReachable(onReachable: onReachable, child: const SizedBox()),
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
