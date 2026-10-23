part of 'result_view_bloc.dart';

sealed class ResultViewEvent extends Equatable {
  const ResultViewEvent();

  @override
  List<Object?> get props => const [];
}

/// The caller ran the statement again and masked its answer with the view's policy; it replaces the result shown.
final class ResultViewReplaced extends ResultViewEvent {
  const ResultViewReplaced(this.masked);

  final MaskedResult masked;

  @override
  List<Object?> get props => [masked];
}

/// The user asked for the next page, or to retry the one that failed. Droppable: one sent while a page is in flight
/// sends nothing.
final class ResultViewLoadMoreRequested extends ResultViewEvent {
  const ResultViewLoadMoreRequested();
}
