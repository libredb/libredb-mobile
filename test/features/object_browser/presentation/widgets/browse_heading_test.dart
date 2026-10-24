@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';

void main() {
  Future<void> pumpHeading(WidgetTester tester, Size screen) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BrowseHeading(
                title: 'ledger',
                overline: 'Table',
                wrappedActions: [TextButton(onPressed: () {}, child: const Text('Count rows'))],
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('puts the wrapped actions on a line of their own under the title in portrait', (tester) async {
    await pumpHeading(tester, const Size(393, 829));

    expect(tester.getRect(find.text('Count rows')).top, greaterThan(tester.getRect(find.text('ledger')).bottom));
  });

  testWidgets('puts the wrapped actions on the title row on a compact height', (tester) async {
    await pumpHeading(tester, const Size(829, 393));

    final title = tester.getRect(find.text('ledger'));
    final action = tester.getRect(find.byType(TextButton));
    expect(action.left, greaterThan(title.right));
    expect(action.top, lessThan(title.bottom));
    expect(tester.getRect(find.byType(BrowseHeading)).height, lessThanOrEqualTo(72));
  });
}
