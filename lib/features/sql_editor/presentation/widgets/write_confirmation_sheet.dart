import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

/// What the user answered on a [WriteConfirmationSheet].
enum WriteConfirmation { confirmed, cancelled }

/// Asks the user to confirm [text] on [connection] before it runs, for the reasons [answer] gives, in a full-height
/// modal sheet on the root navigator, which covers the shell; a dismissed sheet answers [WriteConfirmation.cancelled].
///
/// The caller sends exactly the [text] it showed here, and only on [WriteConfirmation.confirmed]. The sheet keeps
/// nothing once it closes and logs nothing.
Future<WriteConfirmation> showWriteConfirmationSheet(
  BuildContext context, {
  required StudioConnection connection,
  required String text,
  required AsksBeforeRunning answer,
}) async {
  final confirmation = await showModalBottomSheet<WriteConfirmation>(
    context: context,
    // Above the shell, so its top bar and tab bar cannot switch the connection or the tab, and close the editor that
    // waits for this answer, while the sheet is open.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => WriteConfirmationSheet(connection: connection, text: text, answer: answer),
  );
  return confirmation ?? WriteConfirmation.cancelled;
}

/// The confirmation of a statement that [InterimWriteCheck] could not clear: the connection's name and environment,
/// every reason in words, a refusal line on a connection Studio refuses writes on, and every line of the text in a
/// lazily built list, never an excerpt, so a write far down a script can be found.
///
/// On a production connection the header is in the error colour and Run stays disabled until the user types the
/// connection's name, compared exactly as Studio's typed confirmation compares it (`src/components/typed-confirm.tsx`
/// at libredb-studio c9989a6b5): no trimming, no case folding, an empty field never matches, and a connection without
/// a name (or one of only white space) shows a sentence in place of the field and keeps Run disabled. That step is the
/// phone's own, for every confirmation on a production connection.
class WriteConfirmationSheet extends StatefulWidget {
  const WriteConfirmationSheet({super.key, required this.connection, required this.text, required this.answer});

  final StudioConnection connection;
  final String text;
  final AsksBeforeRunning answer;

  static const nameFieldKey = ValueKey('write_confirmation_name_field');
  static const linesKey = ValueKey('write_confirmation_lines');

  @override
  State<WriteConfirmationSheet> createState() => _WriteConfirmationSheetState();
}

class _WriteConfirmationSheetState extends State<WriteConfirmationSheet> {
  final _typedName = TextEditingController();
  late final List<String> _lines = statementLines(widget.text);

  bool get _isProduction => widget.connection.environment == StudioEnvironment.production;

  /// Whether the connection has a name to type; a name of only white space is none, as an empty one is.
  bool get _hasName => widget.connection.name.trim().isNotEmpty;

  bool get _canRun => !_isProduction || (_hasName && _typedName.text == widget.connection.name);

  @override
  void dispose() {
    _typedName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connection = widget.connection;
    final headerColor = _isProduction ? scheme.error : scheme.onSurface;
    final environment = connection.environment;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Row(
              spacing: AppSpacing.sm,
              children: [
                Icon(Icons.warning_amber_rounded, color: headerColor),
                Expanded(
                  child: Text(s.write_confirm_title, style: theme.textTheme.titleLarge?.copyWith(color: headerColor)),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_hasName) Text(connection.name, style: theme.textTheme.titleSmall),
                if (EnvironmentBadge.showsFor(environment))
                  EnvironmentBadge(environment: environment!, color: connection.color),
              ],
            ),
            for (final reason in WriteCheckReason.values)
              if (widget.answer.reasons.contains(reason))
                _Line(icon: Icons.error_outline, text: _reasonText(s, reason)),
            if (connection.readOnlyForUser) ...[
              if (connection.access == StudioAccess.read)
                _Line(icon: Icons.lock_outline, text: s.write_confirm_read_grant),
              if (connection.readOnly) _Line(icon: Icons.lock_outline, text: s.write_confirm_read_only_connection),
            ],
            Text(s.write_confirm_text_heading, style: theme.textTheme.labelLarge),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    key: WriteConfirmationSheet.linesKey,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) => _StatementLine(
                      number: index + 1,
                      digits: '${_lines.length}'.length,
                      text: _lines[index],
                      flagged: widget.answer.flaggedWord?.line == index + 1,
                    ),
                  ),
                ),
              ),
            ),
            if (_isProduction) ...[
              Text(s.write_confirm_production_prompt, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
              if (!_hasName)
                Text(s.write_confirm_no_name, style: theme.textTheme.bodyMedium)
              else
                TextField(
                  key: WriteConfirmationSheet.nameFieldKey,
                  controller: _typedName,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  textCapitalization: TextCapitalization.none,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(labelText: s.write_confirm_name_label(connection.name)),
                  onChanged: (_) => setState(() {}),
                ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(WriteConfirmation.cancelled),
                  child: Text(s.write_confirm_cancel),
                ),
                FilledButton(
                  style: _isProduction
                      ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError)
                      : null,
                  onPressed: _canRun ? () => Navigator.of(context).pop(WriteConfirmation.confirmed) : null,
                  child: Text(s.write_confirm_run),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _reasonText(S s, WriteCheckReason reason) => switch (reason) {
    WriteCheckReason.mayWrite => switch (widget.answer.flaggedWord) {
      FlaggedWord(:final word, :final line) => s.write_confirm_reason_may_write_at(word, line),
      null => s.write_confirm_reason_may_write,
    },
    WriteCheckReason.severalStatements => s.write_confirm_reason_several,
    WriteCheckReason.notSql => s.write_confirm_reason_not_sql,
  };
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpacing.sm,
    children: [
      Icon(icon, size: 20),
      Expanded(child: Text(text)),
    ],
  );
}

/// One line of the confirmed text with its number; the flagged line is marked so it can be found.
class _StatementLine extends StatelessWidget {
  const _StatementLine({required this.number, required this.digits, required this.text, required this.flagged});

  final int number;
  final int digits;
  final String text;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return ColoredBox(
      color: flagged ? scheme.errorContainer : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Text(
            '$number'.padLeft(digits),
            style: style?.copyWith(color: flagged ? scheme.onErrorContainer : scheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(text, style: flagged ? style?.copyWith(color: scheme.onErrorContainer) : style),
          ),
        ],
      ),
    );
  }
}
