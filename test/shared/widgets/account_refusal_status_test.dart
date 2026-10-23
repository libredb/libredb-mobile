@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';

void main() {
  group('AccountRefusalStatus', () {
    testWidgets('tells the screens below it whether Studio refuses the account', (tester) async {
      late bool refused;
      await tester.pumpWidget(
        AccountRefusalStatus(
          isRefused: true,
          child: Builder(
            builder: (context) {
              refused = AccountRefusalStatus.isRefusedOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(refused, isTrue);
    });

    testWidgets('throws when no status is above the screen', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            AccountRefusalStatus.isRefusedOf(context);
            return const SizedBox();
          },
        ),
      );

      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  group('OnAccountAccepted', () {
    Future<void> pumpStatus(WidgetTester tester, {required bool isRefused, required VoidCallback onAccepted}) {
      return tester.pumpWidget(
        AccountRefusalStatus(
          isRefused: isRefused,
          child: OnAccountAccepted(onAccepted: onAccepted, child: const SizedBox()),
        ),
      );
    }

    testWidgets('calls back once when Studio accepts the account again', (tester) async {
      var accepted = 0;
      await pumpStatus(tester, isRefused: false, onAccepted: () => accepted++);
      await pumpStatus(tester, isRefused: true, onAccepted: () => accepted++);
      expect(accepted, 0, reason: 'a refusal is not an acceptance');

      await pumpStatus(tester, isRefused: false, onAccepted: () => accepted++);
      await pumpStatus(tester, isRefused: false, onAccepted: () => accepted++);

      expect(accepted, 1);
    });

    testWidgets('does not call back when it opens accepted', (tester) async {
      var accepted = 0;
      await pumpStatus(tester, isRefused: false, onAccepted: () => accepted++);

      expect(accepted, 0);
    });
  });
}
