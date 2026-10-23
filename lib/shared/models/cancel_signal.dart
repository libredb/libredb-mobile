import 'dart:async';

/// Drops one request the app sent: after [cancel] the app stops waiting for its answer, and the request fails as
/// cancelled. A request that was already answered keeps its answer.
///
/// Studio cancels a run whose request is dropped, where the engine supports it, so dropping the request of a statement
/// is how a page the user left stops it without spending a request slot on `POST /api/db/cancel`.
class CancelSignal {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes once, when [cancel] is first called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Drops the request; a second call changes nothing.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}
