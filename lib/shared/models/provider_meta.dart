import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';

/// What the engine of a connection can do and how its tree is shaped: `POST /api/db/provider-meta`.
///
/// Studio builds it without connecting, so a capability that depends on the live server (MariaDB's extra kinds on a
/// MySQL connection) may be missing here; the kinds of an object count come from a connected provider.
///
/// `queryLanguage`, `queryDialect`, kind ids, roles, `identifierQuoting` and `containerPathShapes` are opaque strings:
/// a screen that branches on one matches its known values explicitly, never with a wildcard that reads an unknown value
/// as a known one.
class ProviderMeta extends Equatable {
  const ProviderMeta({
    required this.queryLanguage,
    required this.schemaRefreshPattern,
    required this.containerLevels,
    required this.objectKinds,
    this.queryDialect,
    this.explainFormat,
    this.maskingExemptColumns,
    this.supportsExplain = false,
    this.supportsTransactions = false,
    this.supportsQueryCancel = false,
    this.supportsResultPagination = false,
    this.supportsColumnProfiling,
    this.supportsSqlFormat,
    this.catalogSessions = false,
    this.tablesAreDerivedGroupings = false,
    this.resumesBilledCompute = false,
    this.identifierQuoting,
    this.defaultPort,
    this.statementTerminator,
    this.declaresPreviewProjection = false,
    this.declaresPreviewTimeWindow = false,
    this.spellsContainerNamesAsEngine = false,
    this.containerPathShapes = 'exact',
    this.rowActions = const [],
    this.keyScan,
    this.labels = const ProviderLabels(),
  });

  static final _log = AppLogger.getLogger('ProviderMeta');

  /// The compiled `schemaRefreshPattern`s of this run, null for one Dart cannot compile, so each pattern is compiled
  /// and warned about once.
  static final _refreshPatterns = <String, RegExp?>{};

  /// `sql`, `json`, `promql`, `cypher` or `influxql`.
  final String queryLanguage;

  /// The engine's statement grammar beside `queryLanguage: "json"`, such as `redis` or `kafka`.
  final String? queryDialect;

  /// How Studio renders the plan of an explain, such as `postgres-json`; absent when the engine has no explain.
  final String? explainFormat;

  /// The one result column that is never masked, and why.
  final MaskingExemptColumn? maskingExemptColumns;

  /// The container levels from the top, none to two of them: a schema, or a database and its schemas.
  final List<ContainerLevel> containerLevels;
  final List<ObjectKind> objectKinds;
  final bool supportsExplain;
  final bool supportsTransactions;
  final bool supportsQueryCancel;
  final bool supportsResultPagination;

  /// False when the engine withholds the column profiler, null when the query language decides.
  final bool? supportsColumnProfiling;

  /// False when the engine withholds Format, null when the query language decides.
  final bool? supportsSqlFormat;

  /// Whether a statement may name the database to run in (`catalog`), on a server-level connection.
  final bool catalogSessions;

  /// Whether the engine's tables are groupings Studio derives rather than objects the engine stores.
  final bool tablesAreDerivedGroupings;

  /// Whether a request to the connection can resume compute the engine bills for, such as a suspended Snowflake or
  /// Databend Cloud warehouse, so the app sends it no check the user did not ask for.
  final bool resumesBilledCompute;

  /// How the engine quotes an identifier: `double`, `backtick`, `double-always` or `backtick-always`.
  final String? identifierQuoting;

  /// The engine's default port, which Studio's generators read as its SQL dialect when no [identifierQuoting] is
  /// declared: 1521 Oracle, 1433 SQL Server, 3306 MySQL, 8888 Druid, 8091 Couchbase, and the PostgreSQL rule for any
  /// other port or none.
  final int? defaultPort;

  /// How a generated statement ends: `none` for an engine whose grammar has no terminator, else `;`.
  final String? statementTerminator;

  /// Whether the engine declares `previewProjection`, a preview that names its columns, which the app does not write.
  final bool declaresPreviewProjection;

  /// Whether the engine declares `previewTimeWindow`, a preview of a recent window, which the app does not write.
  final bool declaresPreviewTimeWindow;

  /// Whether the engine declares `containerNameSpelling: "engine"`, a container segment that may hold several names,
  /// which the app does not quote.
  final bool spellsContainerNamesAsEngine;

  /// `exact` when a container path names one container, `prefixes` when each of its prefixes is a container too.
  final String containerPathShapes;

  /// The read-only statements a row of some kinds offers.
  final List<KindRowAction> rowActions;

  /// The key browser of a key-value engine, absent for the others.
  final KeyScanSpec? keyScan;

  /// Studio's regular expression for a statement that changes the schema, kept as Studio wrote it.
  final String schemaRefreshPattern;

  /// The engine's own words for what a screen shows.
  final ProviderLabels labels;

  bool get isSql => queryLanguage == 'sql';

  /// Whether Studio's object search can list a kind of this engine: it never lists a kind only the key browser
  /// enumerates (`resolveKinds` in libredb-studio `src/lib/api/object-route.ts`), so an engine whose every kind is one
  /// has nothing to search.
  bool get searchesObjects => objectKinds.isEmpty || objectKinds.any((kind) => !kind.keyBrowserOnly);

  /// Whether running [statement] may change the schema, so the object tree has to be read again.
  ///
  /// Studio tests the pattern case-insensitively (`new RegExp(pattern, "i")`); a pattern Dart cannot compile answers
  /// false, and writes one warning per distinct pattern in the run, naming the pattern and never the statement.
  bool refreshesSchema(String statement) {
    final pattern = schemaRefreshPattern;
    final regExp = _refreshPatterns.putIfAbsent(pattern, () {
      try {
        return RegExp(pattern, caseSensitive: false);
      } on FormatException {
        _log.warn('Studio sent a schema refresh pattern Dart cannot compile, so no statement refreshes: {}', [pattern]);
        return null;
      }
    });
    return regExp?.hasMatch(statement) ?? false;
  }

  @override
  List<Object?> get props => [
    queryLanguage,
    queryDialect,
    explainFormat,
    maskingExemptColumns,
    containerLevels,
    objectKinds,
    supportsExplain,
    supportsTransactions,
    supportsQueryCancel,
    supportsResultPagination,
    supportsColumnProfiling,
    supportsSqlFormat,
    catalogSessions,
    tablesAreDerivedGroupings,
    resumesBilledCompute,
    identifierQuoting,
    defaultPort,
    statementTerminator,
    declaresPreviewProjection,
    declaresPreviewTimeWindow,
    spellsContainerNamesAsEngine,
    containerPathShapes,
    rowActions,
    keyScan,
    schemaRefreshPattern,
    labels,
  ];
}

/// The result column the engine never masks, such as a key-value engine's key column.
class MaskingExemptColumn extends Equatable {
  const MaskingExemptColumn({required this.column, required this.reason});

  final String column;

  /// Studio's sentence for why the column stays readable.
  final String reason;

  @override
  List<Object?> get props => [column, reason];
}

/// A read-only statement a row of [kinds] offers, which Studio writes for the object.
class KindRowAction extends Equatable {
  const KindRowAction({required this.id, required this.label, required this.kinds, this.activates = false});

  final String id;
  final String label;

  /// The kind ids whose rows offer the action.
  final List<String> kinds;

  /// Whether tapping a row of these kinds runs the action instead of opening the kind's source.
  final bool activates;

  @override
  List<Object?> get props => [id, label, kinds, activates];
}

/// The engine's own words, all optional: a screen that finds one missing uses its own translated wording.
class ProviderLabels extends Equatable {
  const ProviderLabels({
    this.entityName,
    this.entityNamePlural,
    this.rowName,
    this.rowNamePlural,
    this.selectAction,
    this.generateAction,
    this.searchPlaceholder,
  });

  /// What the engine calls its main object, such as Table or Collection.
  final String? entityName;
  final String? entityNamePlural;

  /// What the engine calls a row, such as row or document.
  final String? rowName;
  final String? rowNamePlural;
  final String? selectAction;
  final String? generateAction;
  final String? searchPlaceholder;

  @override
  List<Object?> get props => [
    entityName,
    entityNamePlural,
    rowName,
    rowNamePlural,
    selectAction,
    generateAction,
    searchPlaceholder,
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
    this.sourceLanguage,
    this.acceptsSourceEdits = false,
    this.hasColumns = false,
    this.childKinds = const [],
    this.attachedTo,
    this.acceptsRowWrites = false,
    this.keyBrowserOnly = false,
    this.countIsListing = false,
    this.machineNamesWithheld = false,
    this.group,
  });

  final String id;

  /// `relation`, `routine`, `group`, `attached` or `config`.
  final String role;
  final String label;
  final String labelPlural;

  /// Whether `source` reads its definition.
  final bool hasSource;

  /// The language the source is written in, such as `sql` or `json`.
  final String? sourceLanguage;

  /// Whether the provider can save an edited source of this kind.
  final bool acceptsSourceEdits;

  /// Whether `describe` reads its columns.
  final bool hasColumns;

  /// The kinds nested under an object of this kind, such as the procedures of a package.
  final List<String> childKinds;

  /// The kind this one hangs under, such as a trigger under a table.
  final String? attachedTo;

  /// Whether writing rows into an object of this kind is meaningful.
  final bool acceptsRowWrites;

  /// Listed only by the key browser, never by counts, lists or search.
  final bool keyBrowserOnly;

  /// Whether counting and listing this kind are one read, so a refused count is a refused listing.
  final bool countIsListing;

  /// Whether the names of this kind are kept from machine surfaces (`machineNames: "withheld"`).
  final bool machineNamesWithheld;

  /// The folder this kind is drawn in, between its container and its own folder.
  final ObjectKindGroup? group;

  @override
  List<Object?> get props => [
    id,
    role,
    label,
    labelPlural,
    hasSource,
    sourceLanguage,
    acceptsSourceEdits,
    hasColumns,
    childKinds,
    attachedTo,
    acceptsRowWrites,
    keyBrowserOnly,
    countIsListing,
    machineNamesWithheld,
    group,
  ];
}

/// A folder that holds several kinds, such as Workloads; kinds with the same id share it.
class ObjectKindGroup extends Equatable {
  const ObjectKindGroup({required this.id, required this.label});

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

/// The page sizes and the shape of the key browser's walk. An absent shape field is Redis's walk, as Studio's
/// `keyScanShape` reads it.
class KeyScanSpec extends Equatable {
  const KeyScanSpec({
    required this.defaultCount,
    required this.maxCount,
    this.separator = ':',
    this.cursor = 'decimal',
    this.pattern = 'glob',
    this.totalScope = 'database',
    this.levels,
  });

  final int defaultCount;
  final int maxCount;

  /// What separates the segments of a key, and ends the prefix a folder stands for.
  final String separator;

  /// `decimal` or `opaque`; `0` starts and ends a walk under both.
  final String cursor;

  /// `glob` for a match pattern, `prefix` for the literal start of every walked key.
  final String pattern;

  /// What a page's total counts: `database`, `walk`, or `none`, when it is not read.
  final String totalScope;

  /// Present when the engine also answers one level of folders and keys at a time.
  final KeyScanLevels? levels;

  @override
  List<Object?> get props => [defaultCount, maxCount, separator, cursor, pattern, totalScope, levels];
}

/// The level pages of a key browser.
class KeyScanLevels extends Equatable {
  const KeyScanLevels({this.rootKind});

  /// The object kind whose rows name the walk's first segment, absent when no tree row stands for a folder.
  final String? rootKind;

  @override
  List<Object?> get props => [rootKind];
}
