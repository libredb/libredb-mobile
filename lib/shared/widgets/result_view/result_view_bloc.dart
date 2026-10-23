import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';

part 'result_view_event.dart';
part 'result_view_state.dart';

/// One statement's result on screen, shared by the object browser's row preview and the SQL editor.
///
/// It takes a result its caller already masked, with the [policy] the caller masked it with, and holds no clear row.
/// The caller builds the policy from the role `StudioRoleScope` answers and its connection's exemption; the view never
/// reads the scope itself, and masks each later page with this same [policy].
class ResultViewBloc extends Bloc<ResultViewEvent, ResultViewState> {
  ResultViewBloc({required MaskedResult masked, required this.policy})
    : super(ResultViewLoaded(result: masked.result, maskedColumns: masked.maskedColumns)) {
    on<ResultViewReplaced>(_onReplaced);
  }

  /// The policy the result was masked with, for every later page of it.
  final MaskingPolicy policy;

  void _onReplaced(ResultViewReplaced event, Emitter<ResultViewState> emit) {
    final next = ResultViewLoaded(result: event.masked.result, maskedColumns: event.masked.maskedColumns);
    // Bloc emits a state equal to its first one, which it never compared; the same result needs no rebuild.
    if (next != state) emit(next);
  }
}
