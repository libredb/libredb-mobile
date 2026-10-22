import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/infrastructure/cache/session_memory_cache.dart';

/// Keeps the containers, counts, lists and describe answers of [IObjectBrowserRepository] in memory for [ttl], so
/// browsing back and forth spends none of the user's Studio request budget, which every object route charges.
///
/// Source, search and key pages are always read afresh. Each answer is stored under its connection id, its method,
/// its container or object path and its kind; on a server-level connection the database is the path's first segment,
/// so it needs no key of its own. The session end, [invalidate] and [invalidateContainer] also keep an answer still on
/// its way from being stored (see [SessionMemoryCache]).
class CachedObjectBrowserRepository implements IObjectBrowserRepository {
  CachedObjectBrowserRepository(this._inner, {DateTime Function()? now})
    : _cache = SessionMemoryCache(ttl: ttl, now: now);

  /// How long an answer is served, checked on read.
  static const ttl = Duration(minutes: 10);

  final IObjectBrowserRepository _inner;
  final SessionMemoryCache<_BrowserKey, Object> _cache;

  /// How many answers are kept.
  @visibleForTesting
  int get entryCount => _cache.length;

  @override
  Future<Result<List<ObjectContainer>>> containers(String connectionId, {List<String>? parent, bool refresh = false}) =>
      _read(
        _BrowserKey(connectionId, 'containers', parent),
        () => _inner.containers(connectionId, parent: parent),
        refresh,
      );

  @override
  Future<Result<Map<String, KindCount>>> counts(
    String connectionId, {
    required List<String> container,
    bool refresh = false,
  }) => _read(
    _BrowserKey(connectionId, 'counts', container),
    () => _inner.counts(connectionId, container: container),
    refresh,
  );

  @override
  Future<Result<List<DatabaseObject>>> list(
    String connectionId, {
    required List<String> container,
    required String kind,
    bool refresh = false,
  }) => _read(
    _BrowserKey(connectionId, 'list', container, kind),
    () => _inner.list(connectionId, container: container, kind: kind),
    refresh,
  );

  @override
  Future<Result<ObjectDetail>> describe(
    String connectionId, {
    required List<String> path,
    required String kind,
    bool refresh = false,
  }) => _read(
    _BrowserKey(connectionId, 'describe', path, kind),
    () => _inner.describe(connectionId, path: path, kind: kind),
    refresh,
  );

  @override
  Future<Result<ObjectSource>> source(String connectionId, {required List<String> path, required String kind}) =>
      _inner.source(connectionId, path: path, kind: kind);

  @override
  Future<Result<List<DatabaseObject>>> search(String connectionId, {required String term, List<String>? kinds}) =>
      _inner.search(connectionId, term: term, kinds: kinds);

  @override
  Future<Result<KeyScanPage>> scanKeys(
    String connectionId, {
    String cursor = '0',
    String? pattern,
    int? count,
    int? database,
  }) => _inner.scanKeys(connectionId, cursor: cursor, pattern: pattern, count: count, database: database);

  /// Drops every answer of [connectionId], as after a statement that changed its schema or when the connection
  /// vanished.
  void invalidate(String connectionId) => _cache.invalidateWhere((key) => key.connectionId == connectionId);

  /// Drops the answers about [container] of [connectionId] and about everything under it: its counts, lists and child
  /// containers, and the describe answers of its objects. The containers list that names [container], the top level or
  /// its parent's, is dropped too, since creating or dropping a schema changes it.
  void invalidateContainer(String connectionId, List<String> container) {
    final parent = container.isEmpty ? null : container.sublist(0, container.length - 1);
    _cache.invalidateWhere(
      (key) => key.connectionId == connectionId && (key.isUnder(container) || key.isContainersOf(parent)),
    );
  }

  /// Drops the answers past [ttl], when the user switches to another connection, so a long session does not keep each
  /// connection it ever opened. The fresh answers stay, so going back within [ttl] sends no request.
  void evictExpired() => _cache.evictExpired();

  /// Drops every answer, when the session ends.
  void clear() => _cache.clear();

  Future<Result<T>> _read<T extends Object>(_BrowserKey key, Future<Result<T>> Function() send, bool refresh) async {
    final result = await _cache.read(key, () async => _widen(await send()), refresh: refresh);
    return switch (result) {
      Success(:final data) => Success(data as T),
      Failure(:final error, :final stackTrace) => Failure(error, stackTrace: stackTrace),
    };
  }

  static Result<Object> _widen<T extends Object>(Result<T> result) => switch (result) {
    Success(:final data) => Success(data),
    Failure(:final error, :final stackTrace) => Failure(error, stackTrace: stackTrace),
  };
}

class _BrowserKey extends Equatable {
  /// Keeps its own unmodifiable copy of [path], so a caller that changes its list later cannot move the entry.
  _BrowserKey(this.connectionId, this.method, List<String>? path, [this.kind])
    : path = path == null ? null : List.unmodifiable(path);

  final String connectionId;
  final String method;

  /// The container path, the parent of `containers` (null at the top), or the object path of `describe`.
  final List<String>? path;
  final String? kind;

  /// Whether [path] is [container] or starts with its segments.
  bool isUnder(List<String> container) {
    final path = this.path;
    return path != null && _startsWith(path, container);
  }

  /// Whether this is the `containers` list under [parent], where null and an empty path both name the top level.
  bool isContainersOf(List<String>? parent) {
    if (method != 'containers' || parent == null) return false;
    final path = this.path ?? const <String>[];
    return path.length == parent.length && _startsWith(path, parent);
  }

  static bool _startsWith(List<String> path, List<String> prefix) {
    if (path.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [connectionId, method, path, kind];
}
