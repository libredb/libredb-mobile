import 'package:libredb_mobile/features/auth/application/usecases/sign_in_with_sso_usecase.dart';
import 'package:libredb_mobile/features/auth/domain/entities/sso_sign_in_result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/sso_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSsoAuthRepository implements ISsoAuthRepository {
  SsoSignInResult result = const SsoSignInCancelled();
  int signIns = 0;

  @override
  Future<SsoSignInResult> signIn() async {
    signIns++;
    return result;
  }
}

void main() {
  group('SignInWithSsoUseCase', () {
    test('signs in through the repository', () async {
      final repository = _FakeSsoAuthRepository();

      await SignInWithSsoUseCase(repository)();

      expect(repository.signIns, 1);
    });

    test('answers the result of the repository unchanged', () async {
      const succeeded = SsoSignInSucceeded(username: 'jdoe', roles: ['ROLE_USER']);
      final repository = _FakeSsoAuthRepository()..result = succeeded;

      expect(await SignInWithSsoUseCase(repository)(), same(succeeded));
    });
  });
}
