@Tags(['widget'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';

void main() {
  Future<StudioRole?> roleUnder(WidgetTester tester, StudioRole? role) async {
    StudioRole? found;
    await tester.pumpWidget(
      StudioRoleScope(
        role: role,
        child: Builder(
          builder: (context) {
            found = StudioRoleScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return found;
  }

  testWidgets('of answers the role of the scope above', (tester) async {
    expect(await roleUnder(tester, const StudioAdminRole()), const StudioAdminRole());
  });

  testWidgets('of answers null while the scope holds no role', (tester) async {
    expect(await roleUnder(tester, null), isNull);
  });

  testWidgets('a dependent rebuilds when the role changes', (tester) async {
    expect(await roleUnder(tester, null), isNull);
    expect(await roleUnder(tester, const StudioUserRole()), const StudioUserRole());
  });

  testWidgets('of throws without a StudioRoleScope above', (tester) async {
    Object? error;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          try {
            StudioRoleScope.of(context);
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
