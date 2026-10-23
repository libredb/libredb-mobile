import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/utils/event_transformers.dart';

part 'result_view_event.dart';
part 'result_view_state.dart';

/// Runs the caller's statement again for [page] and answers its result, clear; the caller holds the statement, its
/// catalog and its connection, so the view never holds statement text.
typedef ResultPageLoader = Future<Result<QueryResult>> Function(QueryPage page);

/// One statement's result on screen, shared by the object browser's row preview and the SQL editor.
///
/// It takes a result its caller already masked, with the [policy] the caller masked it with, and holds no clear row.
/// The caller builds the policy from the role `StudioRoleScope` answers and its connection's exemption; the view never
/// reads the scope itself, and masks each later page with this same [policy].
///
/// Load more fetches the next page through [loadPage] only when Studio's grid would offer it ([pageOffer]); a failed
/// page is never retried by the bloc, since a page runs the statement again, only by the user's next request.
class ResultViewBloc extends Bloc<ResultViewEvent, ResultViewState> {
  ResultViewBloc({
    required MaskedResult masked,
    required this.policy,
    this.loadPage,
    this.supportsResultPagination = false,
    this.hasOuterOrderBy,
  }) : super(ResultViewLoaded(result: masked.result, maskedColumns: masked.maskedColumns)) {
    on<ResultViewReplaced>(_onReplaced);
    on<ResultViewLoadMoreRequested>(_onLoadMore, transformer: EventTransformers.dropConcurrent());
  }

  /// The policy the result was masked with, for every later page of it.
  final MaskingPolicy policy;

  /// Fetches a later page; without it nothing is offered.
  final ResultPageLoader? loadPage;

  /// The caller's `ProviderMeta.supportsResultPagination`: whether the engine really applies an offset.
  final bool supportsResultPagination;

  /// Whether the caller's statement has an outer ORDER BY; null when the caller cannot tell.
  final bool? hasOuterOrderBy;

  /// Counts the results the caller replaced, so a page fetched for one of them is never appended to the next.
  int _generation = 0;

  /// The size of the next page Load more fetches for [result], the page size already on screen, or null when nothing
  /// is offered: as Studio's `pageOfferFor` (`src/components/results-grid/page-offer.ts:27-36`), the engine pages,
  /// Studio says another page exists, and the caller gave a [loadPage].
  int? pageOffer(QueryResult result) {
    final pagination = result.pagination;
    if (!supportsResultPagination || pagination == null || !pagination.hasMore || loadPage == null) return null;
    return pagination.limit;
  }

  /// Whether to say that rows may repeat or be skipped between pages: only with an offer and a statement known to have
  /// no outer ORDER BY, as Studio says it (`ResultsGrid.tsx:1320-1321`); an unknown statement makes no claim.
  bool showsOrderNotice(QueryResult result) => pageOffer(result) != null && hasOuterOrderBy == false;

  void _onReplaced(ResultViewReplaced event, Emitter<ResultViewState> emit) {
    _generation++;
    final next = ResultViewLoaded(result: event.masked.result, maskedColumns: event.masked.maskedColumns);
    // Bloc emits a state equal to its first one, which it never compared; the same result needs no rebuild.
    if (next != state) emit(next);
  }

  Future<void> _onLoadMore(ResultViewLoadMoreRequested event, Emitter<ResultViewState> emit) async {
    final (shown, maskedColumns) = switch (state) {
      ResultViewLoaded(:final result, :final maskedColumns) => (result, maskedColumns),
      ResultViewLoadMoreFailed(:final result, :final maskedColumns) => (result, maskedColumns),
    };
    final loadPage = this.loadPage;
    if (pageOffer(shown) == null || loadPage == null) return;
    final generation = _generation;
    emit(ResultViewLoaded(result: shown, maskedColumns: maskedColumns, loadingMore: true));
    final answer = await loadPage(QueryPage.after(shown.pagination!));
    if (generation != _generation) return;
    switch (answer) {
      case Success(:final data):
        final page = maskResult(data, policy);
        emit(
          ResultViewLoaded(
            result: appendResultPage(shown, page.result),
            maskedColumns: {...maskedColumns, ...page.maskedColumns},
          ),
        );
      case Failure(:final error):
        emit(ResultViewLoadMoreFailed(result: shown, maskedColumns: maskedColumns, error: error));
    }
  }
}
