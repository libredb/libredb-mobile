import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/search_directory_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'directory_picker_event.dart';
part 'directory_picker_state.dart';

/// The search of LibreDB Platform's directory behind the grant picker.
///
/// Each search or page costs Platform up to 22 Keycloak Admin calls, which cancelling on the phone does not stop, so it
/// sends few: the first page of every user once when the picker opens, then a typed query only once the user stops
/// typing for [debounce], trimmed. A query in flight, or on screen with nothing in flight, is never sent again, so
/// typing away from it and back within the pause sends nothing, while after a failure Retry sends the same query again.
/// A query longer than [maxQueryLength] is never sent and shows a hint. A newer query wins: the answer to an older one,
/// or to a page of it, is dropped.
///
/// "Load more" keeps the query on screen, is dropped while one runs, and adds only users not already listed, because
/// Keycloak's pages can shift between requests. The results live in this bloc only and are never cached or stored, and
/// no log line carries the query or a user.
class DirectoryPickerBloc extends Bloc<DirectoryPickerEvent, DirectoryPickerState> {
  DirectoryPickerBloc({required this._searchDirectoryUseCase})
    : super(const DirectoryPickerState(status: DirectoryPickerStatus.loading, query: '')) {
    on<DirectoryPickerOpened>(_onOpened);
    on<DirectoryPickerQueryChanged>(_onQueryChanged);
    on<DirectoryPickerRetryRequested>(_onRetry);
    on<DirectoryPickerLoadMoreRequested>(_onLoadMore, transformer: EventTransformers.dropConcurrent());
    on<_DirectoryPickerSearchSent>(_onSearchSent, transformer: EventTransformers.restart());
  }

  /// How long the search waits after the last keystroke.
  static const debounce = Duration(milliseconds: 400);

  /// The longest trimmed query Platform accepts, in UTF-16 code units as JavaScript counts them, which
  /// [String.length] counts too (libredb-platform `searchDirectoryUsersSchema`).
  static const maxQueryLength = 255;

  static final _log = AppLogger.getLogger('DirectoryPickerBloc');

  final SearchDirectoryUseCase _searchDirectoryUseCase;

  /// The wait of the last typed query.
  Timer? _wait;

  /// The query whose first page is in flight, null when none is.
  String? _inFlight;

  /// The query whose answer is on screen, null when none is.
  String? _shown;

  /// Counts every first page sent, so only the answer to the latest one, and to pages of it, is shown.
  int _generation = 0;

  void _onOpened(DirectoryPickerOpened event, Emitter<DirectoryPickerState> emit) {
    if (_generation > 0) return;
    _send('');
  }

  void _onQueryChanged(DirectoryPickerQueryChanged event, Emitter<DirectoryPickerState> emit) {
    final query = event.text.trim();
    _cancelWait();
    final tooLong = query.length > maxQueryLength;
    if (tooLong != state.queryTooLong) emit(state._with(queryTooLong: tooLong));
    if (tooLong || _isCurrent(query)) return;
    _wait = Timer(debounce, () {
      _wait = null;
      if (!isClosed) _send(query);
    });
  }

  void _onRetry(DirectoryPickerRetryRequested event, Emitter<DirectoryPickerState> emit) {
    if (state.status != DirectoryPickerStatus.failure || _inFlight != null) return;
    _cancelWait();
    _send(state.query);
  }

  /// Whether [query] is in flight, or on screen while nothing is.
  bool _isCurrent(String query) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight == query;
    return _shown == query;
  }

  void _send(String query) {
    _generation++;
    _inFlight = query;
    _shown = null;
    add(_DirectoryPickerSearchSent(query, _generation));
  }

  void _cancelWait() {
    _wait?.cancel();
    _wait = null;
  }

  Future<void> _onSearchSent(_DirectoryPickerSearchSent event, Emitter<DirectoryPickerState> emit) async {
    final _DirectoryPickerSearchSent(:query, :generation) = event;
    emit(DirectoryPickerState(status: DirectoryPickerStatus.loading, query: query, queryTooLong: state.queryTooLong));
    final result = await _searchDirectoryUseCase(query: query, page: 1);
    if (emit.isDone || generation != _generation) return;
    _inFlight = null;
    switch (result) {
      case Success(:final data):
        _shown = query;
        _log.debug('search: page 1, {} users of {}', [data.users.length, data.total]);
        emit(
          DirectoryPickerState(
            status: DirectoryPickerStatus.loaded,
            query: query,
            users: _distinct(const [], data.users),
            page: 1,
            total: data.total,
            lastPageSize: data.users.length,
            queryTooLong: state.queryTooLong,
          ),
        );
      case Failure(:final error):
        // The code only: Platform's message can name a user.
        _log.warn('search failed: {}', [error.code ?? error.runtimeType]);
        emit(
          DirectoryPickerState(
            status: DirectoryPickerStatus.failure,
            query: query,
            error: AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic,
            queryTooLong: state.queryTooLong,
          ),
        );
    }
  }

  Future<void> _onLoadMore(DirectoryPickerLoadMoreRequested event, Emitter<DirectoryPickerState> emit) async {
    if (!state.canLoadMore) return;
    final generation = _generation;
    final page = state.page + 1;
    emit(state._with(loadingMore: true, loadMoreError: () => null));
    final result = await _searchDirectoryUseCase(query: state.query, page: page);
    if (emit.isDone || generation != _generation) return;
    final current = state;
    switch (result) {
      case Success(:final data):
        _log.debug('load more: page {}, {} users of {}', [page, data.users.length, data.total]);
        emit(
          DirectoryPickerState(
            status: DirectoryPickerStatus.loaded,
            query: current.query,
            users: _distinct(current.users, data.users),
            page: page,
            total: data.total,
            lastPageSize: data.users.length,
            queryTooLong: current.queryTooLong,
          ),
        );
      case Failure(:final error):
        _log.warn('load more failed: page {}, {}', [page, error.code ?? error.runtimeType]);
        emit(
          current._with(
            loadingMore: false,
            loadMoreError: () => AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic,
          ),
        );
    }
  }

  /// [listed] followed by the users of [next] whose id is not listed yet.
  static List<DirectoryUser> _distinct(List<DirectoryUser> listed, List<DirectoryUser> next) {
    final ids = {for (final user in listed) user.id};
    return List.unmodifiable([
      ...listed,
      for (final user in next)
        if (ids.add(user.id)) user,
    ]);
  }

  @override
  Future<void> close() {
    _cancelWait();
    return super.close();
  }
}
