import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';

part 'connection_policy_state.dart';

/// What Studio allows for connections and whether Platform governs it, for the signed-in user's session.
///
/// A Cubit, not a Bloc: the policy is one idempotent GET, with no payload to carry and nothing to debounce or replay.
/// The two guards below read like the drop-concurrent policy `EventTransformer` exists for, and one of them is —
/// `droppable()` would cover a second [load] or [refresh] while an answer is awaited. The one that matters would not
/// move: [_generation] drops an answer about a user who signed out while it was on its way, and [clear] is a
/// different interaction from [load], so no transformer spans the two. In a Bloc it would still be this counter,
/// written by hand, next to an event stream nothing else uses.
class ConnectionPolicyCubit extends Cubit<ConnectionPolicyState> {
  ConnectionPolicyCubit({required this._repository}) : super(const ConnectionPolicyInitial());

  static final _log = AppLogger.getLogger('ConnectionPolicyCubit');

  final IConnectionRepository _repository;

  /// Counts the sign-outs, so an answer for a user who has signed out since it was asked for is dropped.
  int _generation = 0;

  /// Whether a [refresh] awaits its answer.
  bool _refreshing = false;

  /// Asks Studio again; a call while an answer is awaited sends no second request.
  Future<void> load() async {
    if (state is ConnectionPolicyLoading) return;
    final generation = _generation;
    emit(const ConnectionPolicyLoading());
    final result = await _repository.fetchPolicy();
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final data):
        emit(ConnectionPolicyLoaded(data));
      case Failure(:final error):
        _log.warn('load failed: {}', [error.code ?? error.runtimeType]);
        emit(ConnectionPolicyFailure(AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
    }
  }

  /// Asks Studio again with the connection list, keeping a loaded policy on screen while it waits and when the answer
  /// fails, which is logged; without a loaded policy it is [load].
  Future<void> refresh() async {
    final current = state;
    if (current is! ConnectionPolicyLoaded) return load();
    if (_refreshing) return;
    _refreshing = true;
    final generation = _generation;
    try {
      final result = await _repository.fetchPolicy();
      if (isClosed || generation != _generation) return;
      switch (result) {
        case Success(:final data):
          emit(ConnectionPolicyLoaded(data));
        case Failure(:final error):
          _log.warn('refresh failed, keeping the policy loaded before: {}', [error.code ?? error.runtimeType]);
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Forgets the signed-out user's policy, including an answer still on its way.
  void clear() {
    _generation++;
    emit(const ConnectionPolicyInitial());
  }
}
