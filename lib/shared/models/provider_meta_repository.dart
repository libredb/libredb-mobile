import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';

/// What the engine of a managed connection can do, named by its id (`seed:<id>`), for every feature that needs it.
///
/// Studio answers without opening the connection, but the request still spends a slot of the user's Studio request
/// budget: cache the answer.
abstract class IProviderMetaRepository {
  Future<Result<ProviderMeta>> providerMeta(String connectionId);
}
