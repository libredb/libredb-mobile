import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/session/studio_account_refusal_cubit.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';

void main() {
  test('starts with the account accepted', () {
    expect(StudioAccountRefusalCubit().state, const StudioAccountAccepted());
  });

  blocTest<StudioAccountRefusalCubit, StudioAccountRefusalState>(
    "holds the code of Studio's refusal",
    build: StudioAccountRefusalCubit.new,
    act: (cubit) => cubit.refuse(AppErrorCode.studioAccountHasNoRole),
    expect: () => const [StudioAccountRefused(AppErrorCode.studioAccountHasNoRole)],
  );

  blocTest<StudioAccountRefusalCubit, StudioAccountRefusalState>(
    'keeps one refusal when every request of a screen meets it',
    build: StudioAccountRefusalCubit.new,
    act: (cubit) => cubit
      ..refuse(AppErrorCode.studioAccountHasNoRole)
      ..refuse(AppErrorCode.studioAccountHasNoRole),
    expect: () => const [StudioAccountRefused(AppErrorCode.studioAccountHasNoRole)],
  );

  blocTest<StudioAccountRefusalCubit, StudioAccountRefusalState>(
    'forgets the refusal once Studio accepts the account again or the user signs out',
    build: StudioAccountRefusalCubit.new,
    seed: () => const StudioAccountRefused(AppErrorCode.studioAccountHasNoIdentity),
    act: (cubit) => cubit.clear(),
    expect: () => const [StudioAccountAccepted()],
  );

  test('refuses a code that is not an account refusal', () {
    expect(
      () => StudioAccountRefusalCubit().refuse(AppErrorCode.studioIdentityProviderUnavailable),
      throwsArgumentError,
    );
  });
}
