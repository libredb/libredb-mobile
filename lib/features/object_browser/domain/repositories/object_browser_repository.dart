import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/database_object.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/kind_count.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_container.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_detail.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/object_source.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/provider_meta.dart';

/// Read-only browsing of a managed connection, named by its id (`seed:<id>`).
///
/// Every request but [providerMeta] opens the connection, and every one of them spends a slot of the user's Studio
/// request budget, which the user's Studio sessions in the browser share: cache the answers.
abstract class IObjectBrowserRepository {
  Future<Result<ProviderMeta>> providerMeta(String connectionId);

  /// The containers at the top, or the ones under [parent].
  Future<Result<List<ObjectContainer>>> containers(String connectionId, {List<String>? parent});

  /// How many objects of each kind [container] holds, keyed by kind id.
  Future<Result<Map<String, KindCount>>> counts(String connectionId, {required List<String> container});

  Future<Result<List<DatabaseObject>>> list(
    String connectionId, {
    required List<String> container,
    required String kind,
  });

  /// The columns, indexes and foreign keys of an object whose kind has columns.
  Future<Result<ObjectDetail>> describe(String connectionId, {required List<String> path, required String kind});

  /// The definition of an object whose kind has source.
  Future<Result<ObjectSource>> source(String connectionId, {required List<String> path, required String kind});

  /// The objects whose name contains [term], ignoring case, optionally only of [kinds].
  Future<Result<List<DatabaseObject>>> search(String connectionId, {required String term, List<String>? kinds});

  /// A page of keys of a key-value engine, from [cursor] (`0` for the first page).
  Future<Result<KeyScanPage>> scanKeys(
    String connectionId, {
    String cursor = '0',
    String? pattern,
    int? count,
    int? database,
  });
}
