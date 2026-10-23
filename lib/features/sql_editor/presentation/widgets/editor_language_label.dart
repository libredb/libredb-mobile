import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_language_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The small line above the field that names the engine's statement language, or says why it is unknown and the text
/// is not highlighted.
class EditorLanguageLabel extends StatelessWidget {
  const EditorLanguageLabel({super.key});

  static const labelKey = ValueKey('sql-editor-language');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return BlocBuilder<EditorLanguageCubit, EditorLanguageState>(
      builder: (context, state) => switch (state) {
        EditorLanguageLoading() => const SizedBox.shrink(),
        EditorLanguageKnown(:final language) => Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Text(
            s.sql_editor_language(language.label),
            key: labelKey,
            style: style,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        EditorLanguageUnknown(:final errorCode) => Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: Text(s.sql_editor_language_unknown(errorCode.resolve(context)), key: labelKey, style: style),
        ),
      },
    );
  }
}
