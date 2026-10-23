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

  testWidgets('a dependent rebuilds when the role changes, and only then', (tester) async {
    _RoleReader.builds = 0;
    Future<void> pumpRole(StudioRole? role) =>
        tester.pumpWidget(StudioRoleScope(role: role, child: const _RoleReader()));

    await pumpRole(null);
    expect((_RoleReader.builds, _RoleReader.last), (1, null));

    await pumpRole(null);
    expect(_RoleReader.builds, 1, reason: 'the same role must not rebuild the const child');

    await pumpRole(const StudioUserRole());
    expect((_RoleReader.builds, _RoleReader.last), (2, const StudioUserRole()));

    await pumpRole(const StudioUserRole());
    expect(_RoleReader.builds, 2, reason: 'an equal role must not rebuild the const child');

    await pumpRole(const StudioAdminRole());
    expect((_RoleReader.builds, _RoleReader.last), (3, const StudioAdminRole()));
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

/// A const dependent of the scope that counts its builds, so it rebuilds only when the scope notifies it.
class _RoleReader extends StatelessWidget {
  const _RoleReader();

  static int builds = 0;
  static StudioRole? last;

  @override
  Widget build(BuildContext context) {
    builds++;
    last = StudioRoleScope.of(context);
    return const SizedBox();
  }
}
