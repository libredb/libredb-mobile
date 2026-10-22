import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/infrastructure/cache/session_memory_cache.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// Keeps each connection's provider-meta in memory for the signed-in session, for every feature that reads it.
///
/// Studio charges every `POST /api/db/provider-meta` a slot of the user's request budget, so this cache is the only
/// thing that keeps the browser, the result screens and the editor from spending one each time. The session end and
/// [invalidate] also keep an answer still on its way from being stored (see [SessionMemoryCache]).
class CachedProviderMetaRepository implements IProviderMetaRepository {
  CachedProviderMetaRepository(this._inner);

  final IProviderMetaRepository _inner;
  final _cache = SessionMemoryCache<String, ProviderMeta>();

  /// How many answers are kept.
  @visibleForTesting
  int get entryCount => _cache.length;

  @override
  Future<Result<ProviderMeta>> providerMeta(String connectionId) =>
      _cache.read(connectionId, () => _inner.providerMeta(connectionId));

  /// Drops the answer of [connectionId], when the connection vanished, so a grant given back later is read afresh.
  void invalidate(String connectionId) => _cache.invalidateWhere((key) => key == connectionId);

  /// Drops every answer, when the session ends.
  void clear() => _cache.clear();
}
