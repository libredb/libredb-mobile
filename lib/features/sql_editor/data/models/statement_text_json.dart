import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_draft.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';

/// The JSON the statement text store keeps in its encrypted files.
///
/// A draft is `{text, catalog?}`. The history is `{entries: [...]}`, newest first, each entry
/// `{id, connectionId, connectionName, text, textTooLong, status, durationMs, rowCount?, executedAt}`, with `text`
/// null when `textTooLong` is true and `executedAt` in ISO 8601 UTC.
///
/// The readers throw a [FormatException] for content of another shape; its message never holds a value, since the
/// values are statement text.
final class StatementTextJson {
  const StatementTextJson._();

  static Map<String, Object?> draftToJson(StatementDraft draft) => {
    'text': draft.text,
    if (draft.catalog != null) 'catalog': draft.catalog,
  };

  static StatementDraft draft(Object? json) => switch (json) {
    {'text': final String text, 'catalog': final String? catalog} => StatementDraft(text: text, catalog: catalog),
    {'text': final String text} when !json.containsKey('catalog') => StatementDraft(text: text),
    _ => throw const FormatException('the saved draft is not {text, catalog}'),
  };

  static Map<String, Object?> historyToJson(List<StatementHistoryEntry> entries) => {
    'entries': [for (final entry in entries) _entryToJson(entry)],
  };

  static List<StatementHistoryEntry> history(Object? json) => switch (json) {
    {'entries': final List<Object?> entries} => [for (final entry in entries) _entry(entry)],
    _ => throw const FormatException('the saved history is not {entries}'),
  };

  static Map<String, Object?> _entryToJson(StatementHistoryEntry entry) => {
    'id': entry.id,
    'connectionId': entry.connectionId,
    'connectionName': entry.connectionName,
    'text': entry.text,
    'textTooLong': entry.textTooLong,
    'status': entry.status.name,
    'durationMs': entry.duration.inMilliseconds,
    if (entry.rowCount != null) 'rowCount': entry.rowCount,
    'executedAt': entry.executedAt.toUtc().toIso8601String(),
  };

  static StatementHistoryEntry _entry(Object? json) {
    if (json
        case {
          'id': final String id,
          'connectionId': final String connectionId,
          'connectionName': final String connectionName,
          'text': final String? text,
          'textTooLong': final bool textTooLong,
          'status': final String status,
          'durationMs': final int durationMs,
          'executedAt': final String executedAt,
        }
        when (text == null) == textTooLong) {
      final rowCount = json['rowCount'];
      final at = DateTime.tryParse(executedAt);
      final runStatus = StatementRunStatus.values.where((value) => value.name == status).firstOrNull;
      if (at != null && runStatus != null && (rowCount == null || rowCount is int)) {
        return StatementHistoryEntry(
          id: id,
          connectionId: connectionId,
          connectionName: connectionName,
          text: text,
          textTooLong: textTooLong,
          status: runStatus,
          duration: Duration(milliseconds: durationMs),
          rowCount: rowCount as int?,
          executedAt: at,
        );
      }
    }
    throw const FormatException('a saved history entry is not of the stored shape');
  }
}
