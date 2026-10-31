import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/auth/domain/repositories/platform_identity_repository.dart';
import 'package:libredb_mobile/shared/models/platform_identity.dart';

part 'platform_identity_state.dart';

/// Who LibreDB Platform says the signed-in admin is, for every Platform screen.
///
/// The identity lives here only, from Platform's latest `GET /api/v1/me` answer or the sign-in gate's ([signedIn]), and
/// is never stored. A failure never ends the session: only the Platform client does that, for a 401 `BEARER_INVALID`
/// that survives the token refresh.
///
/// A Cubit, not a Bloc: the identity is one idempotent GET, with nothing to debounce or replay. [_generation] drops
/// an answer about an admin who signed out while it was on its way, and because [clear] is an interaction of its own,
/// no `EventTransformer` spans it and [load] — it would stay this counter in a Bloc too.
class PlatformIdentityCubit extends Cubit<PlatformIdentityState> {
  PlatformIdentityCubit({required this._repository}) : super(const PlatformIdentityInitial());

  static final _log = AppLogger.getLogger('PlatformIdentityCubit');

  final IPlatformIdentityRepository _repository;

  /// Counts the sign-outs, so an answer about an admin who has signed out since it was asked for is dropped.
  int _generation = 0;

  /// Asks Platform again; a call while an answer is awaited sends no second request.
  Future<void> load() async {
    if (state is PlatformIdentityLoading) return;
    final generation = _generation;
    emit(const PlatformIdentityLoading());
    final result = await _repository.fetch();
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Success(:final data):
        emit(PlatformIdentityLoaded(data));
      case Failure(:final error):
        _log.warn('load failed: {}', [error.code ?? error.runtimeType]);
        emit(PlatformIdentityFailure(AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic));
    }
  }

  /// The identity the sign-in gate has just read, so the shell needs no second request.
  void signedIn(PlatformIdentity identity) => emit(PlatformIdentityLoaded(identity));

  /// Forgets the signed-out admin, including an answer still on its way.
  void clear() {
    _generation++;
    emit(const PlatformIdentityInitial());
  }
}
