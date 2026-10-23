import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// Whether governance records each statement the user runs in full (the policy's `statementCapture` is `full`), for
/// every screen below it.
///
/// It answers false while the policy is not loaded or its read failed. `AppShell` in `lib/app/shell/` provides it from
/// the connection policy, so a feature such as the SQL editor reads it without importing the connections feature.
class StatementCaptureScope extends InheritedWidget {
  const StatementCaptureScope({super.key, required this.recordsInFull, required super.child});

  final bool recordsInFull;

  /// Whether the [StatementCaptureScope] above [context] records statements in full; [context] rebuilds when it
  /// changes.
  ///
  /// Throws a [FlutterError] when there is none.
  static bool recordsInFullOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StatementCaptureScope>();
    if (scope == null) {
      throw FlutterError(
        'StatementCaptureScope.recordsInFullOf() was called with a context that has no StatementCaptureScope above '
        'it.\nAppShell provides one above every signed-in screen; a test wraps the widget in a StatementCaptureScope.',
      );
    }
    return scope.recordsInFull;
  }

  @override
  bool updateShouldNotify(StatementCaptureScope oldWidget) => oldWidget.recordsInFull != recordsInFull;
}

/// "Statements you run are recorded in full in this server's query log.", as Studio's web client says it while
/// governance records statements in full; the screen that shows it decides when.
class StatementCaptureNote extends StatelessWidget {
  const StatementCaptureNote({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('connection-statement-capture-note'),
      width: double.infinity,
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.policy_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              S.of(context).connection_statement_capture_full,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
