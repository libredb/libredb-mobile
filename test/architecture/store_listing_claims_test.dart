import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the three store-listing claims a reader could buy the app for, against what the code measurably does.
///
/// The listing texts live in six places that must agree: the live Play listing
/// (`android/fastlane/metadata/android/<locale>/full_description.txt`), every Play draft
/// (`android/fastlane/drafts/<feature>/<locale>/full_description.txt`) and the App Store listing
/// (`ios/fastlane/metadata/<locale>/description.txt`). A sentence corrected in one and forgotten in another is the
/// failure this test exists to catch, so each claim is checked in every file and in both languages.
///
/// What each claim had to become, and why:
///
/// - **Cancel.** `EditorRunBloc._onCancelRequested` (`lib/features/sql_editor/application/editor_run_bloc.dart:264`)
///   branches on the engine: with `ProviderMeta.supportsQueryCancel` it posts `cancel` to Studio, and without it the
///   app only drops its own request (`EditorCancelOutcome.stoppedWaiting`) while the statement runs on. The app says
///   so itself in `sql_editor_stopped_waiting`, so the listing must not promise the cancel flatly.
/// - **The confirmation.** The check is a keyword scan whose limits `docs/security.md:372-376` records: it "reads
///   words, not what a user-defined function or procedure ... does when an allowed statement calls it", so
///   `SELECT my_func(1)` reaches the database with no sheet, and on a production connection without the typed name.
/// - **Masking.** `docs/security.md:295-299` records that three of Studio's mask functions have open bugs the port
///   does not copy, pinned by `test/shared/security/result_masking/data_masking_test.dart:109-141`: a token or key,
///   an email with an empty local part or domain, and a date that is not a bare `YYYY-MM-DD` value are masked
///   further on the phone than in Studio's grid. Which columns are masked still follows Studio's defaults.
void main() {
  test('every listing states the three claims as the code measures them', () {
    final texts = _listingTexts();
    expect(texts, isNotEmpty, reason: 'no listing description was found');

    final problems = <String>[];
    for (final MapEntry(key: path, value: language) in texts.entries) {
      final text = File(path).readAsStringSync();
      for (final claim in _claims) {
        for (final phrase in claim.overstated[language]!) {
          if (text.contains(phrase)) problems.add('$path overstates ${claim.name}: "$phrase"');
        }
        for (final phrase in claim.measured[language]!) {
          if (!text.contains(phrase)) problems.add('$path does not say what ${claim.name} does: "$phrase" is missing');
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

/// One claim, with the wording that overstates it and the wording that matches the measurement, per language.
class _Claim {
  const _Claim({required this.name, required this.overstated, required this.measured});

  final String name;
  final Map<String, List<String>> overstated;
  final Map<String, List<String>> measured;
}

const _claims = [
  _Claim(
    name: 'cancelling a running statement',
    overstated: {
      'en': ['and cancel a statement that is running'],
      'tr': ['çalışan bir deyimi iptal edin'],
    },
    measured: {
      'en': ['keeps running on the server'],
      'tr': ['sunucuda çalışmaya devam eder'],
    },
  ),
  _Claim(
    name: 'the confirmation before a write',
    overstated: {
      'en': ['Before a statement that may change data runs, the app shows it in full and asks you to confirm'],
      'tr': ['Veriyi değiştirebilecek bir deyim çalışmadan önce uygulama onu eksiksiz gösterir'],
    },
    measured: {
      'en': ["The check reads the statement's words"],
      'tr': ['Denetim deyimin sözcüklerini okur'],
    },
  ),
  _Claim(
    name: 'result masking',
    overstated: {
      'en': ['the same default rules as Studio'],
      'tr': ["Studio'nun web tablosundaki varsayılan kurallarla"],
    },
    measured: {
      'en': ['hides more than Studio'],
      'tr': ['daha fazlasını gizler'],
    },
  ),
];

/// Every listing description, as a map of path to the language its locale directory is written in.
Map<String, String> _listingTexts() {
  final texts = <String, String>{};
  void add(Directory locales, String file) {
    if (!locales.existsSync()) return;
    for (final locale in locales.listSync().whereType<Directory>()) {
      final path = '${locale.path}/$file';
      if (File(path).existsSync()) texts[path] = _name(locale.path).startsWith('tr') ? 'tr' : 'en';
    }
  }

  add(Directory('android/fastlane/metadata/android'), 'full_description.txt');
  final drafts = Directory('android/fastlane/drafts');
  if (drafts.existsSync()) {
    for (final draft in drafts.listSync().whereType<Directory>()) {
      add(draft, 'full_description.txt');
    }
  }
  add(Directory('ios/fastlane/metadata'), 'description.txt');
  return texts;
}

String _name(String path) => path.replaceAll('\\', '/').split('/').last;
