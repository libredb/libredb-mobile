part of 'key_browser_bloc.dart';

/// What the screen is reading pages for.
enum KeyPageLoad { idle, more, all }

sealed class KeyBrowserState extends Equatable {
  const KeyBrowserState();

  @override
  List<Object?> get props => const [];
}

/// The engine's walk and the first page are on their way.
final class KeyBrowserLoading extends KeyBrowserState {
  const KeyBrowserLoading();
}

/// The engine declares no key walk, so there is nothing to page.
final class KeyBrowserUnavailable extends KeyBrowserState {
  const KeyBrowserUnavailable();
}

/// The walk so far: every key and folder the pages named, held once each, and what the pages said about it.
final class KeyBrowserLoaded extends KeyBrowserState {
  const KeyBrowserLoaded({
    required this.meta,
    required this.spec,
    required this.pattern,
    this.keys = const [],
    this.types = const {},
    this.folders = const [],
    this.scanned = 0,
    this.cursor,
    this.total,
    this.clustered,
    this.skipped,
    this.readOutcome,
    this.load = KeyPageLoad.idle,
    this.stopping = false,
  });

  /// The engine's provider-meta, which says what a tap on a key opens.
  final ProviderMeta meta;

  /// The shape of the engine's walk.
  final KeyScanSpec spec;

  /// The text of the pattern field this walk was asked with; on a level page, what narrows the folder.
  final String pattern;

  /// The distinct keys, in the order the pages named them.
  final List<String> keys;

  /// The value type of each key whose type a page read.
  final Map<String, String> types;

  /// The folders of a level page, from Studio's `prefixes`, in the order they came; always empty without levels.
  final List<String> folders;

  /// The keys and folders the pages handed over, repeats included.
  final int scanned;

  /// The cursor of the last page, null before the first page answered.
  final String? cursor;

  /// The count the engine publishes, in the scope `spec.totalScope` names; null under `none` or before a page.
  final int? total;

  /// Whether the last page said it describes one node of a cluster.
  final bool? clustered;

  /// The keys the pages left out, added up, with the last page's reason.
  final KeyScanSkipped? skipped;

  /// What the engine says about the read's completeness, from the last page that said anything.
  final KeyReadOutcome? readOutcome;

  final KeyPageLoad load;

  /// Stop was asked during a Load all and takes effect after the page in flight.
  final bool stopping;

  /// Whether the walk has pages left: until the cursor returns to `0`.
  bool get hasMore => cursor != '0';

  /// The keys and folders the screen holds.
  int get held => keys.length + folders.length;

  /// Whether the screen holds as many keys as it keeps, so no further page is read.
  bool get atCap => held >= KeyBrowserBloc.heldKeyLimit;

  bool get usesLevels => spec.levels != null;

  KeyBrowserLoaded copyWith({KeyPageLoad? load, bool? stopping}) => KeyBrowserLoaded(
    meta: meta,
    spec: spec,
    pattern: pattern,
    keys: keys,
    types: types,
    folders: folders,
    scanned: scanned,
    cursor: cursor,
    total: total,
    clustered: clustered,
    skipped: skipped,
    readOutcome: readOutcome,
    load: load ?? this.load,
    stopping: stopping ?? this.stopping,
  );

  @override
  List<Object?> get props => [
    meta,
    spec,
    pattern,
    keys,
    types,
    folders,
    scanned,
    cursor,
    total,
    clustered,
    skipped,
    readOutcome,
    load,
    stopping,
  ];
}

/// A page could not be read.
///
/// [error] is shown by `StudioErrorBanner`; [previous] is the walk on screen before the failed page, which stays
/// under the error and resumes from its cursor. It is null when the engine's walk itself could not be read.
final class KeyBrowserFailure extends KeyBrowserState {
  const KeyBrowserFailure({required this.error, this.previous});

  final AppError error;
  final KeyBrowserLoaded? previous;

  @override
  List<Object?> get props => [error, previous];
}
