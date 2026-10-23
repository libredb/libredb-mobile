// A port of the card list's field choice in Studio's grid (`detectPrimaryColumn` and `detectIdColumn` in
// `src/components/ResultsGrid.tsx:211-236`, and the preview fields of `src/components/results-grid/ResultCard.tsx:49`,
// at libredb-studio c9989a6b5).
//
// The title is found by name and never from a table's keys: a SELECT-only role gets no primary keys from describe on
// Postgres, and a statement's result has no catalog entry at all.

const _preferredWords = ['name', 'title', 'label', 'username', 'email', 'description'];

/// The field a card shows as its title: the first field whose lowercased name contains `name`, `title`, `label`,
/// `username`, `email` or `description`, tried in that order; else the first field whose value in the first row is a
/// string and whose name does not contain `id`; else the first field. Null when there is no field.
///
/// The view reads the masked rows it holds, so a masked field with a value counts as a string; Studio reads the clear
/// rows, which may choose another title for a masked column whose clear value is a number. Either title shows only
/// what the card shows.
String? primaryField(List<String> fields, List<Map<String, Object?>> rows) {
  for (final word in _preferredWords) {
    for (final field in fields) {
      if (field.toLowerCase().contains(word)) return field;
    }
  }
  if (rows.isNotEmpty) {
    for (final field in fields) {
      if (rows.first[field] is String && !field.toLowerCase().contains('id')) return field;
    }
  }
  return fields.isEmpty ? null : fields.first;
}

/// The field a card shows under its title: the first named `id` or ending in `_id`, ignoring case; null when there is
/// none.
String? idField(List<String> fields) {
  for (final field in fields) {
    final lower = field.toLowerCase();
    if (lower == 'id' || lower.endsWith('_id')) return field;
  }
  return null;
}

/// The most fields a card previews.
const maxPreviewFields = 4;

/// The fields a card previews: the first [maxPreviewFields] of [fields] other than [primary] and [id].
List<String> previewFields(List<String> fields, {required String? primary, required String? id}) =>
    fields.where((field) => field != primary && field != id).take(maxPreviewFields).toList();
