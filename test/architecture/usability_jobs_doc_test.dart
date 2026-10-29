import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds `docs/usability-jobs.md` to the tree and to the format beside it (the first child of #285).
///
/// That page is what a persona of M16's usage layer is started from, and it is the only thing it may ask: child 3
/// runs the jobs without an owner in the room, so a job that names a screen which no longer exists, a build file that
/// was renamed, or an environment the app does not have, stops a run that cannot ask what was meant. Each of those
/// fails quietly on the page — it still reads like an instruction.
///
/// It also has to stay the other half of `docs/usability-findings.md`: that page reads `persona`, `job`, `step` and
/// `severity` off this one ("read from: the first child of #285"), so a job with no numbered steps makes `step`
/// unwritable, a persona id the roster does not hold makes `persona` unwritable, and a severity this page invents
/// makes two personas' severities incomparable. The two pages are one format in two files, and nothing but a guard
/// notices when one of them moves.
///
/// So the page is read against disk and against its sibling, on the shape `usability_doc_test.dart` and
/// `testing_doc_test.dart` already use: a claim about the tree is checked against the tree, and the pull request that
/// moves one updates the page in the same change.
void main() {
  test('the page exists and holds jobs', () {
    expect(File(_pagePath).existsSync(), isTrue, reason: '$_pagePath is what the usage layer is started from');
    expect(readJobs(_page()), isNotEmpty, reason: 'a page of no jobs starts no persona');
  });

  test('every job block carries every key, in order, and agrees with its heading', () {
    expect(blockProblems(readJobs(_page())), isEmpty);
  });

  test('every job belongs to the roster, and every persona of the roster has two or three jobs numbered from 1', () {
    final roster = readRoster(_page());
    expect(roster, isNotEmpty, reason: 'the roster table is what `persona` is written from');

    expect(rosterProblems(readJobs(_page()), roster), isEmpty);
  });

  test('every job has at least two steps, numbered continuously from 1', () {
    expect(stepProblems(readJobs(_page())), isEmpty);
  });

  test('every screen the page names is a constant of ApplicationRoutesConstants', () {
    final declared = _declaredRouteConstants();
    expect(declared, isNotEmpty, reason: 'no route constant was read, so this guard reads nothing');

    final page = _page();
    expect(RegExp(_routeConstantPattern).allMatches(page), isNotEmpty, reason: 'a job names the screen it starts on');

    expect(unknownRouteConstants(page, declared), isEmpty);
  });

  test("every job's start and done name a screen", () {
    expect(jobsWithoutScreen(readJobs(_page())), isEmpty);
  });

  test('every environment and every session is one the app has', () {
    final environments = _enumNames('lib/infrastructure/config/environment.dart', 'Environment');
    final sessions = _enumNames('lib/shared/models/session_target.dart', 'SessionTarget');
    expect(environments, containsAll(<String>['mock', 'prod']));
    expect(sessions, containsAll(<String>['studio', 'platform']));

    final jobs = readJobs(_page());

    expect(unknownValues(jobs, 'environment', environments), isEmpty);
    expect(unknownValues(jobs, 'session', sessions), isEmpty);
  });

  test('every entry point a job builds from is a file under lib/main', () {
    final jobs = readJobs(_page());
    final targets = {for (final job in jobs) value(job, 'target')};
    expect(targets, isNotEmpty);

    final missing = [
      for (final target in targets.toList()..sort())
        if (!target.startsWith('lib/main/') || !File(target).existsSync()) target,
    ];

    expect(missing, isEmpty, reason: 'entry points that lead nowhere:\n${missing.join('\n')}');
  });

  test('every repository path the page names exists', () {
    final page = _page();
    expect(RegExp(_repoPathPattern).allMatches(page), isNotEmpty);

    final missing = missingRepoPaths(page, (path) => File(path).existsSync() || Directory(path).existsSync());

    expect(missing, isEmpty, reason: 'paths that lead nowhere:\n${missing.join('\n')}');
  });

  test('every severity the page uses is one the finding format defines', () {
    final defined = severityLevels(File(_findingsPath).readAsStringSync());
    expect(defined, equals({'S1', 'S2', 'S3', 'S4'}), reason: 'read from $_findingsPath, not written here');

    final used = RegExp(r'\bS\d\b').allMatches(_page()).map((m) => m.group(0)!).toSet();
    expect(used, isNotEmpty, reason: 'a job that names no severity leaves the run to feel one');

    expect(used.difference(defined), isEmpty);
  });

  test('the page and the finding format name each other', () {
    expect(_page(), contains(_findingsPath));
    expect(File(_findingsPath).readAsStringSync(), contains(_pagePath));
  });

  group('readJobs', () {
    test('reads the heading id, the block in order and the step numbers', () {
      final jobs = readJobs(_sample);

      expect(jobs, hasLength(1));
      expect(jobs.single.id, 'dba-on-call/1');
      expect(jobs.single.keys.map((e) => e.key), [
        'job',
        'target',
        'environment',
        'session',
        'start',
        'asks',
        'done',
        'takeaway',
      ]);
      expect(value(jobs.single, 'environment'), 'prod');
      expect(jobs.single.steps, [1, 2]);
    });

    test('does not read a block of another section as a job', () {
      const markdown = '''
## Not a job

```text
job:           nothing/9
```
''';

      expect(readJobs(markdown), isEmpty);
    });
  });

  group('blockProblems', () {
    test('names a missing key', () {
      final jobs = readJobs(_sample.replaceFirst('session:       studio\n', ''));

      expect(blockProblems(jobs), ['dba-on-call/1 — no `session:` line']);
    });

    test('names keys written out of order', () {
      final jobs = readJobs(
        _sample.replaceFirst(
          'target:        lib/main/main_prod.dart\nenvironment:   prod\n',
          'environment:   prod\ntarget:        lib/main/main_prod.dart\n',
        ),
      );

      expect(blockProblems(jobs), [
        'dba-on-call/1 — the keys are out of order: job, environment, target, session, start, asks, done, takeaway',
      ]);
    });

    test('names a block whose job id is not its heading', () {
      final jobs = readJobs(_sample.replaceFirst('job:           dba-on-call/1', 'job:           dba-on-call/2'));

      expect(blockProblems(jobs), ['dba-on-call/1 — the block says `dba-on-call/2`']);
    });
  });

  group('rosterProblems', () {
    const roster = {'dba-on-call', 'data-analyst'};

    test('names a persona the roster does not hold', () {
      final jobs = readJobs(_sample.replaceAll('dba-on-call', 'ux-designer'));

      expect(rosterProblems(jobs, roster), contains('ux-designer — not in the roster'));
    });

    test('names a persona with one job, and one with four', () {
      final one = readJobs(_sample);
      final four = readJobs([for (var n = 1; n <= 4; n++) _sampleJob('data-analyst', n)].join());

      expect(rosterProblems(one, roster), contains('dba-on-call — 1 job, and the epic asks for two or three'));
      expect(rosterProblems(four, roster), contains('data-analyst — 4 jobs, and the epic asks for two or three'));
    });

    test('names jobs that are not numbered from 1 without a gap', () {
      final jobs = readJobs(_sampleJob('data-analyst', 1) + _sampleJob('data-analyst', 3));

      expect(rosterProblems(jobs, roster), contains('data-analyst — numbered 1, 3, not 1..2'));
    });

    test('says nothing about a roster written as the epic asks', () {
      final jobs = readJobs(
        _sampleJob('dba-on-call', 1) +
            _sampleJob('dba-on-call', 2) +
            _sampleJob('data-analyst', 1) +
            _sampleJob('data-analyst', 2),
      );

      expect(rosterProblems(jobs, roster), isEmpty);
    });
  });

  group('stepProblems', () {
    test('names a job of one step', () {
      final jobs = readJobs(_sample.replaceFirst('2. Read the status line.\n', ''));

      expect(stepProblems(jobs), ['dba-on-call/1 — 1 step, and a job of one step is a tap, not a job']);
    });

    test('names steps that skip a number', () {
      final jobs = readJobs(_sample.replaceFirst('2. Read the status line.', '3. Read the status line.'));

      expect(stepProblems(jobs), ['dba-on-call/1 — steps 1, 3, not 1..2']);
    });
  });

  group('unknownRouteConstants', () {
    test('names a constant the router does not declare', () {
      const markdown = 'start: ApplicationRoutesConstants.connectionList, done: ApplicationRoutesConstants.tableList';

      expect(unknownRouteConstants(markdown, {'connectionList'}), [
        'ApplicationRoutesConstants.tableList — not declared in $_routerPath',
      ]);
    });

    test('names it once however often the page writes it', () {
      const markdown = 'ApplicationRoutesConstants.gone and ApplicationRoutesConstants.gone';

      expect(unknownRouteConstants(markdown, {'connectionList'}), hasLength(1));
    });
  });

  group('jobsWithoutScreen', () {
    test('names a job whose done cannot be opened', () {
      final jobs = readJobs(
        _sample.replaceFirst(
          'done:          The status line of ApplicationRoutesConstants.connectionList reads a latency or a failure.',
          'done:          It felt easy.',
        ),
      );

      expect(jobsWithoutScreen(jobs), ['dba-on-call/1 — `done:` names no ApplicationRoutesConstants screen']);
    });
  });

  group('missingRepoPaths', () {
    bool exists(String path) => path == 'lib/main/main_prod.dart';

    test('names a path that is not in the tree', () {
      const markdown = '`lib/main/main_prod.dart` and `lib/main/main_staging.dart`';

      expect(missingRepoPaths(markdown, exists), ['`lib/main/main_staging.dart` — not in the tree']);
    });

    test('reads only a path in backticks', () {
      const markdown = 'lib/main/main_staging.dart without backticks is prose, `lib/main/main_prod.dart` is a path';

      expect(missingRepoPaths(markdown, exists), isEmpty);
    });
  });

  group('severityLevels', () {
    test('reads the levels the finding format defines', () {
      const markdown = '| **S1** | did not finish | ... |\n| **S2** | finished | ... |';

      expect(severityLevels(markdown), {'S1', 'S2'});
    });
  });
}

const _pagePath = 'docs/usability-jobs.md';
const _findingsPath = 'docs/usability-findings.md';
const _routerPath = 'lib/app/router/app_routes_constants.dart';

/// The keys of a job block, in the order the page writes them.
const _jobKeys = ['job', 'target', 'environment', 'session', 'start', 'asks', 'done', 'takeaway'];

/// A job heading: `### <persona>/<n> — <title>`.
final _headingPattern = RegExp(r'^### ([a-z][a-z0-9-]*)/(\d+) — .+$', multiLine: true);

/// A `key: value` line of a job block.
final _keyLinePattern = RegExp(r'^([a-z_]+):\s+(\S.*)$', multiLine: true);

/// A numbered step of a job.
final _stepPattern = RegExp(r'^(\d+)\. \S', multiLine: true);

/// A screen, as the page names one.
const _routeConstantPattern = r'\bApplicationRoutesConstants\.(\w+)';

/// A path into this repository, as the page writes one inside backticks.
const _repoPathPattern = r'`((?:lib|test|docs|assets|tool|scripts)/[\w./-]+)`';

/// A severity level, as the finding format's table writes one.
const _severityPattern = r'\|\s+\*\*(S\d)\*\*\s+\|';

String _page() => File(_pagePath).readAsStringSync();

Set<String> _declaredRouteConstants() {
  final source = File(_routerPath).readAsStringSync();
  return RegExp(r'static (?:const|String|List<String>|bool) (\w+)').allMatches(source).map((m) => m.group(1)!).toSet();
}

Set<String> _enumNames(String path, String name) {
  final source = File(path).readAsStringSync();
  final body = RegExp('enum $name {([^}]*)}').firstMatch(source)?.group(1) ?? '';
  return RegExp(r'\b([a-z]\w*)\b').allMatches(body).map((m) => m.group(1)!).toSet();
}

/// One job as the page writes it.
class JobEntry {
  JobEntry({required this.id, required this.persona, required this.number, required this.keys, required this.steps});

  /// `<persona>/<n>`, from the heading.
  final String id;
  final String persona;
  final int number;

  /// The `key: value` lines of the job's block, in the order the page writes them.
  final List<MapEntry<String, String>> keys;

  /// The numbers of the job's steps, in the order the page writes them.
  final List<int> steps;
}

/// The value [job] writes for [key], or the empty string when it writes none.
String value(JobEntry job, String key) =>
    job.keys.firstWhere((e) => e.key == key, orElse: () => const MapEntry('', '')).value;

/// The personas of the roster table of [markdown]: the first column of every row whose first cell is a backticked id.
Set<String> readRoster(String markdown) {
  final table = RegExp(r'## The roster\n([\s\S]*?)\n## ').firstMatch('$markdown\n## ')?.group(1) ?? '';
  return RegExp(r'^\| `([a-z][a-z0-9-]*)` \|', multiLine: true).allMatches(table).map((m) => m.group(1)!).toSet();
}

/// The jobs of [markdown]: everything from one `### <persona>/<n>` heading to the next heading of any level.
List<JobEntry> readJobs(String markdown) {
  final headings = _headingPattern.allMatches(markdown).toList();
  final jobs = <JobEntry>[];
  for (var index = 0; index < headings.length; index++) {
    final heading = headings[index];
    final next = markdown.indexOf(RegExp(r'^#{1,3} ', multiLine: true), heading.end);
    final body = markdown.substring(heading.end, next == -1 ? markdown.length : next);
    jobs.add(
      JobEntry(
        id: '${heading.group(1)}/${heading.group(2)}',
        persona: heading.group(1)!,
        number: int.parse(heading.group(2)!),
        keys: [for (final line in _keyLinePattern.allMatches(body)) MapEntry(line.group(1)!, line.group(2)!.trim())],
        steps: [for (final step in _stepPattern.allMatches(body)) int.parse(step.group(1)!)],
      ),
    );
  }
  return jobs;
}

/// The problems of the blocks of [jobs]: a missing key, keys out of order, or a block that names another job.
List<String> blockProblems(List<JobEntry> jobs) {
  final problems = <String>[];
  for (final job in jobs) {
    final written = job.keys.map((e) => e.key).where(_jobKeys.contains).toList();
    for (final key in _jobKeys) {
      if (!written.contains(key)) problems.add('${job.id} — no `$key:` line');
    }
    final expected = _jobKeys.where(written.contains).toList();
    if (!_sameOrder(written, expected)) {
      problems.add('${job.id} — the keys are out of order: ${written.join(', ')}');
    }
    final declared = value(job, 'job');
    if (declared.isNotEmpty && declared != job.id) problems.add('${job.id} — the block says `$declared`');
  }
  return problems;
}

bool _sameOrder(List<String> a, List<String> b) => a.length == b.length && a.join() == b.join();

/// The problems of the roster of [jobs] against [roster]: an unknown persona, a persona with other than two or three
/// jobs, or jobs that are not numbered from 1 without a gap.
List<String> rosterProblems(List<JobEntry> jobs, Set<String> roster) {
  final problems = <String>[];
  final byPersona = <String, List<int>>{};
  for (final job in jobs) {
    byPersona.putIfAbsent(job.persona, () => []).add(job.number);
  }
  for (final persona in byPersona.keys.toList()..sort()) {
    final numbers = byPersona[persona]!;
    if (!roster.contains(persona)) problems.add('$persona — not in the roster');
    if (numbers.length < 2 || numbers.length > 3) {
      problems.add(
        '$persona — ${numbers.length} job${numbers.length == 1 ? '' : 's'}, and the epic asks for two or '
        'three',
      );
    }
    final wanted = [for (var n = 1; n <= numbers.length; n++) n];
    if (numbers.join(',') != wanted.join(',')) {
      problems.add('$persona — numbered ${numbers.join(', ')}, not 1..${numbers.length}');
    }
  }
  for (final persona in roster.toList()..sort()) {
    if (!byPersona.containsKey(persona)) problems.add('$persona — in the roster with no job');
  }
  return problems;
}

/// The problems of the steps of [jobs]: a job the finding format could not write a `step` into.
List<String> stepProblems(List<JobEntry> jobs) {
  final problems = <String>[];
  for (final job in jobs) {
    if (job.steps.length < 2) {
      problems.add(
        '${job.id} — ${job.steps.length} step${job.steps.length == 1 ? '' : 's'}, and a job of one step '
        'is a tap, not a job',
      );
      continue;
    }
    final wanted = [for (var n = 1; n <= job.steps.length; n++) n];
    if (job.steps.join(',') != wanted.join(',')) {
      problems.add('${job.id} — steps ${job.steps.join(', ')}, not 1..${job.steps.length}');
    }
  }
  return problems;
}

/// The `ApplicationRoutesConstants.<name>` screens [markdown] names that [declared] does not hold, each named once.
List<String> unknownRouteConstants(String markdown, Set<String> declared) {
  final named = {for (final match in RegExp(_routeConstantPattern).allMatches(markdown)) match.group(1)!};
  return [
    for (final name in named.toList()..sort())
      if (!declared.contains(name)) 'ApplicationRoutesConstants.$name — not declared in $_routerPath',
  ];
}

/// The jobs of [jobs] whose `start:` or `done:` names no screen, so a run cannot tell where to begin or when it is
/// finished without asking.
List<String> jobsWithoutScreen(List<JobEntry> jobs) {
  final pattern = RegExp(_routeConstantPattern);
  return [
    for (final job in jobs)
      for (final key in ['start', 'done'])
        if (!pattern.hasMatch(value(job, key))) '${job.id} — `$key:` names no ApplicationRoutesConstants screen',
  ];
}

/// The values [jobs] write for [key] that are not in [allowed], each named once.
List<String> unknownValues(List<JobEntry> jobs, String key, Set<String> allowed) {
  final written = {for (final job in jobs) value(job, key)};
  return [
    for (final one in written.toList()..sort())
      if (!allowed.contains(one)) '$key: $one — the app has only ${(allowed.toList()..sort()).join(', ')}',
  ];
}

/// The repository paths [markdown] names in backticks for which [exists] answers false, each named once.
List<String> missingRepoPaths(String markdown, bool Function(String path) exists) {
  final named = {for (final match in RegExp(_repoPathPattern).allMatches(markdown)) match.group(1)!};
  return [
    for (final path in named.toList()..sort())
      if (!exists(path)) '`$path` — not in the tree',
  ];
}

/// The severity levels [markdown] defines, read from the table that defines them.
Set<String> severityLevels(String markdown) =>
    RegExp(_severityPattern).allMatches(markdown).map((m) => m.group(1)!).toSet();

String _sampleJob(String persona, int number) =>
    '''
### $persona/$number — Something a person wants to know

```text
job:           $persona/$number
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.connectionList, signed in, nothing open
asks:          Whether the connection the alert named answers.
done:          The status line of ApplicationRoutesConstants.connectionList reads a latency or a failure.
takeaway:      The connection answered in so many ms, or it did not answer.
```

1. Open the connection.
2. Read the status line.

''';

final _sample = _sampleJob('dba-on-call', 1);
