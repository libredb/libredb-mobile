import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards CLAUDE.md's "Default to `Bloc` for any new feature touching network requests" against the feature `Cubit`s
/// that hold a repository.
///
/// The rule lets a `Cubit` stand only where "every interaction is an atomic, fire-and-forget call and the event stream
/// adds no value (no debouncing, no concurrency policy ...)". Four feature `Cubit`s hold a repository, and three of
/// them do carry a concurrency policy — written by hand, as a `_generation` counter and an in-flight flag. That is a
/// contradiction a reader hits with nothing to read, so this guard makes each of them answer it in its own class doc,
/// on the line `EditorLanguageCubit` already wrote for itself:
///
/// ```dart
/// /// A Cubit, not a Bloc: one cached read when the editor opens, with nothing to debounce, drop or replay.
/// ```
///
/// The set below is the whole of what may hold a repository without being a `Bloc`. A new one fails here, which is
/// where the default is meant to bite — before the Cubit is written, not after its tests exist.
///
/// What this reads is a heuristic: a field whose type is an `I...Repository`, `...Client`, `...Gateway` or `...Api`.
/// A collaborator named outside that shape slips past, as it does in every guard here that reads source rather than
/// behaviour. It catches the shape this codebase actually writes.
void main() {
  /// Why each of these is a `Cubit` and not a `Bloc` belongs in the file itself; this set only says which files have
  /// answered for it.
  const justified = {
    'lib/features/auth/application/studio_identity_cubit.dart',
    'lib/features/auth/application/platform_identity_cubit.dart',
    'lib/features/connections/application/connection_policy_cubit.dart',
    'lib/features/connections/application/collapsed_sections_cubit.dart',
    'lib/features/sql_editor/application/editor_language_cubit.dart',
  };

  const justification = 'A Cubit, not a Bloc:';

  final collaborator = RegExp(
    r'^\s*(?:late\s+)?final\s+I\w*(?:Repository|Client|Gateway|Api)\s+_\w+;',
    multiLine: true,
  );

  List<String> cubitsHoldingACollaborator() =>
      Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => (_relative(f.path), f.readAsStringSync()))
          .where((e) => e.$2.contains('extends Cubit<') && collaborator.hasMatch(e.$2))
          .map((e) => e.$1)
          .toList();

  test('every feature Cubit that holds a repository is one this guard knows about', () {
    final unexpected = cubitsHoldingACollaborator().where((p) => !justified.contains(p)).toList()..sort();

    expect(
      unexpected,
      isEmpty,
      reason:
          'A new feature that calls a server gets a Bloc, whose EventTransformer gives the concurrency policy that a '
          'Cubit has to write by hand (CLAUDE.md, "`Bloc` vs `Cubit`"). If this one truly has nothing to debounce, '
          'drop or replay, say so in its class doc on a "$justification" line and name it in this guard:\n'
          '${unexpected.join('\n')}',
    );
  });

  test('the set this guard knows about names files that exist', () {
    final missing = justified.where((p) => !File(p).existsSync()).toList()..sort();

    expect(missing, isEmpty, reason: 'this guard waives files that are gone:\n${missing.join('\n')}');
  });

  for (final path in justified) {
    test('${path.split('/').last} says why it is a Cubit and not a Bloc', () {
      expect(
        File(path).readAsStringSync(),
        contains(justification),
        reason:
            '$path holds a repository, so CLAUDE.md would have made it a Bloc. Its class doc has to carry a '
            '"$justification" line saying what makes it the exception, so the next reader is not left to guess '
            'whether it is a decision or a drift.',
      );
    });
  }
}

/// Make a path relative for readable output.
String _relative(String path) => path.replaceAll(r'\', '/').replaceAll(RegExp(r'^.*?lib/'), 'lib/');
