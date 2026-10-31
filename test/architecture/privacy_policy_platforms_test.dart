import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that the privacy policy covers both platforms the app ships on (issue #199).
///
/// The policy is one document, published at one URL, and both stores point a reader at it: Google Play through the
/// Data safety form and App Store Connect through App Privacy. A reader on either platform has to find their own
/// device described there, and App Review reads the same URL under Guideline 5.1.1.
///
/// The app's behaviour genuinely differs between the two, so a policy written for one is wrong for the other rather
/// than merely thin. Tokens sit in the Android Keystore on one and in the Keychain on the other; Android's cloud
/// backup is turned off for the app, while iOS keeps the default, so a backup may hold the files but never the key
/// ([`docs/security.md`](../../docs/security.md), "What a backup can carry").
///
/// Each rule below is a pair: when the policy says the first thing, it has to say the second as well. That is
/// narrower than "mention iOS somewhere" and catches the real failure, which is a paragraph that answers the
/// question for one platform and leaves the other reader with someone else's answer.
void main() {
  test('every platform-specific passage answers for both platforms, in both languages', () {
    final problems = [
      for (final MapEntry(key: path, value: rules) in _rules.entries) ...policyProblems(File(path), rules),
    ];

    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('policyProblems', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('privacy_policy_'));
    tearDown(() => temp.deleteSync(recursive: true));

    File write(String text) => File('${temp.path}/policy.md')..writeAsStringSync(text);

    test('accepts a policy that answers for both platforms', () {
      final file = write('Tokens sit in the Android Keystore, and in the iOS Keychain.');

      expect(policyProblems(file, const [('Android Keystore', 'Keychain')]), isEmpty);
    });

    test('names the passage that answers for one platform only', () {
      final file = write('Tokens sit in the Android Keystore.');

      expect(policyProblems(file, const [('Android Keystore', 'Keychain')]), [
        '${file.path} says "Android Keystore" but never "Keychain", so it answers for one platform only',
      ]);
    });

    test('says nothing about a rule whose first phrase is absent', () {
      final file = write('The app keeps no rows of query results after it closes.');

      expect(policyProblems(file, const [('Android Keystore', 'Keychain')]), isEmpty);
    });
  });
}

/// For each locale of the policy, the pairs it must keep: saying the first phrase obliges it to say the second.
const _rules = {
  'docs/privacy-policy.md': [('Google Play', 'App Store'), ('Android Keystore', 'Keychain'), ('cloud backup', 'iOS')],
  'docs/privacy-policy.tr.md': [('Google Play', 'App Store'), ('Android Keystore', 'Keychain'), ('yedek', 'iOS')],
};

/// The problems of [policy] against [rules]: a passage that answers for one platform and leaves the other reader out.
List<String> policyProblems(File policy, List<(String, String)> rules) {
  if (!policy.existsSync()) return ['${policy.path} is missing'];
  final text = policy.readAsStringSync();
  return [
    for (final (said, owed) in rules)
      if (text.contains(said) && !text.contains(owed))
        '${policy.path} says "$said" but never "$owed", so it answers for one platform only',
  ];
}
