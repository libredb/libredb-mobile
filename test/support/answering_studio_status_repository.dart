import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/studio_readiness.dart';
import 'package:libredb_mobile/features/studio_status/domain/repositories/studio_status_repository.dart';

/// Studio answers every liveness check at once, and its readiness is ready.
///
/// For an App test about something else whose network refuses every request it does not list, or whose device is
/// offline: the Studio status check would fail there and show the unreachable page in place of the app.
class AnsweringStudioStatusRepository implements IStudioStatusRepository {
  const AnsweringStudioStatusRepository();

  @override
  Future<Result<void>> liveness() async => const Success(null);

  @override
  Future<Result<StudioReadiness>> readiness() async => const Success(StudioReadinessReady());
}
