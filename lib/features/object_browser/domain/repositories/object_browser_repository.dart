import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';

/// Read-only browsing of a managed connection, named by its id (`seed:<id>`).
///
/// Every request opens the connection and spends a slot of the user's Studio request budget, which the user's Studio
/// sessions in the browser share, so the app reads it through `CachedObjectBrowserRepository`. What the engine can do
/// comes from `IProviderMetaRepository`.
///
/// [refresh] is a pull to refresh: it skips an answer kept from before and replaces it. A repository that keeps no
/// answer reads afresh either way.
abstract class IObjectBrowserRepository {
  /// The containers at the top, or the ones under [parent].
  Future<Result<List<ObjectContainer>>> containers(String connectionId, {List<String>? parent, bool refresh = false});

  /// How many objects of each kind [container] holds, keyed by kind id.
  Future<Result<Map<String, KindCount>>> counts(
    String connectionId, {
    required List<String> container,
    bool refresh = false,
  });

  Future<Result<List<DatabaseObject>>> list(
    String connectionId, {
    required List<String> container,
    required String kind,
    bool refresh = false,
  });

  /// The columns, indexes and foreign keys of an object whose kind has columns.
  Future<Result<ObjectDetail>> describe(
    String connectionId, {
    required List<String> path,
    required String kind,
    bool refresh = false,
  });

  /// The definition of an object whose kind has source.
  Future<Result<ObjectSource>> source(String connectionId, {required List<String> path, required String kind});

  /// The objects whose name contains [term], ignoring case, optionally only of [kinds].
  Future<Result<List<DatabaseObject>>> search(String connectionId, {required String term, List<String>? kinds});

  /// A page of keys of a key-value engine. The first page names no [cursor]; each later page sends the cursor of the
  /// page before exactly as it came. [database] names a numbered database, [level] asks an engine that declares
  /// `keyScan.levels` for one level of folders and keys, and is sent only when true. Pages are never kept.
  Future<Result<KeyScanPage>> scanKeys(
    String connectionId, {
    String? cursor,
    String? pattern,
    int? count,
    int? database,
    bool level = false,
  });
}
