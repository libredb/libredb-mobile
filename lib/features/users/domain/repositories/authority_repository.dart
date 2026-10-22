import 'package:libredb_mobile/core/result/result.dart';

abstract class IAuthorityRepository {
  Future<Result<List<String>>> list();
}
