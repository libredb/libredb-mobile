import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/application/usecases/list_audit_events_usecase.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'audit_log_event.dart';
part 'audit_log_state.dart';

/// The audit log of the install in Platform mode: governed query events, newest first, with filters and paging.
///
/// A refresh or a filter change reads the first page and replaces one still running. The typed search text is sent
/// once the typing pauses for [debounce], trimmed, and never when it equals the current search. A filter set while the
/// text waits for its pause is sent together with that text, in one request, unless it changes the search itself (the
/// search chip's delete) or clears every filter, which drop the waiting text. Load more reads the
/// next page from the end of the rows Platform answered so far, is dropped while one runs, and its answer is used only
/// while the list it was asked for is still on screen: a refresh or a filter change in between discards it. An event
/// already listed is not listed again, since a new event moves every older one a place down between two pages. A
/// failed filter change keeps the list with the filter it was read with, so the chips name the rows shown.
///
/// `PLAN_FEATURE_REQUIRED` and `PERMISSION_DENIED` replace any list with their own state. The events live in this bloc
/// only and are never stored, and no log line carries a filter value, a statement or a user.
class AuditLogBloc extends Bloc<AuditLogEvent, AuditLogState> {
  AuditLogBloc({required this._listAuditEventsUseCase}) : super(const AuditLogInitial(filter: AuditFilter())) {
    on<AuditLogQueryEvent>(_onQuery, transformer: EventTransformers.restart());
    on<AuditLogSearchChanged>(_onSearchChanged);
    on<AuditLogLoadMoreRequested>(_onLoadMore, transformer: EventTransformers.dropConcurrent());
  }

  /// How long the search waits after the last keystroke.
  static const debounce = Duration(milliseconds: 400);

  static final _log = AppLogger.getLogger('AuditLogBloc');

  final ListAuditEventsUseCase _listAuditEventsUseCase;

  /// The wait of the last typed search text.
  Timer? _wait;

  /// The trimmed search text [_wait] sends, held while it waits.
  String? _pendingSearch;

  /// Counts every first page asked for, so a Load more answer for an older list is dropped.
  int _generation = 0;

  /// The filter the listed events were read with, which a failed filter change gives back to the list.
  AuditFilter? _listedFilter;

  Future<void> _onQuery(AuditLogQueryEvent event, Emitter<AuditLogState> emit) async {
    final waiting = _wait != null;
    final pendingSearch = _pendingSearch;
    final filter = switch (event) {
      // Another filter set while the typed text waits for its pause is sent with that text, so the request carries
      // both; a change of the search itself wins over the waiting text.
      AuditLogFilterChanged(:final filter) when waiting && filter.search == state.filter.search => filter.copyWith(
        search: () => pendingSearch,
      ),
      AuditLogFilterChanged(:final filter) => filter,
      AuditLogRefreshed() => state.filter,
      AuditLogFiltersCleared() => const AuditFilter(),
    };
    if (event is! AuditLogRefreshed) _cancelWait();
    _generation++;

    final current = state;
    if (current is AuditLogLoaded) {
      emit(
        current._with(
          filter: filter,
          isRefreshing: true,
          refreshError: () => null,
          isLoadingMore: false,
          loadMoreError: () => null,
        ),
      );
    } else {
      emit(AuditLogLoading(filter: filter));
    }

    final result = await _listAuditEventsUseCase(filter: filter, offset: 0);
    if (emit.isDone) return;
    switch (result) {
      case Success(:final data):
        _log.debug('load: {} events of {}, filters {}', [data.events.length, data.total, filter.setFilterNames]);
        _listedFilter = filter;
        emit(
          AuditLogLoaded(
            filter: filter,
            events: _distinct(const [], data.events),
            total: data.total,
            nextOffset: _nextOffset(data),
          ),
        );
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        // The code only: Platform's message can name a user.
        _log.warn('load failed: {}', [error.code ?? error.runtimeType]);
        final refused = _refusal(errorCode, filter);
        if (refused != null) {
          emit(refused);
        } else if (state case final AuditLogLoaded loaded) {
          // The kept rows and their next offset belong to the filter they were read with, so the chips and a Load
          // more go back to it rather than mixing the failed filter's pages into another filter's rows.
          emit(loaded._with(filter: _listedFilter!, isRefreshing: false, refreshError: () => errorCode));
        } else {
          emit(AuditLogFailure(filter: filter, errorCode: errorCode));
        }
    }
  }

  void _onSearchChanged(AuditLogSearchChanged event, Emitter<AuditLogState> emit) {
    // Trimmed and cut to Platform's limit as the filter keeps it, so text that would send the same search sends none.
    final search = AuditFilter(search: event.text).search;
    _cancelWait();
    if (search == state.filter.search) return;
    _pendingSearch = search;
    _wait = Timer(debounce, () {
      _wait = null;
      _pendingSearch = null;
      if (!isClosed) add(AuditLogFilterChanged(state.filter.copyWith(search: () => search)));
    });
  }

  Future<void> _onLoadMore(AuditLogLoadMoreRequested event, Emitter<AuditLogState> emit) async {
    final current = state;
    if (current is! AuditLogLoaded || !current.canLoadMore) return;
    final generation = _generation;
    final filter = current.filter;
    final offset = current.nextOffset!;
    emit(current._with(isLoadingMore: true, loadMoreError: () => null));

    final result = await _listAuditEventsUseCase(filter: filter, offset: offset);
    final listed = state;
    if (emit.isDone || generation != _generation || listed is! AuditLogLoaded || listed.filter != filter) {
      _log.debug('load more: the answer for offset {} is dropped, the list changed meanwhile', [offset]);
      return;
    }
    switch (result) {
      case Success(:final data):
        _log.debug('load more: {} events from offset {} of {}', [data.events.length, offset, data.total]);
        emit(
          AuditLogLoaded(
            filter: filter,
            events: _distinct(listed.events, data.events),
            total: data.total,
            nextOffset: _nextOffset(data),
          ),
        );
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        _log.warn('load more failed: offset {}, {}', [offset, error.code ?? error.runtimeType]);
        emit(_refusal(errorCode, filter) ?? listed._with(isLoadingMore: false, loadMoreError: () => errorCode));
    }
  }

  /// The state of a refusal that no list survives, or null for any other failure.
  static AuditLogState? _refusal(AppErrorCode errorCode, AuditFilter filter) => switch (errorCode) {
    AppErrorCode.platformPlanFeatureRequired => AuditLogPlanRefused(filter: filter),
    AppErrorCode.platformPermissionDenied => AuditLogPermissionRefused(filter: filter),
    _ => null,
  };

  /// Where the page after [page] starts, or null when [page] was the last.
  static int? _nextOffset(AuditPage page) => page.hasMore ? page.offset + page.events.length : null;

  /// [listed] followed by the events of [next] whose id is not listed yet.
  static List<AuditEvent> _distinct(List<AuditEvent> listed, List<AuditEvent> next) {
    final ids = {for (final event in listed) event.eventId};
    return List.unmodifiable([
      ...listed,
      for (final event in next)
        if (ids.add(event.eventId)) event,
    ]);
  }

  void _cancelWait() {
    _wait?.cancel();
    _wait = null;
    _pendingSearch = null;
  }

  @override
  Future<void> close() {
    _cancelWait();
    return super.close();
  }
}
