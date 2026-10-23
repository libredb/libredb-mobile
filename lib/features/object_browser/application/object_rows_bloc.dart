import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/query_id.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/statement_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'object_rows_event.dart';
part 'object_rows_state.dart';

/// The first rows of the object at [path] of [connectionId], of [kind]: Studio's preview statement, written by
/// [PreviewStatementGenerator] from the cached provider-meta, run through [IStatementRepository] with a page of 50 rows
/// and a fresh run id, in the path's catalog on a server-level connection.
///
/// The answer is masked at once with the policy of the role the request carries and the engine's exempt column, so the
/// bloc never holds a clear row. A run is a statement: it runs only when the page asks, on open, a pull or a retry,
/// never again by itself after a failure or a schema change, and a request while one runs is dropped. Neither the
/// statement nor a database error text is logged.
class ObjectRowsBloc extends Bloc<ObjectRowsEvent, ObjectRowsState> {
  ObjectRowsBloc({
    required this._statements,
    required this._providerMeta,
    required this.connectionId,
    required this.path,
    required this.kind,
    this._generator = const PreviewStatementGenerator(),
    this._newRunId = newQueryId,
  }) : super(const ObjectRowsLoading()) {
    on<ObjectRowsRequested>(_onRequested, transformer: EventTransformers.dropConcurrent());
  }

  static final _log = AppLogger.getLogger('ObjectRowsBloc');

  final IStatementRepository _statements;
  final IProviderMetaRepository _providerMeta;
  final PreviewStatementGenerator _generator;
  final String Function() _newRunId;

  /// The connection, from the page's route.
  final String connectionId;

  /// The object's path, from the page's route.
  final List<String> path;

  /// The object's kind id, from the page's route.
  final String kind;

  /// The runs answered so far, which tells one result on screen from the next.
  int _runs = 0;

  Future<void> _onRequested(ObjectRowsRequested event, Emitter<ObjectRowsState> emit) async {
    final onScreen = switch (state) {
      final ObjectRowsLoaded loaded => loaded,
      ObjectRowsFailure(:final previous) => previous,
      ObjectRowsLoading() || ObjectRowsUnavailable() => null,
    };
    if (onScreen != null) {
      emit(onScreen.copyWith(isRefreshing: true));
    } else if (state is! ObjectRowsLoading) {
      emit(const ObjectRowsLoading());
    }

    final ProviderMeta meta;
    switch (await _providerMeta.providerMeta(connectionId)) {
      case Failure(:final error):
        if (emit.isDone) return;
        _fail(emit, error, onScreen: onScreen);
        return;
      case Success(:final data):
        meta = data;
    }
    if (emit.isDone) return;
    final declared = meta.objectKinds.where((candidate) => candidate.id == kind).firstOrNull;
    if (declared == null) {
      _log.warn('the engine declares no kind of the route\'s id');
      _fail(emit, const ValidationError('The engine declares no such object kind'), onScreen: onScreen, meta: meta);
      return;
    }

    final PreviewStatement preview;
    switch (_generator.preview(meta, declared, path)) {
      case PreviewUnavailable(:final reason):
        _log.info('no preview for this object: {}', [reason]);
        emit(ObjectRowsUnavailable(meta: meta, kind: declared));
        return;
      case final PreviewStatement statement:
        preview = statement;
    }

    final result = await _statements.run(
      connectionId,
      preview.statement,
      queryId: _newRunId(),
      page: const QueryPage(limit: PreviewStatementGenerator.pageSize),
      catalog: preview.catalog,
    );
    if (emit.isDone) return;
    switch (result) {
      case Failure(:final error):
        _fail(emit, error, onScreen: onScreen, meta: meta, kind: declared);
      case Success(:final data):
        final policy = MaskingPolicy.forRole(event.role, exempt: meta.maskingExemptColumns);
        emit(
          ObjectRowsLoaded(
            meta: meta,
            kind: declared,
            preview: preview,
            masked: maskResult(data, policy),
            policy: policy,
            loadedAt: clock.now(),
            run: ++_runs,
          ),
        );
    }
  }

  /// Runs [preview], the statement of the rows on screen, again for [page], with a fresh run id and in its catalog, for
  /// the result view's Load more; the state does not change, and a failure is answered, never run again by itself.
  Future<Result<QueryResult>> loadPage(PreviewStatement preview, QueryPage page) async {
    final answer = await _statements.run(
      connectionId,
      preview.statement,
      queryId: _newRunId(),
      page: page,
      catalog: preview.catalog,
    );
    if (answer case Failure(:final error)) _log.warn('page not read: {}', [error.code ?? error.runtimeType]);
    return answer;
  }

  void _fail(
    Emitter<ObjectRowsState> emit,
    AppError error, {
    required ObjectRowsLoaded? onScreen,
    ProviderMeta? meta,
    ObjectKind? kind,
  }) {
    _log.warn('rows not read: {}', [error.code ?? error.runtimeType]);
    // A request the offline device never sent says nothing new, so the rows on screen stay, marked stale by the page.
    if (onScreen != null && error.code == AppErrorCode.networkOffline.key) {
      emit(onScreen.copyWith(isRefreshing: false));
      return;
    }
    emit(
      ObjectRowsFailure(
        error: error,
        meta: meta ?? onScreen?.meta,
        kind: kind ?? onScreen?.kind,
        previous: onScreen?.copyWith(isRefreshing: false),
      ),
    );
  }
}
