import 'package:libredb_mobile/core/result/result.dart';

abstract class IAuthRepository {
  Future<Result<void>> logout();
}
