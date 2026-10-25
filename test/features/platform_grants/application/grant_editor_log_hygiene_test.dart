import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/directory_picker_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_editor_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/put_grant_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/search_directory_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_target.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';
import '../../../support/printed_lines.dart';

const _alice = DirectoryUser(
  id: 'f:ldap-1:alice',
  username: 'alice',
  email: 'alice@example.com',
  firstName: 'Alice',
  lastName: 'Stone',
  enabled: true,
  studioRole: 'user',
  needsSeat: true,
);

/// The picker and the editor print no query, subject, username, name or e-mail address. The texts of their events and
/// states are checked too, since the bloc observer and the dev console print them.
void main() {
  test('a search for alice@example.com and a save for f:ldap-1:alice print no line containing alice', () async {
    final directory = MockPlatformDirectoryRepository();
    final grants = MockIPlatformGrantRepository();
    when(
      () => directory.search(
        query: any(named: 'query'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => const Success(DirectoryPage(users: [_alice], page: 1, total: 1)));
    var put = 0;
    when(
      () => grants.put(
        any(),
        any(),
        level: any(named: 'level'),
        expiresAt: any(named: 'expiresAt'),
      ),
    ).thenAnswer(
      (_) async => put++ == 0
          ? const Failure(ValidationError('Keycloak user alice is disabled', code: 'platform.grant_subject_refused'))
          : const Success('g1'),
    );

    final texts = <String>['${const DirectoryPickerQueryChanged('alice@example.com')}'];
    final lines = await printedLines(() async {
      final picker = DirectoryPickerBloc(searchDirectoryUseCase: SearchDirectoryUseCase(directory))
        ..add(const DirectoryPickerOpened());
      picker.stream.listen((state) => texts.add('$state'));
      await Future<void>.delayed(Duration.zero);
      picker.add(const DirectoryPickerQueryChanged('alice@example.com'));
      await Future<void>.delayed(DirectoryPickerBloc.debounce + const Duration(milliseconds: 50));
      expect(picker.state.query, 'alice@example.com');
      await picker.close();

      final editor = GrantEditorBloc(
        putGrantUseCase: PutGrantUseCase(grants),
        target: const GrantTarget(
          connectionId: 'c1',
          connectionName: 'Alice DB',
          hasWriteCredential: true,
          active: true,
        ),
        user: picker.state.users.single,
        clock: Clock.fixed(DateTime(2027)),
      );
      editor.stream.listen((state) => texts.add('$state'));
      texts.add('${editor.state}');
      editor.add(const GrantEditorSubmitted());
      await Future<void>.delayed(Duration.zero);
      editor.add(const GrantEditorSubmitted());
      await Future<void>.delayed(Duration.zero);
      expect(editor.state.status, GrantEditorStatus.saved);
      await editor.close();
    });

    // Positive controls: the lines are captured, the blocs' own lines and the observer's among them.
    expect(lines, contains(contains('DirectoryPickerBloc : search: page 1, 1 users of 1')));
    expect(lines, contains(contains('GrantEditorBloc : save failed: platform.grant_subject_refused')));
    expect(lines, contains(contains('GrantEditorBloc : save: the grant is saved')));
    expect(texts.length, greaterThan(4));
    expect(lines.where((line) => line.toLowerCase().contains('alice')), isEmpty);
    expect(texts.where((text) => text.toLowerCase().contains('alice')), isEmpty);
  });
}
