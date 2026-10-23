import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/entities/key_scan_page.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'key_browser_event.dart';
part 'key_browser_state.dart';

/// Pages through the key space of [connectionId] in the shape its engine declares in `keyScan`.
///
/// The first page sends no cursor and each later page the cursor of the page before, exactly as it came. The pattern
/// is a glob that starts at `*`, or a literal prefix that starts empty, is sent as typed and is left out while empty.
/// [container]'s first segment is sent as the numbered database only when it is all digits, as Studio's own panel
/// does, so any other engine walks its own. An engine with `levels` is asked one level at a time, with [prefix], the
/// folder the page opens, at the head of the pattern. Pages are never kept between screens.
class KeyBrowserBloc extends Bloc<KeyBrowserEvent, KeyBrowserState> {
  KeyBrowserBloc({
    required this._repository,
    required this._providerMeta,
    required this.connectionId,
    required this.container,
    this.prefix,
  }) : super(const KeyBrowserLoading()) {
    on<KeyBrowserPageEvent>(_onPage, transformer: EventTransformers.dropConcurrent());
    on<KeyBrowserStopped>(_onStopped);
  }

  /// How many keys the screen holds at most, as Studio's web panel caps one Scan all and the keys it holds.
  static const heldKeyLimit = 10000;

  static final _log = AppLogger.getLogger('KeyBrowserBloc');
  static final _digits = RegExp(r'^\d+$');

  final IObjectBrowserRepository _repository;
  final IProviderMetaRepository _providerMeta;

  /// The connection, from the page's route.
  final String connectionId;

  /// The container the screen was opened in, empty on an engine with no container level.
  final List<String> container;

  /// The level folder the page lists, ending in the separator; null at the top.
  final String? prefix;

  bool _stop = false;

  /// The numbered database to walk: the container's first segment when it is all digits.
  int? get _database {
    if (container.isEmpty || !_digits.hasMatch(container.first)) return null;
    return int.tryParse(container.first);
  }

  Future<void> _onPage(KeyBrowserPageEvent event, Emitter<KeyBrowserState> emit) async {
    switch (event) {
      case KeyBrowserStarted():
        await _start(emit);
      case KeyBrowserPatternSubmitted(:final text):
        final walk = _walkOnScreen;
        if (walk == null) return _start(emit);
        await _readPage(KeyBrowserLoaded(meta: walk.meta, spec: walk.spec, pattern: text), KeyPageLoad.more, emit);
      case KeyBrowserMoreRequested():
        final walk = _walkOnScreen;
        if (walk == null) return _start(emit);
        if (!walk.hasMore || walk.atCap) return;
        await _readPage(walk, KeyPageLoad.more, emit);
      case KeyBrowserAllRequested():
        await _readAll(emit);
    }
  }

  void _onStopped(KeyBrowserStopped event, Emitter<KeyBrowserState> emit) {
    final state = this.state;
    if (state is! KeyBrowserLoaded || state.load != KeyPageLoad.all) return;
    _stop = true;
    emit(state.copyWith(stopping: true));
  }

  /// The walk on screen, under a failed page's error too.
  KeyBrowserLoaded? get _walkOnScreen => switch (state) {
    final KeyBrowserLoaded loaded => loaded,
    KeyBrowserFailure(:final previous) => previous,
    KeyBrowserLoading() || KeyBrowserUnavailable() => null,
  };

  Future<void> _start(Emitter<KeyBrowserState> emit) async {
    emit(const KeyBrowserLoading());
    final meta = await _providerMeta.providerMeta(connectionId);
    if (emit.isDone) return;
    switch (meta) {
      case Failure(:final error):
        _log.warn('the key walk was not read: {}', [error.code ?? error.runtimeType]);
        emit(KeyBrowserFailure(error: error));
      case Success(data: ProviderMeta(keyScan: null)):
        _log.warn('the engine declares no key walk');
        emit(const KeyBrowserUnavailable());
      case Success(data: final meta && ProviderMeta(keyScan: final spec?)):
        await _readPage(
          KeyBrowserLoaded(meta: meta, spec: spec, pattern: spec.pattern == 'glob' ? '*' : ''),
          KeyPageLoad.more,
          emit,
        );
    }
  }

  Future<void> _readAll(Emitter<KeyBrowserState> emit) async {
    var walk = _walkOnScreen;
    if (walk == null || !walk.hasMore || walk.atCap) return;
    _stop = false;
    while (walk != null && walk.hasMore && !walk.atCap && !_stop) {
      walk = await _readPage(walk, KeyPageLoad.all, emit, last: false);
      if (emit.isDone) return;
    }
    if (walk != null) emit(walk.copyWith(load: KeyPageLoad.idle, stopping: false));
    _stop = false;
  }

  /// Reads the page after [walk] and returns the walk with it, or null when it failed. The walk is shown as loading
  /// [load] while the page is in flight; with [last], the default, it is shown idle once the page is in.
  Future<KeyBrowserLoaded?> _readPage(
    KeyBrowserLoaded walk,
    KeyPageLoad load,
    Emitter<KeyBrowserState> emit, {
    bool last = true,
  }) async {
    emit(walk.copyWith(load: load, stopping: _stop && load == KeyPageLoad.all));
    final result = await _repository.scanKeys(
      connectionId,
      cursor: walk.cursor,
      pattern: _sentPattern(walk),
      database: _database,
      level: walk.usesLevels,
    );
    if (emit.isDone) return null;
    switch (result) {
      case Failure(:final error):
        _log.warn('a key page was not read: {}', [error.code ?? error.runtimeType]);
        emit(
          KeyBrowserFailure(
            error: error,
            previous: walk.copyWith(load: KeyPageLoad.idle, stopping: false),
          ),
        );
        return null;
      case Success(data: final page):
        final next = _merge(walk, page, last ? KeyPageLoad.idle : load);
        emit(next);
        return next;
    }
  }

  /// The pattern a page is asked with: under `glob` the text, under `prefix` the level's folder followed by the text,
  /// with nothing added; left out while empty.
  String? _sentPattern(KeyBrowserLoaded walk) {
    final pattern = walk.spec.pattern == 'glob' ? walk.pattern : '${prefix ?? ''}${walk.pattern}';
    return pattern.isEmpty ? null : pattern;
  }

  KeyBrowserLoaded _merge(KeyBrowserLoaded walk, KeyScanPage page, KeyPageLoad load) {
    // As Studio's panel absorbs a page: a name already held is skipped, the page's folders come before its keys, and
    // nothing is taken past heldKeyLimit, so the page that crosses it is trimmed to exactly the limit.
    final folders = <String>{...walk.folders};
    final keys = <String>{...walk.keys};
    bool absorb(Set<String> into, String name) {
      if (into.contains(name)) return true;
      if (folders.length + keys.length >= heldKeyLimit) return false;
      into.add(name);
      return true;
    }

    for (final folder in page.prefixes ?? const <String>[]) {
      if (!absorb(folders, folder)) break;
    }
    for (final key in page.keys) {
      if (!absorb(keys, key)) break;
    }
    final skipped = switch ((walk.skipped, page.skipped)) {
      (final before?, final now?) => KeyScanSkipped(count: before.count + now.count, reason: now.reason),
      (final before, final now) => now ?? before,
    };
    return KeyBrowserLoaded(
      meta: walk.meta,
      spec: walk.spec,
      pattern: walk.pattern,
      keys: List.unmodifiable(keys),
      types: Map.unmodifiable({...walk.types, ...page.types}),
      folders: List.unmodifiable(folders),
      scanned: walk.scanned + page.keys.length + (page.prefixes?.length ?? 0),
      cursor: page.cursor,
      total: walk.spec.totalScope == 'none' ? null : page.total,
      clustered: page.clustered,
      skipped: skipped,
      readOutcome: page.readOutcome ?? walk.readOutcome,
      load: load,
      stopping: load == KeyPageLoad.all && _stop,
    );
  }
}
