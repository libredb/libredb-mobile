import 'package:equatable/equatable.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/query_result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/script_result.dart';

/// Whether a connection has an open transaction, and whose it is.
///
/// Without governance Studio keeps one transaction per connection for every user of it, owned by the account that
/// began it; the same account's browser and phone share it. Under governance each user has their own.
class TransactionStatus extends Equatable {
  const TransactionStatus({
    required this.inTransaction,
    required this.ownedByYou,
    required this.heldByAnotherSession,
    this.startedAt,
  });

  final bool inTransaction;
  final bool ownedByYou;
  final bool heldByAnotherSession;
  final DateTime? startedAt;

  @override
  List<Object?> get props => [inTransaction, ownedByYou, heldByAnotherSession, startedAt];
}

/// The answer to statements run inside a transaction: one [result], or a [script] for several statements.
class TransactionRun extends Equatable {
  const TransactionRun({required this.inTransaction, this.result, this.script});

  /// Whether the transaction is still open: a COMMIT, a ROLLBACK or an implicit commit in the statements ends it.
  final bool inTransaction;
  final QueryResult? result;
  final ScriptResult? script;

  @override
  List<Object?> get props => [inTransaction, result, script];
}
