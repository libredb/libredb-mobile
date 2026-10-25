import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/session/platform_account_refusal_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

void main() {
  test('starts accepted', () {
    expect(PlatformAccountRefusalCubit().state, const PlatformAccountAccepted());
  });

  test('refuses with each of its two codes, and clear accepts again', () {
    for (final code in [AppErrorCode.platformAdminRoleRequired, AppErrorCode.platformLicenseAdminSeats]) {
      final cubit = PlatformAccountRefusalCubit()..refuse(code);
      expect(cubit.state, PlatformAccountRefused(code));

      cubit.clear();
      expect(cubit.state, const PlatformAccountAccepted());
    }
  });

  test('throws for any other code', () {
    final cubit = PlatformAccountRefusalCubit();
    for (final code in AppErrorCode.values) {
      if (code == AppErrorCode.platformAdminRoleRequired || code == AppErrorCode.platformLicenseAdminSeats) continue;
      expect(() => cubit.refuse(code), throwsArgumentError, reason: code.key);
    }
    expect(cubit.state, const PlatformAccountAccepted());
  });
}
