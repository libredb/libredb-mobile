@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/governance_status.dart';

void main() {
  testWidgets('of finds the GovernanceStatus above', (tester) async {
    late GovernanceStatus found;
    final status = GovernanceStatus(
      reportOutage: () {},
      reportRecovered: () {},
      noticeBuilder: (_) => const SizedBox(),
      child: Builder(
        builder: (context) {
          found = GovernanceStatus.of(context);
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(status);

    expect(found, same(status));
  });

  testWidgets('of throws without a GovernanceStatus above', (tester) async {
    Object? error;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          try {
            GovernanceStatus.of(context);
          } catch (e) {
            error = e;
          }
          return const SizedBox();
        },
      ),
    );

    expect(error, isA<FlutterError>());
  });
}
