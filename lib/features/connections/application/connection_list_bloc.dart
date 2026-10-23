import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_sections.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';
import 'package:libredb_mobile/shared/utils/search_fold.dart';

part 'connection_list_event.dart';
part 'connection_list_state.dart';

/// The connection list, its search and filter, and its live refresh.
///
/// While the page says the list is in the foreground ([ConnectionListAutoRefreshChanged]), the bloc asks Studio again
/// every `cacheHint`, clamped to [minRefreshInterval] and [maxRefreshInterval] as Studio's web client does, and every
/// [unavailableRetryInterval] while governance is unavailable, longer when a 429 asked for it; a return of the app to
/// the foreground asks at once. A failure screen stops it: an account Studio refuses would be refused, and audited, on
/// every tick, so only the user's retry asks again.
class ConnectionListBloc extends Bloc<ConnectionListEvent, ConnectionListState> {
  ConnectionListBloc({required this._listManagedConnectionsUseCase}) : super(const ConnectionListInitial()) {
    on<ConnectionListLoadEvent>(_onLoad, transformer: EventTransformers.restart());
    on<ConnectionListSearchChanged>(
      _onSearchChanged,
      transformer: EventTransformers.debounceRestartable(searchDebounce),
    );
    on<ConnectionListEnvironmentFilterChanged>(_onEnvironmentFilterChanged);
    on<ConnectionListAutoRefreshChanged>(_onAutoRefreshChanged);
  }

  /// How long the search waits after a keystroke before it narrows the list.
  static const searchDebounce = Duration(milliseconds: 200);

  /// The shortest wait between two timed refreshes, whatever `cacheHint` Studio sent, and the wait without one.
  static const minRefreshInterval = Duration(seconds: 5);

  /// The longest wait between two timed refreshes, whatever `cacheHint` Studio sent.
  static const maxRefreshInterval = Duration(seconds: 60);

  /// The wait between two retries while governance is unavailable.
  static const unavailableRetryInterval = Duration(seconds: 10);

  static final _log = AppLogger.getLogger('ConnectionListBloc');
  final ListManagedConnectionsUseCase _listManagedConnectionsUseCase;

  /// The search and the filter chosen before a list arrived, applied once it does.
  String _query = '';
  String? _environment;

  /// The last list Studio answered, which an offline load keeps on screen even when it restarted another load.
  ConnectionListLoaded? _lastLoaded;

  /// Whether the list is in the foreground, so the live refresh runs.
  bool _active = false;

  /// Whether a load runs; it arms the next timed refresh when it ends.
  bool _loading = false;

  Timer? _refreshTimer;

  FutureOr<void> _onLoad(ConnectionListLoadEvent event, Emitter<ConnectionListState> emit) async {
    _log.debug('BEGIN: onLoad {}', [event.runtimeType]);
    _cancelRefreshTimer();
    final current = state;
    switch ((event, current)) {
      // A timed refresh changes nothing on screen until Studio answers.
      case (ConnectionListPolled(), _):
        break;
      case (ConnectionListRefreshed(), final ConnectionListLoaded loaded):
        emit(loaded._with(isRefreshing: true));
      case (ConnectionListRefreshed(), ConnectionListUnavailable(:final errorCode, :final previous?)):
        emit(ConnectionListUnavailable(errorCode: errorCode, previous: previous, isRetrying: true));
      case _:
        emit(const ConnectionListLoading());
    }
    _loading = true;
    final result = await _listManagedConnectionsUseCase();
    if (emit.isDone) return;
    _loading = false;
    _emitResult(result, emit);
    _scheduleRefresh();
  }

  void _emitResult(Result<ManagedConnections> result, Emitter<ConnectionListState> emit) {
    switch (result) {
      case Success(:final data):
        final loaded = ConnectionListLoaded(
          connections: data.connections,
          cacheHint: data.cacheHint,
          loadedAt: clock.now(),
          query: _query,
          environment: _environment,
        );
        _lastLoaded = loaded;
        emit(loaded);
        _log.debug('END: onLoad connections: {}', [data.connections.length]);
      case Failure(:final error):
        final errorCode = AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic;
        // The rows on screen now, with the search and the filter chosen while Studio was answering; none after a load
        // that showed the spinner.
        final onScreen = switch (state) {
          final ConnectionListLoaded loaded => loaded._with(),
          ConnectionListUnavailable(:final previous) => previous,
          ConnectionListInitial() || ConnectionListLoading() || ConnectionListFailure() => null,
        };
        // A request refused because the device is offline never reached Studio, so what was loaded stays on screen,
        // marked stale by the page, instead of turning into an error; the search and the filter chosen meanwhile stay.
        final kept = _lastLoaded;
        if (errorCode == AppErrorCode.networkOffline) {
          if (state case ConnectionListUnavailable(:final errorCode, :final previous?)) {
            emit(ConnectionListUnavailable(errorCode: errorCode, previous: previous));
            _log.info('END: onLoad offline, governance still unavailable');
            return;
          }
          if (kept != null) {
            emit(kept._with(query: _query, environment: () => _environment));
            _log.info('END: onLoad offline, keeping the {} connections loaded before', [kept.connections.length]);
            return;
          }
        }
        if (errorCode == AppErrorCode.studioGovernanceUnavailable) {
          // An outage says nothing about the grants: the rows shown before stay, greyed, and nothing reads as empty.
          emit(ConnectionListUnavailable(errorCode: errorCode, previous: onScreen));
          _log.warn('END: onLoad governance unavailable, keeping {} connections', [onScreen?.connections.length ?? 0]);
          return;
        }
        if (state case ConnectionListUnavailable(:final errorCode, :final previous?) when error is! AuthError) {
          // A retry that failed before it reached governance says nothing about whether governance is back, so the
          // rows stay greyed and the outage keeps its retry.
          emit(ConnectionListUnavailable(errorCode: errorCode, previous: previous, retryError: error));
          _log.warn('END: onLoad governance still unavailable, the retry failed: {}', [
            error.code ?? error.runtimeType,
          ]);
          return;
        }
        if (error is AuthError || onScreen == null) {
          // Studio refused the account or failed the list, so the rows loaded before are no longer shown and are not
          // brought back.
          _lastLoaded = null;
          emit(ConnectionListFailure(errorCode: errorCode));
        } else {
          emit(onScreen._with(refreshError: error));
        }
        _log.error('END: onLoad error: {}', [error.message]);
    }
  }

  void _onAutoRefreshChanged(ConnectionListAutoRefreshChanged event, Emitter<ConnectionListState> emit) {
    if (event.active == _active) return;
    _active = event.active;
    _log.debug('onAutoRefreshChanged active: {}', [event.active]);
    if (!_active) {
      _cancelRefreshTimer();
      return;
    }
    // A running load arms the timer when it ends.
    if (_loading) return;
    // Back in the foreground, what Studio offers may have changed meanwhile, so the page asks at once. The ask waits for
    // a zero timer, so a refresh sent at the same moment, such as the page's on a reconnect, replaces it instead of
    // asking twice.
    _scheduleRefresh(immediately: event.askNow);
  }

  /// How long the next timed refresh waits in the current state, or null when the state takes none.
  Duration? _refreshDelay() => switch (state) {
    ConnectionListLoaded(:final cacheHint, :final refreshError) => _longer(
      _clamp(cacheHint ?? Duration.zero),
      refreshError is RateLimitedError ? refreshError.retryAfter : null,
    ),
    ConnectionListUnavailable(:final retryError) => _longer(
      unavailableRetryInterval,
      retryError is RateLimitedError ? retryError.retryAfter : null,
    ),
    ConnectionListInitial() || ConnectionListLoading() || ConnectionListFailure() => null,
  };

  static Duration _clamp(Duration hint) => hint < minRefreshInterval
      ? minRefreshInterval
      : hint > maxRefreshInterval
      ? maxRefreshInterval
      : hint;

  static Duration _longer(Duration interval, Duration? retryAfter) =>
      retryAfter != null && retryAfter > interval ? retryAfter : interval;

  void _scheduleRefresh({bool immediately = false}) {
    _cancelRefreshTimer();
    if (!_active || isClosed) return;
    final delay = _refreshDelay();
    if (delay == null) return;
    _refreshTimer = Timer(immediately ? Duration.zero : delay, () {
      _refreshTimer = null;
      if (!isClosed) add(const ConnectionListPolled());
    });
  }

  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  Future<void> close() {
    _cancelRefreshTimer();
    return super.close();
  }

  void _onSearchChanged(ConnectionListSearchChanged event, Emitter<ConnectionListState> emit) {
    _query = event.query;
    switch (state) {
      case final ConnectionListLoaded loaded:
        emit(loaded._with(query: event.query, isRefreshing: loaded.isRefreshing, refreshError: loaded.refreshError));
      case ConnectionListUnavailable(:final errorCode, :final previous?, :final isRetrying, :final retryError):
        emit(
          ConnectionListUnavailable(
            errorCode: errorCode,
            previous: previous._with(query: event.query),
            isRetrying: isRetrying,
            retryError: retryError,
          ),
        );
      case ConnectionListInitial() || ConnectionListLoading() || ConnectionListUnavailable() || ConnectionListFailure():
        break;
    }
  }

  void _onEnvironmentFilterChanged(ConnectionListEnvironmentFilterChanged event, Emitter<ConnectionListState> emit) {
    _environment = event.environment;
    switch (state) {
      case final ConnectionListLoaded loaded:
        emit(
          loaded._with(
            environment: () => event.environment,
            isRefreshing: loaded.isRefreshing,
            refreshError: loaded.refreshError,
          ),
        );
      case ConnectionListUnavailable(:final errorCode, :final previous?, :final isRetrying, :final retryError):
        emit(
          ConnectionListUnavailable(
            errorCode: errorCode,
            previous: previous._with(environment: () => event.environment),
            isRetrying: isRetrying,
            retryError: retryError,
          ),
        );
      case ConnectionListInitial() || ConnectionListLoading() || ConnectionListUnavailable() || ConnectionListFailure():
        break;
    }
  }
}
