/// Derives the adoption figures the onboarding shows from the JSON Lines series of `libredb/libredb-adoption`.
///
/// It lives under `tool/` rather than `lib/` because the app never runs it: `scripts/generate_adoption.sh` runs it at
/// build time and commits its output, so nothing here ships in the binary.
///
/// Every function takes the file's whole contents, because two of the three answers cannot be read from a single
/// line: a series holds several metrics at once, and the count of vendor sites is the number of distinct metric
/// names, which no line stores.
library;

import 'dart:convert';

/// The newest value of [metric] in [series], or null when the series holds no measurement of it.
///
/// "Newest" is by `date`, then by `measured_at`, because a date repeats: `channels.total` was measured twice on
/// 2026-10-21, at 05:06 and 21:00, with different values. Neither the first nor the last line of a file is reliable,
/// so the whole series is read.
///
/// A line that is blank or not an object with the fields this needs is skipped: these files gain metrics over time,
/// and one unreadable line should not lose the figure.
int? newestValueOf(String series, String metric) {
  Map<String, dynamic>? newest;
  for (final line in const LineSplitter().convert(series)) {
    final row = _rowOf(line);
    if (row == null || row['metric'] != metric) continue;
    if (row['value'] is! int) continue;
    if (newest == null || _isNewer(row, newest)) newest = row;
  }
  return newest?['value'] as int?;
}

/// How many distinct metric names in [series] start with [prefix].
///
/// This is how the vendor-site count is read: `listings.jsonl` names one metric per site
/// (`listings.postgresql-software-catalogue` and so on) and stores the count nowhere, so the file is parsed in full
/// and the names are counted. A site measured many times still counts once.
int distinctMetricCount(String series, String prefix) {
  final names = <String>{};
  for (final line in const LineSplitter().convert(series)) {
    final metric = _rowOf(line)?['metric'];
    if (metric is String && metric.startsWith(prefix)) names.add(metric);
  }
  return names.length;
}

/// The three figures the onboarding shows, from the three series.
///
/// Throws [StateError] naming the metric when one of them has no measurement. The app falls back when its asset is
/// unreadable, but the script must not write a figure it could not read: a missing metric would reach the user as
/// "0 engines", which is worse than showing yesterday's committed numbers.
Map<String, int> adoptionFiguresFrom({required String engines, required String channels, required String listings}) {
  final shipped = newestValueOf(engines, enginesMetric);
  if (shipped == null) throw StateError('$enginesMetric has no measurement in the engines series');
  final total = newestValueOf(channels, channelsMetric);
  if (total == null) throw StateError('$channelsMetric has no measurement in the channels series');
  final sites = distinctMetricCount(listings, listingsPrefix);
  if (sites == 0) throw StateError('the listings series names no metric under "$listingsPrefix"');
  return {'engines': shipped, 'channels': total, 'listings': sites};
}

/// The database engines LibreDB ships support for.
const String enginesMetric = 'engines.shipped';

/// The channels LibreDB is published on.
const String channelsMetric = 'channels.total';

/// The prefix of the per-site metrics that together give the count of official vendor and project listings.
const String listingsPrefix = 'listings.';

/// Whether [row] was measured after [other]: later `date`, or the same `date` and a later `measured_at`.
bool _isNewer(Map<String, dynamic> row, Map<String, dynamic> other) {
  final byDate = '${row['date']}'.compareTo('${other['date']}');
  if (byDate != 0) return byDate > 0;
  return '${row['measured_at']}'.compareTo('${other['measured_at']}') > 0;
}

/// [line] as a row, or null when it is blank or not a JSON object.
Map<String, dynamic>? _rowOf(String line) {
  if (line.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(line);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
