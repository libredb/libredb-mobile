import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';

void main() {
  // Every role the app can hold, null for an identity not loaded or failed, each with the settings it must get. The
  // switch has no wildcard, so a StudioRole added later stops the build here too.
  MaskingRoleKind expected(StudioRole? role) => switch (role) {
    null => MaskingRoleKind.user,
    StudioAdminRole() => MaskingRoleKind.admin,
    StudioUserRole() => MaskingRoleKind.user,
    StudioUnknownRole() => MaskingRoleKind.user,
  };

  const roles = <StudioRole?>[StudioAdminRole(), StudioUserRole(), StudioUnknownRole('owner'), null];

  for (final role in roles) {
    group('role ${role?.name ?? 'not loaded'}', () {
      test('gets the ${expected(role).name} settings', () {
        expect(MaskingRoleKind.of(role), expected(role));
        expect(MaskingPolicy.forRole(role).roleKind, expected(role));
      });

      test('masks, since no role may turn masking off before M7-13', () {
        expect(MaskingPolicy.forRole(role).masks, isTrue);
      });
    });
  }

  test("the admin gets Studio's admin settings, and a user, an unknown role and no role the user settings", () {
    final config = defaultMaskingConfig;
    expect(
      [
        for (final role in roles)
          (canToggleMasking(MaskingRoleKind.of(role), config), canReveal(MaskingRoleKind.of(role), config)),
      ],
      [(true, true), (false, false), (false, false), (false, false)],
    );
  });

  test('an unknown role named like admin in another case is not the admin', () {
    expect(MaskingRoleKind.of(StudioRole.fromName('Admin')), MaskingRoleKind.user);
  });

  test('the policy carries the exemption it was built with, and two policies built alike are equal', () {
    const exempt = MaskingExemptColumn(column: r'^address$', reason: 'register');
    final policy = MaskingPolicy.forRole(const StudioAdminRole(), exempt: exempt);
    expect(policy.exempt, exempt);
    expect(policy, MaskingPolicy.forRole(const StudioAdminRole(), exempt: exempt));
    expect(policy, isNot(MaskingPolicy.forRole(const StudioAdminRole())));
    expect(policy, isNot(MaskingPolicy.forRole(const StudioUserRole(), exempt: exempt)));
  });
}
