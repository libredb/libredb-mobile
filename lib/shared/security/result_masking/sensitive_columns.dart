import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/security/result_masking/mask_functions.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_config.dart';

// A port of Studio's column detection and row masking (`detectSensitiveColumnsFromConfig` and `applyMaskingToRows` in
// `src/lib/data-masking.ts:205-264`, `numberedRepeatBase` in `src/lib/db/utils/result-fields.ts:64-74` and
// `splitMaskedColumns` in `src/lib/db/masking-exemption.ts:26-60`, at libredb-studio c9989a6b5). Detection reads column
// names only, as Studio's does.

final _log = AppLogger.getLogger('ResultMasking');

final _numberedRepeat = RegExp(r'^(.*) \(\d+\)$');

/// The name a numbered name `name (N)` repeats, read once (`a (2) (2)` gives `a (2)`), or null for a name not of that
/// form: Studio numbers a repeated column of a result that way.
String? numberedRepeatBase(String name) => _numberedRepeat.firstMatch(name)?.group(1);

/// [field] and every name it may repeat, so `email (2)` is matched as `email` too.
List<String> _namesToMatch(String field) => [
  field,
  for (var base = numberedRepeatBase(field); base != null; base = numberedRepeatBase(base)) base,
];

final _columnPatterns = <String, RegExp?>{};

/// Whether [columnPattern] matches the whole of [name], ignoring case; a pattern Dart cannot compile is compared as
/// text, ignoring case, as Studio does with one JavaScript cannot compile.
bool _matches(String columnPattern, String name) {
  final regExp = _columnPatterns.putIfAbsent(columnPattern, () {
    try {
      return RegExp('^$columnPattern\$', caseSensitive: false);
    } on FormatException {
      return null;
    }
  });
  return regExp?.hasMatch(name) ?? columnPattern.toLowerCase() == name.toLowerCase();
}

/// The fields of [fields] an enabled rule of [config] matches, each with the first rule that matches it, in the order
/// of [fields] (Studio's `detectSensitiveColumnsFromConfig`).
Map<String, MaskingPattern> detectSensitiveColumns(List<String> fields, MaskingConfig config) {
  final enabled = config.patterns.where((p) => p.enabled).toList();
  final sensitive = <String, MaskingPattern>{};
  for (final field in fields) {
    final names = _namesToMatch(field);
    for (final pattern in enabled) {
      if (pattern.columnPatterns.any((cp) => names.any((name) => _matches(cp, name)))) {
        sensitive[field] = pattern;
        break;
      }
    }
  }
  return sensitive;
}

final _exemptPatterns = <String, RegExp?>{};

/// The columns of [fields] still masked once the engine's [declared] exemption is applied, and the exempted ones with
/// the reason for each (Studio's `splitMaskedColumns`). An exemption only takes a column out, it never adds one.
///
/// Studio compiles the exemption as is, unanchored and case-sensitive (`new RegExp(declared.column)`). A pattern Dart
/// cannot compile exempts nothing, the safe direction, and writes one warning per distinct pattern in the run, naming
/// the pattern.
({Map<String, MaskingPattern> masked, Map<String, String> exempt}) splitMaskedColumns(
  List<String> fields,
  MaskingConfig config,
  MaskingExemptColumn? declared,
) {
  final detected = detectSensitiveColumns(fields, config);
  if (declared == null) return (masked: detected, exempt: const {});
  final regExp = _exemptPatterns.putIfAbsent(declared.column, () {
    try {
      return RegExp(declared.column);
    } on FormatException {
      _log.warn('Studio sent a masking exemption Dart cannot compile, so it exempts no column: {}', [declared.column]);
      return null;
    }
  });
  if (regExp == null) return (masked: detected, exempt: const {});
  final exempt = {
    for (final field in fields)
      if (regExp.hasMatch(field)) field: declared.reason,
  };
  final masked = {
    for (final entry in detected.entries)
      if (!exempt.containsKey(entry.key)) entry.key: entry.value,
  };
  return (masked: masked, exempt: exempt);
}

/// [rows] with the value of each column of [sensitive] masked by its rule, as JavaScript's `String` prints it; a null
/// or absent value stays as it was, and [rows] itself is not changed (Studio's `applyMaskingToRows`). With no sensitive
/// column the answer is [rows] itself.
List<Map<String, Object?>> applyMaskingToRows(
  List<Map<String, Object?>> rows,
  List<String> fields,
  Map<String, MaskingPattern> sensitive,
) {
  if (sensitive.isEmpty) return rows;
  final masked = {for (final field in fields) field: ?sensitive[field]};
  return [
    for (final row in rows)
      {
        for (final MapEntry(:key, :value) in row.entries)
          key: switch ((masked[key], value)) {
            (final MaskingPattern pattern, final Object value) => maskByType(jsString(value), pattern),
            _ => value,
          },
      },
  ];
}
