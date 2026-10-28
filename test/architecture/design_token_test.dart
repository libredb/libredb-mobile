import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/dart_code.dart';

/// Guards that a screen reaches for a token instead of a number.
///
/// `lib/features/auth/presentation/` was the only presentation directory in the repository importing no part of the
/// design system, and it held every raw `fontSize:` outside a code viewer, every `Color(0x…)` outside the theme and
/// every `circular(999)` in the app. That was not carelessness: `components/components.dart` is a barrel with 26
/// consumers and `tokens/` had none, so a screen's author never learned which tokens existed. The barrel fixed the
/// discoverability; this fixes the drift, by making a new off-token value fail rather than wait to be noticed.
///
/// Every budget below is a **ratchet**: the number of offences a file is allowed to keep while its own milestone
/// gets to it. A file may shrink its budget, never grow it, and a file with no entry gets zero. The budgets are the
/// counts measured when the guard was written, so they are a record of the debt rather than a judgement about it.
/// Deleting an entry that has reached zero is part of finishing the work it tracked.
///
/// Patterns are matched against [codeOnly], so a number inside a comment or a string is not an offence.
void main() {
  /// Where a screen is written. `lib/shared/design_system/` is skipped because it defines the tokens, and
  /// `lib/app/dev_console/` because it is a debug-only tool, as `ui_text_localized_test.dart` also skips it.
  const roots = ['lib/features/', 'lib/shared/widgets/', 'lib/app/shell/'];
  const skipped = ['lib/shared/design_system/', 'lib/app/dev_console/'];

  /// The closed spacing scale of `AppSpacing`, plus 0, which means "none" rather than a size.
  const spacingScale = {0, 4, 8, 12, 16, 24, 32, 40, 48, 64};

  /// The radii `AppRadius` defines: sm, md, lg, xl and pill.
  const radiusScale = {4, 6, 8, 12, 999};

  Map<String, String> sources() {
    final files = <String, String>{};
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        final path = file.path.replaceAll(r'\', '/');
        if (!path.endsWith('.dart') || skipped.any(path.startsWith)) continue;
        files[path] = codeOnly(file.readAsStringSync());
      }
    }
    return files;
  }

  /// Fails when a file has more offences than its budget, naming every file that is over and by how much, and every
  /// file whose budget is now too generous — a budget that outlives its debt stops being a ratchet.
  void expectWithin(String what, Map<String, int> counts, Map<String, int> budgets) {
    final over = <String>[], slack = <String>[];
    counts.forEach((path, n) {
      final budget = budgets[path] ?? 0;
      if (n > budget) over.add('$path: $n, budget $budget');
    });
    budgets.forEach((path, budget) {
      final n = counts[path] ?? 0;
      if (n < budget) slack.add('$path: $n, budget $budget — lower it');
    });
    expect(over, isEmpty, reason: '$what: a new one is not allowed\n${over.join('\n')}');
    expect(slack, isEmpty, reason: '$what: the budget no longer matches the debt\n${slack.join('\n')}');
  }

  Map<String, int> countOf(RegExp pattern, {bool Function(RegExpMatch)? offends}) {
    final counts = <String, int>{};
    sources().forEach((path, code) {
      final n = pattern.allMatches(code).where((m) => offends?.call(m) ?? true).length;
      if (n > 0) counts[path] = n;
    });
    return counts;
  }

  bool offScale(RegExpMatch match, Set<int> scale) {
    final value = double.tryParse(match.group(1)!);
    return value == null || value != value.roundToDouble() || !scale.contains(value.round());
  }

  test('a screen takes its text size from the theme, not a number', () {
    // A raw fontSize cannot follow the type scale, so it cannot follow a design system either.
    expectWithin('fontSize', countOf(RegExp(r'\bfontSize\s*:\s*[0-9]')), const {
      // M15 rewrites these; the budgets go with it. The 13 pt sizes round to the theme's 14, and the five inside
      // the wide-only brand panel are frozen by the owner's iPad ruling. #379 split login_page.dart's 8 across
      // three files without adding one: 5 + 2 + 1, and the page itself now has none.
      'lib/features/auth/presentation/widgets/login_brand_panel.dart': 5,
      'lib/features/auth/presentation/widgets/sign_in_entry.dart': 2,
      'lib/features/auth/presentation/widgets/sign_in_error_line.dart': 1,
      'lib/features/auth/presentation/widgets/community_card_grid.dart': 4,
      'lib/shared/widgets/community/community_chip_row.dart': 3,
      'lib/shared/widgets/app_version_label.dart': 1,
      // A source viewer sets the size of the code it shows. Permanent.
      'lib/features/object_browser/presentation/widgets/object_source_view.dart': 1,
    });
  });

  test('a screen takes its colours from the scheme, not a literal', () {
    expectWithin('Color(0x…)', countOf(RegExp(r'\bColor\(0x[0-9A-Fa-f]{6,8}\)')), const {
      // All 29 are in the wide-only brand chrome, which M14's handover re-colours and the owner's iPad ruling
      // freezes until then. #379 moved all 13 of login_page.dart's into the brand panel, which is that chrome and
      // nothing else — the ruling is enforceable now that no other change has to open the file holding them.
      'lib/features/auth/presentation/widgets/login_brand_panel.dart': 13,
      'lib/features/auth/presentation/widgets/community_card_grid.dart': 16,
    });
  });

  test('a gap or a padding is on the spacing scale', () {
    // SizedBox and EdgeInsets are where a layout reaches for a number; AppSpacing.* references are not literals and
    // so never match.
    //
    // The number has to *be* an argument — it follows a `:`, a `,` or a `(`. Without that the digits inside an
    // identifier count as debt: `child: Text(l10n.onboarding_skip)` inside a `SizedBox(height: …)` was read as the
    // spacing value **10**, and `_panelCount - 1` as the spacing value **1**. Neither is a gap and neither is on
    // any scale, so both were reported, and whether they were depended on something as incidental as whether an
    // earlier argument happened to close a bracket first. #284 met both at once.
    final pattern = RegExp(
      r'(?:SizedBox\s*\(\s*(?:height|width)|EdgeInsets\.(?:all|symmetric|only|fromLTRB)|spacing|runSpacing)'
      r'[^)]*?[:,(]\s*([0-9]+(?:\.[0-9]+)?)',
    );
    expectWithin('off-scale spacing', countOf(pattern, offends: (m) => offScale(m, spacingScale)), const {
      // #379 split login_page.dart's 12: 6 to the brand panel, 2 to the entry, 3 left on the page. The twelfth was
      // a duplicate the split removed, so the total went down — which is what a ratchet is for.
      'lib/features/auth/presentation/pages/login_page.dart': 3,
      'lib/features/auth/presentation/widgets/login_brand_panel.dart': 6,
      'lib/features/auth/presentation/widgets/sign_in_entry.dart': 2,
      'lib/features/auth/presentation/widgets/community_card_grid.dart': 8,
      'lib/shared/widgets/community/community_chip_row.dart': 1,
      // One each, predating the scale. They round without a layout decision, and whoever next edits the file does it.
      'lib/features/object_browser/presentation/widgets/object_tile.dart': 1,
      'lib/features/connections/presentation/widgets/connection_list_view.dart': 1,
      // connection_details_sheet.dart is gone from this list: its one entry was `Text(l10n…)` after a
      // `spacing:`, read as the number 10. Fake debt, and the ratchet only ever lets a budget shrink.
      'lib/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart': 2,
      'lib/features/sql_editor/presentation/widgets/statement_history_sheet.dart': 1,
      'lib/shared/widgets/result_view/result_notices.dart': 1,
      'lib/shared/widgets/connection_badges.dart': 1,
      'lib/shared/widgets/theme_selection_dialog.dart': 1,
    });
  });

  test('a corner radius is one AppRadius defines', () {
    final pattern = RegExp(r'BorderRadius\.circular\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)');
    expectWithin('off-scale radius', countOf(pattern, offends: (m) => offScale(m, radiusScale)), const {
      // All three were login_page.dart's and all three are the brand panel's wide-only chrome now (#379).
      'lib/features/auth/presentation/widgets/login_brand_panel.dart': 3,
      'lib/shared/widgets/theme_selection_dialog.dart': 4,
      // circular(100), the other way this app spelled a pill before AppRadius.pill existed.
      'lib/features/object_browser/presentation/widgets/key_browser_list.dart': 1,
      'lib/app/shell/top_bar/active_connection_title.dart': 1,
    });
  });

  test('a feature does not carry its own breakpoint', () {
    // A width compared against a number is a breakpoint, and breakpoints belong to AppBreakpoints: a feature that
    // keeps its own drifts from every other screen the moment the scale changes.
    final pattern = RegExp(r'\b(?:maxWidth|width)\s*[<>]=?\s*([0-9]{3,}(?:\.[0-9]+)?)');
    final counts = countOf(pattern)..removeWhere((path, _) => !path.startsWith('lib/features/'));
    expectWithin('hardcoded breakpoint', counts, const {});
  });
}
