import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';

part 'connection_policy_state.dart';

/// What Studio allows for connections and whether Platform governs it, for the signed-in user's session.
class ConnectionPolicyCubit extends Cubit<ConnectionPolicyState> {
  ConnectionPolicyCubit({required this._repository}) : super(const ConnectionPolicyInitial());

  static final _log = AppLogger.getLogger('ConnectionPolicyCubit');

  final IConnectionRepository _repository;

  /// Counts the sign-outs, so an answer for a user who has signed out since it was asked for is dropped.
  int _generation = 0;

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

  /// Forgets the signed-out user's policy, including an answer still on its way.
  void clear() {
    _generation++;
    emit(const ConnectionPolicyInitial());
  }
}
