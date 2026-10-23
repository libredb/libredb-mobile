import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The database's own words of a failed read, such as a permission refused to a read-only role or Redis's
/// `WRONGTYPE`, for a `studio.query_error`; null for any other error, whose text is never shown.
String? browseDatabaseWordsOf(AppError error) =>
    error.code == AppErrorCode.studioQueryError.key && error.message.trim().isNotEmpty ? error.message : null;

/// The database's words for a failed read or statement, in monospace and selectable, for the object browser's pages and
/// the SQL editor; never logged.
class BrowseDatabaseWords extends StatelessWidget {
  const BrowseDatabaseWords(this.words, {super.key});

  final String words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Text(S.of(context).browse_rows_database_says, style: theme.textTheme.labelMedium),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: SelectableText(
                    words,
                    key: const ValueKey('rows-database-words'),
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
