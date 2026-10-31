import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/studio_identity_repository.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

part 'studio_identity_state.dart';

/// Who Studio says the signed-in user is, for every screen that shows or decides on the user's role.
///
/// The role lives here only, from Studio's latest `GET /api/auth/me` answer or a mode switch's ([signedIn]), and is
/// never stored. A failure never ends the session: only the ApiClient does that, for a 401 `AUTH_REQUIRED` that
/// survives the token refresh.
///
/// A Cubit, not a Bloc: the identity is one idempotent GET, with nothing to debounce or replay. [_generation] drops
/// an answer about a user who signed out while it was on its way, and because [clear] and [signedIn] are
/// interactions of their own, no `EventTransformer` spans them — it would stay this counter in a Bloc too.
class StudioIdentityCubit extends Cubit<StudioIdentityState> {
  StudioIdentityCubit({required this._repository}) : super(const StudioIdentityInitial());

  static final _log = AppLogger.getLogger('StudioIdentityCubit');

  final IStudioIdentityRepository _repository;

  /// Counts the sign-outs, so an answer about a user who has signed out since it was asked for is dropped.
  int _generation = 0;

  /// Asks Studio again; a call while an answer is awaited sends no second request.
  Future<void> load() async {
    if (state is StudioIdentityLoading) return;
    final generation = _generation;
    emit(const StudioIdentityLoading());
    final result = await _repository.fetch();
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final data):
        emit(StudioIdentityLoaded(data));
      case Failure(:final error):
        _log.warn('load failed: {}', [error.code ?? error.runtimeType]);
        emit(StudioIdentityFailure(AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
    }
  }

  /// The identity Studio's gate has just read for a mode switch, so the shell needs no second request; an answer still
  /// on its way is dropped.
  void signedIn(StudioIdentity identity) {
    _generation++;
    emit(StudioIdentityLoaded(identity));
  }

  /// Forgets the signed-out user, including an answer still on its way.
  void clear() {
    _generation++;
    emit(const StudioIdentityInitial());
  }
}
