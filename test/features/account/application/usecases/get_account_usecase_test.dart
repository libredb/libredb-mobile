import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/account/application/usecases/get_account_usecase.dart';
import 'package:libredb_mobile/shared/models/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

void main() {
  late MockIAccountRepository mockRepo;
  late GetAccountUseCase useCase;

  setUp(() {
    mockRepo = MockIAccountRepository();
    useCase = GetAccountUseCase(mockRepo);
  });

  const testUser = UserEntity(id: '1', login: 'admin', email: 'admin@test.com');

  test('returns Success with account data', () async {
    when(() => mockRepo.getAccount()).thenAnswer((_) async => const Success(testUser));

    final result = await useCase.call();

    expect(result, isA<Success<UserEntity>>());
    expect((result as Success).data, testUser);
  });

  test('returns Failure on error', () async {
    when(() => mockRepo.getAccount()).thenAnswer((_) async => const Failure(AuthError('Unauthorized')));

    final result = await useCase.call();

    expect(result, isA<Failure<UserEntity>>());
    expect((result as Failure).error, isA<AuthError>());
  });
}
