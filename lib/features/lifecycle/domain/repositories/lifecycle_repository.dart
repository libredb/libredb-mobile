import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/lifecycle/domain/entities/app_config_entity.dart';

abstract class ILifecycleRepository {
  /// Fetch the remote app configuration.
  Future<Result<AppConfigEntity>> fetchAppConfig();
}
