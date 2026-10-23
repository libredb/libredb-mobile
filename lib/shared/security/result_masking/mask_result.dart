import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/security/result_masking/sensitive_columns.dart';

/// A result with its sensitive values masked, and the columns that were.
class MaskedResult extends Equatable {
  const MaskedResult({required this.result, required this.maskedColumns});

  /// The result with the values of [maskedColumns] replaced by their masks.
  final QueryResult result;

  /// The columns whose values are masked.
  final Set<String> maskedColumns;

  @override
  List<Object?> get props => [result, maskedColumns];
}

/// [result] masked by [policy], as Studio's grid masks it: each column a default rule matches by name, less the
/// column the connection's engine exempts, has every value that is not NULL replaced by its mask.
///
/// The masked result replaces the clear one: the caller keeps no state, bloc, cache or log of [result]'s rows, which
/// are not changed. A result with no masked column comes back as it was.
MaskedResult maskResult(QueryResult result, MaskingPolicy policy) {
  if (!policy.masks) return MaskedResult(result: result, maskedColumns: const {});
  final masked = splitMaskedColumns(result.fields, policy.config, policy.exempt).masked;
  if (masked.isEmpty) return MaskedResult(result: result, maskedColumns: const {});
  return MaskedResult(
    result: QueryResult(
      fields: result.fields,
      rows: applyMaskingToRows(result.rows, result.fields, masked),
      rowCount: result.rowCount,
      executionTime: result.executionTime,
      columnTypes: result.columnTypes,
      warnings: result.warnings,
      pagination: result.pagination,
      openTransactionRolledBack: result.openTransactionRolledBack,
      vectorColumns: result.vectorColumns,
    ),
    maskedColumns: masked.keys.toSet(),
  );
}
