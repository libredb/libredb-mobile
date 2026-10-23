import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/features/object_browser/application/row_count_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/preview_statement_generator.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// 'Count rows' for the [RowCountBloc] above it: runs [statement] once per tap, and is disabled while a count runs or
/// while [enabled] is false, which the heading's `OnlineOnlyAction` passes offline.
class CountRowsButton extends StatelessWidget {
  const CountRowsButton({super.key, required this.statement, required this.enabled});

  final PreviewStatement statement;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final running = context.select((RowCountBloc bloc) => bloc.state is RowCountRunning);
    return TextButton(
      onPressed: enabled && !running ? () => context.read<RowCountBloc>().add(RowCountRequested(statement)) : null,
      child: Text(S.of(context).browse_count_rows),
    );
  }
}

/// The row count of the [RowCountBloc] above it, as one line under a heading: the count grouped in the user's locale,
/// a progress bar while it runs, or, for a refused count, that it could not be loaded, with the error code.
class RowCountLine extends StatelessWidget {
  const RowCountLine({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    String rows(int count) => s.browse_object_rows(count, number.format(count));
    return BlocBuilder<RowCountBloc, RowCountState>(
      builder: (context, state) {
        final (text, isError) = switch (state) {
          RowCountIdle() || RowCountRunning(previous: null) => (null, false),
          RowCountRunning(:final previous?) => (rows(previous), false),
          RowCountLoaded(:final count) => (rows(count), false),
          RowCountFailure(:final error) => (s.browse_count_failed(error.code ?? error.runtimeType.toString()), true),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state is RowCountRunning) const LinearProgressIndicator(),
              if (text != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    text,
                    key: const ValueKey('row-count-line'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
