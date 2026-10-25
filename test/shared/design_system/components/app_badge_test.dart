@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';

void main() {
  group('AppBadge', () {
    Future<void> pumpNarrow(WidgetTester tester, Widget badge) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 120, child: Wrap(children: [badge])),
            ),
          ),
        ),
      );
    }

    const longLabel = 'A label far longer than the narrow row it is placed in';

    testWidgets('wraps a label longer than its row instead of overflowing it', (tester) async {
      await pumpNarrow(tester, const AppBadge(label: 'Short'));
      final lineHeight = tester.getSize(find.text('Short')).height;

      await pumpNarrow(tester, const AppBadge(label: longLabel));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppBadge)).width, lessThanOrEqualTo(120));
      expect(tester.getSize(find.text(longLabel)).height, greaterThan(lineHeight * 1.5), reason: 'on several lines');
    });

    testWidgets('wraps the label beside its icon too', (tester) async {
      await pumpNarrow(tester, const AppBadge(label: longLabel, icon: Icons.check));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppBadge)).width, lessThanOrEqualTo(120));
    });
  });
}
