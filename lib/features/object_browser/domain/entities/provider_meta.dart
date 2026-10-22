import 'package:equatable/equatable.dart';

/// What the engine of a connection can do and how its tree is shaped: `POST /api/db/provider-meta`.
///
/// Studio builds it without connecting, so a capability that depends on the live server (MariaDB's extra kinds on a
/// MySQL connection) may be missing here; the kinds of an object count come from a connected provider.
class ProviderMeta extends Equatable {
  const ProviderMeta({
    required this.queryLanguage,
    required this.containerLevels,
    required this.objectKinds,
    this.supportsExplain = false,
    this.supportsTransactions = false,
    this.supportsQueryCancel = false,
    this.supportsResultPagination = false,
    this.catalogSessions = false,
    this.keyScan,
  });

  /// `sql`, `json`, `promql`, `cypher` or `influxql`.
  final String queryLanguage;

  /// The container levels from the top, none to two of them: a schema, or a database and its schemas.
  final List<ContainerLevel> containerLevels;
  final List<ObjectKind> objectKinds;
  final bool supportsExplain;
  final bool supportsTransactions;
  final bool supportsQueryCancel;
  final bool supportsResultPagination;

  /// Whether a statement may name the database to run in (`catalog`), on a server-level connection.
  final bool catalogSessions;

  /// The key browser of a key-value engine, absent for the others.
  final KeyScanSpec? keyScan;

  bool get isSql => queryLanguage == 'sql';

  @override
  List<Object?> get props => [
    queryLanguage,
    containerLevels,
    objectKinds,
    supportsExplain,
    supportsTransactions,
    supportsQueryCancel,
    supportsResultPagination,
    catalogSessions,
    keyScan,
  ];
}

/// One level of containers, in the engine's own words: Schema, Database, Keyspace, Bucket.
class ContainerLevel extends Equatable {
  const ContainerLevel({required this.id, required this.label, required this.labelPlural});

  /// `catalog` or `schema`, which orders the levels.
  final String id;
  final String label;
  final String labelPlural;

  @override
  List<Object?> get props => [id, label, labelPlural];
}

/// A kind of object the engine has, such as a table, a view or a collection. Kind ids are opaque: the labels come
/// from here, never from the app.
class ObjectKind extends Equatable {
  const ObjectKind({
    required this.id,
    required this.role,
    required this.label,
    required this.labelPlural,
    this.hasSource = false,
    this.hasColumns = false,
    this.attachedTo,
    this.keyBrowserOnly = false,
  });

  final String id;

  /// `relation`, `routine`, `group`, `attached` or `config`.
  final String role;
  final String label;
  final String labelPlural;

  /// Whether `source` reads its definition.
  final bool hasSource;

  /// Whether `describe` reads its columns.
  final bool hasColumns;

  /// The kind this one hangs under, such as a trigger under a table.
  final String? attachedTo;

  /// Listed only by the key browser, never by counts, lists or search.
  final bool keyBrowserOnly;

  @override
  List<Object?> get props => [id, role, label, labelPlural, hasSource, hasColumns, attachedTo, keyBrowserOnly];
}

/// The page sizes the key browser accepts.
class KeyScanSpec extends Equatable {
  const KeyScanSpec({required this.defaultCount, required this.maxCount});

  final int defaultCount;
  final int maxCount;

  @override
  List<Object?> get props => [defaultCount, maxCount];
}
