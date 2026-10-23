import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';

/// Gives the signed-in screens below it a [StatementCaptureScope] from the policy [ConnectionPolicyCubit] holds:
/// whether governance records each statement in full, and false before the policy loaded and after a failed read.
class AppStatementCaptureScope extends StatelessWidget {
  const AppStatementCaptureScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ConnectionPolicyCubit, ConnectionPolicyState, bool>(
      selector: (state) => switch (state) {
        ConnectionPolicyLoaded(:final policy) => policy.statementCapture == ConnectionPolicy.statementCaptureFull,
        ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
      },
      builder: (context, recordsInFull) => StatementCaptureScope(recordsInFull: recordsInFull, child: child),
    );
  }
}
