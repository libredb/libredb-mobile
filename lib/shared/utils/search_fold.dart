/// The text fold of every local search in the app, such as the connection list and the object lists.
///
/// Lower case with two letters folded by hand: U+0130 (the dotted capital I) and U+0131 (the dotless small i) both
/// become a plain `i`.
/// The dotted capital I follows Studio's tree filter (libredb-studio `src/components/object-tree/filter.ts`):
/// `toLowerCase` turns it into `i` plus a combining dot, two code units for one, so `istanbul` would not find
/// `İstanbul` and every index after the letter would be off by one for a highlight.
/// The dotless i is a deliberate superset of Studio: a Turkish keyboard types `ı` where an English name has `I`, so
/// `ılık` finds `ILIK` and `kirik` finds `Kırık`.
/// Each folded letter stays one code unit, so the folded text is exactly as long as the label and a match range is
/// valid in both.
String foldForSearch(String text) => text.replaceAll('İ', 'i').replaceAll('ı', 'i').toLowerCase();

/// The [query] as a search compares it: trimmed and folded. An empty result means 'not filtering', so whitespace
/// alone never hides a list.
String normalizeSearchQuery(String query) => foldForSearch(query.trim());

/// Whether any of [fields] holds [query], compared by [foldForSearch]; an empty query matches everything.
bool matchesSearch(String query, Iterable<String?> fields) {
  final normalized = normalizeSearchQuery(query);
  if (normalized.isEmpty) return true;
  return fields.any((field) => field != null && foldForSearch(field).contains(normalized));
}
