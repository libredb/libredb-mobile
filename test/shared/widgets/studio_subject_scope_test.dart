@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/widgets/studio_subject_scope.dart';

void main() {
  Future<String?> hashUnder(WidgetTester tester, String? subjectHash) async {
    String? found;
    await tester.pumpWidget(
      StudioSubjectScope(
        subjectHash: subjectHash,
        child: Builder(
          builder: (context) {
            found = StudioSubjectScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return found;
  }

  testWidgets('of answers the subject hash of the scope above', (tester) async {
    expect(await hashUnder(tester, 'abc'), 'abc');
  });

  testWidgets('of answers null while Studio has named no subject', (tester) async {
    expect(await hashUnder(tester, null), isNull);
  });

  testWidgets('of throws without a scope above', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          StudioSubjectScope.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(tester.takeException(), isA<FlutterError>());
  });
}
