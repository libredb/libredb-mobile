import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_editor_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/put_grant_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_target.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

final _now = DateTime(2027, 6, 1, 12, 30, 45);

const _writable = GrantTarget(connectionId: 'c1', connectionName: 'Sales', hasWriteCredential: true, active: true);
const _readOnly = GrantTarget(connectionId: 'c1', connectionName: 'Sales', hasWriteCredential: false, active: true);

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

PlatformGrant _grant({String level = 'read', DateTime? expiresAt}) => PlatformGrant(
  id: 'g1',
  subject: 'kc-bob',
  subjectUsername: 'bob',
  subjectEmail: 'bob@example.com',
  level: level,
  expiresAt: expiresAt,
  grantedBy: const PlatformGrantGranter(id: 'u1', name: null, email: 'admin@example.com'),
  grantedAt: DateTime.utc(2027),
);

AppError _error(AppErrorCode code) => ValidationError('Platform text', code: code.key);

void main() {
  late MockIPlatformGrantRepository repository;

  setUp(() => repository = MockIPlatformGrantRepository());

  GrantEditorBloc build({GrantTarget target = _writable, DirectoryUser? user = _alice, PlatformGrant? grant}) =>
      GrantEditorBloc(
        putGrantUseCase: PutGrantUseCase(repository),
        target: target,
        user: user,
        grant: grant,
        clock: Clock.fixed(_now),
      );

  void answer(Result<String> answer) => when(
    () => repository.put(
      any(),
      any(),
      level: any(named: 'level'),
      expiresAt: any(named: 'expiresAt'),
    ),
  ).thenAnswer((_) async => answer);

  void verifyNoPut() => verifyNever(
    () => repository.put(
      any(),
      any(),
      level: any(named: 'level'),
      expiresAt: any(named: 'expiresAt'),
    ),
  );

  group('opening', () {
    test('a new grant opens with read and no expiry', () {
      final state = build().state;

      expect(state.level, 'read');
      expect(state.expiresAt, isNull);
      expect(state.isEdit, isFalse);
      expect(state.subject.subject, 'f:ldap-1:alice');
      expect(state.status, GrantEditorStatus.editing);
    });

    test('an existing grant prefills its level and expiry', () {
      final expiry = DateTime.utc(2028, 1, 2, 3, 4);
      final state = build(
        user: null,
        grant: _grant(level: 'write', expiresAt: expiry),
      ).state;

      expect(state.isEdit, isTrue);
      expect(state.level, 'write');
      expect(state.expiresAt, expiry);
      expect(state.subject.subject, 'kc-bob');
      expect(state.levelIssue, isNull);
    });

    test('an existing write grant on a connection without a write credential shows write as unavailable', () {
      final state = build(
        target: _readOnly,
        user: null,
        grant: _grant(level: 'write'),
      ).state;

      expect(state.level, 'write');
      expect(state.levelIssue, GrantLevelIssue.writeUnavailable);
    });

    test('an existing grant of an unknown level opens with no level selected', () {
      final state = build(user: null, grant: _grant(level: 'owner')).state;

      expect(state.level, isNull);
    });

    test('an existing grant whose expiry has passed shows the expiry as not in the future', () {
      final state = build(user: null, grant: _grant(expiresAt: _now.subtract(const Duration(days: 1)))).state;

      expect(state.expiryIssue, GrantExpiryIssue.notInFuture);
    });
  });

  group('validation before sending', () {
    blocTest<GrantEditorBloc, GrantEditorState>(
      'a present expiry is refused and no request goes out',
      build: build,
      act: (bloc) => bloc
        ..add(GrantEditorExpiryChanged(DateTime(2027, 6, 1, 12, 30)))
        ..add(const GrantEditorSubmitted()),
      verify: (bloc) {
        expect(bloc.state.expiryIssue, GrantExpiryIssue.notInFuture);
        expect(bloc.state.status, GrantEditorStatus.editing);
        verifyNoPut();
      },
    );

    blocTest<GrantEditorBloc, GrantEditorState>(
      'a past expiry is refused and no request goes out',
      build: build,
      act: (bloc) => bloc
        ..add(GrantEditorExpiryChanged(DateTime(2027, 5, 1)))
        ..add(const GrantEditorSubmitted()),
      verify: (bloc) {
        expect(bloc.state.expiryIssue, GrantExpiryIssue.notInFuture);
        verifyNoPut();
      },
    );

    blocTest<GrantEditorBloc, GrantEditorState>(
      'write on a connection without a write credential is refused until read is picked',
      setUp: () => answer(const Success('g1')),
      build: () => build(
        target: _readOnly,
        user: null,
        grant: _grant(level: 'write'),
      ),
      act: (bloc) async {
        bloc.add(const GrantEditorSubmitted());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.levelIssue, GrantLevelIssue.writeUnavailable);
        verifyNoPut();
        bloc
          ..add(const GrantEditorLevelChanged('read'))
          ..add(const GrantEditorSubmitted());
      },
      verify: (bloc) {
        expect(bloc.state.status, GrantEditorStatus.saved);
        verify(() => repository.put('c1', 'kc-bob', level: 'read', expiresAt: null)).called(1);
      },
    );

    blocTest<GrantEditorBloc, GrantEditorState>(
      'no level selected is refused',
      build: () => build(user: null, grant: _grant(level: 'owner')),
      act: (bloc) => bloc.add(const GrantEditorSubmitted()),
      verify: (bloc) {
        expect(bloc.state.levelIssue, GrantLevelIssue.missing);
        verifyNoPut();
      },
    );

    test('an expiry drops its seconds and smaller units', () async {
      final bloc = build()..add(GrantEditorExpiryChanged(DateTime(2027, 7, 1, 9, 15, 59, 999)));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.expiresAt, DateTime(2027, 7, 1, 9, 15));
      await bloc.close();
    });
  });

  blocTest<GrantEditorBloc, GrantEditorState>(
    'sends the subject, the level and the expiry, and ends saved',
    setUp: () => answer(const Success('g9')),
    build: build,
    act: (bloc) => bloc
      ..add(const GrantEditorLevelChanged('write'))
      ..add(GrantEditorExpiryChanged(DateTime(2027, 7, 1, 9, 15)))
      ..add(const GrantEditorSubmitted()),
    verify: (bloc) {
      expect(bloc.state.status, GrantEditorStatus.saved);
      expect(bloc.state.mayHaveChanged, isTrue);
      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'write', expiresAt: DateTime(2027, 7, 1, 9, 15)))
          .called(1);
    },
  );

  test('a double tap on save sends one PUT', () async {
    final pending = Completer<Result<String>>();
    when(
      () => repository.put(
        any(),
        any(),
        level: any(named: 'level'),
        expiresAt: any(named: 'expiresAt'),
      ),
    ).thenAnswer((_) => pending.future);
    final bloc = build()..add(const GrantEditorSubmitted());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, GrantEditorStatus.submitting);
    bloc.add(const GrantEditorSubmitted());
    await Future<void>.delayed(Duration.zero);
    pending.complete(const Success('g1'));
    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.put(
        any(),
        any(),
        level: any(named: 'level'),
        expiresAt: any(named: 'expiresAt'),
      ),
    ).called(1);
    await bloc.close();
  });

  group('a refusal lands where it belongs, keeping the form', () {
    final cases = <AppErrorCode, Matcher>{
      AppErrorCode.platformGrantLevelRefused: isA<GrantEditorState>().having(
        (s) => s.levelIssue,
        'levelIssue',
        GrantLevelIssue.refused,
      ),
      AppErrorCode.platformGrantExpiryRefused: isA<GrantEditorState>().having(
        (s) => s.expiryIssue,
        'expiryIssue',
        GrantExpiryIssue.refused,
      ),
      AppErrorCode.platformGrantSubjectRefused: isA<GrantEditorState>().having(
        (s) => s.subjectRefused,
        'subjectRefused',
        isTrue,
      ),
      AppErrorCode.platformValidationFailed: isA<GrantEditorState>().having(
        (s) => s.formError,
        'formError',
        AppErrorCode.platformValidationFailed,
      ),
      for (final license in [
        AppErrorCode.platformLicenseUserSeats,
        AppErrorCode.platformLicenseExpired,
        AppErrorCode.platformLicenseInvalid,
      ])
        license: isA<GrantEditorState>()
            .having((s) => s.banner, 'banner', GrantEditorBanner.license)
            .having((s) => s.bannerCode, 'bannerCode', license),
      AppErrorCode.platformDirectoryUnavailable: isA<GrantEditorState>().having(
        (s) => s.banner,
        'banner',
        GrantEditorBanner.retry,
      ),
      AppErrorCode.platformKeycloakUnavailable: isA<GrantEditorState>().having(
        (s) => s.banner,
        'banner',
        GrantEditorBanner.retry,
      ),
      AppErrorCode.platformNotFound: isA<GrantEditorState>().having(
        (s) => s.banner,
        'banner',
        GrantEditorBanner.connectionGone,
      ),
      AppErrorCode.platformInternalError: isA<GrantEditorState>().having(
        (s) => s.formError,
        'formError',
        AppErrorCode.platformInternalError,
      ),
      AppErrorCode.platformUnreadableAnswer: isA<GrantEditorState>().having(
        (s) => s.formError,
        'formError',
        AppErrorCode.platformUnreadableAnswer,
      ),
    };
    for (final MapEntry(key: code, value: matcher) in cases.entries) {
      blocTest<GrantEditorBloc, GrantEditorState>(
        code.key,
        setUp: () => answer(Failure(_error(code))),
        build: build,
        act: (bloc) => bloc
          ..add(const GrantEditorLevelChanged('write'))
          ..add(GrantEditorExpiryChanged(DateTime(2027, 9, 1, 8)))
          ..add(const GrantEditorSubmitted()),
        verify: (bloc) {
          expect(bloc.state, matcher);
          expect(bloc.state.status, GrantEditorStatus.editing);
          expect(bloc.state.level, 'write');
          expect(bloc.state.expiresAt, DateTime(2027, 9, 1, 8));
          final others = [
            if (bloc.state.levelIssue != null) 'level',
            if (bloc.state.expiryIssue != null) 'expiry',
            if (bloc.state.subjectRefused) 'subject',
            if (bloc.state.formError != null) 'form',
            if (bloc.state.banner != null) 'banner',
          ];
          expect(others, hasLength(1), reason: 'one place shows the refusal');
        },
      );
    }
  });

  group('whether the grant may have changed', () {
    final cases = <String, (AppError, bool)>{
      'a field refusal': (_error(AppErrorCode.platformGrantSubjectRefused), false),
      'a license refusal': (_error(AppErrorCode.platformLicenseUserSeats), false),
      'a connection that is gone': (_error(AppErrorCode.platformNotFound), false),
      'a directory outage': (_error(AppErrorCode.platformDirectoryUnavailable), false),
      'a 500 INTERNAL_ERROR': (const ServerError('500', code: 'platform.internal_error'), true),
      'an unreadable 200': (const ServerError('bad', code: 'platform.unreadable_answer'), true),
      'a timeout': (const TimeoutError('slow'), true),
      'a lost connection': (const NetworkError('down'), true),
    };
    for (final MapEntry(key: name, value: (error, changed)) in cases.entries) {
      blocTest<GrantEditorBloc, GrantEditorState>(
        '${changed ? 'is' : 'is not'} said after $name',
        setUp: () => answer(Failure(error)),
        build: build,
        act: (bloc) => bloc.add(const GrantEditorSubmitted()),
        verify: (bloc) => expect(bloc.state.mayHaveChanged, changed),
      );
    }
  });

  group('retry', () {
    test('a 503 sends no second PUT until Retry, which sends the form again', () async {
      var answers = <Result<String>>[Failure(_error(AppErrorCode.platformDirectoryUnavailable)), const Success('g1')];
      when(
        () => repository.put(
          any(),
          any(),
          level: any(named: 'level'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenAnswer((_) async {
        final next = answers.first;
        answers = answers.sublist(1);
        return next;
      });
      final bloc = build()
        ..add(GrantEditorExpiryChanged(DateTime(2027, 9, 1, 8)))
        ..add(const GrantEditorSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.banner, GrantEditorBanner.retry);
      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: DateTime(2027, 9, 1, 8))).called(1);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      verifyNoPut();

      bloc.add(const GrantEditorRetryRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: DateTime(2027, 9, 1, 8))).called(1);
      expect(bloc.state.status, GrantEditorStatus.saved);
      await bloc.close();
    });

    void answerInOrder(List<Result<String>> answers) {
      var left = answers;
      when(
        () => repository.put(
          any(),
          any(),
          level: any(named: 'level'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).thenAnswer((_) async {
        final next = left.first;
        left = left.sublist(1);
        return next;
      });
    }

    test('Retry after a field changed sends the level the form shows', () async {
      answerInOrder([Failure(_error(AppErrorCode.platformDirectoryUnavailable)), const Success('g1')]);
      final bloc = build()..add(const GrantEditorSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.banner, GrantEditorBanner.retry);

      bloc
        ..add(const GrantEditorLevelChanged('write'))
        ..add(const GrantEditorRetryRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: null)).called(1);
      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'write', expiresAt: null)).called(1);
      expect(bloc.state.level, 'write');
      expect(bloc.state.status, GrantEditorStatus.saved);
      await bloc.close();
    });

    test('Retry after the expiry changed from never sends the expiry the form shows', () async {
      answerInOrder([Failure(_error(AppErrorCode.platformKeycloakUnavailable)), const Success('g1')]);
      final bloc = build()..add(const GrantEditorSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(bloc.state.banner, GrantEditorBanner.retry);

      bloc
        ..add(GrantEditorExpiryChanged(DateTime(2027, 9, 1, 8)))
        ..add(const GrantEditorRetryRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: DateTime(2027, 9, 1, 8))).called(1);
      expect(bloc.state.status, GrantEditorStatus.saved);
      await bloc.close();
    });

    test('Retry checks the form first and sends nothing for an expiry in the past', () async {
      answerInOrder([Failure(_error(AppErrorCode.platformDirectoryUnavailable))]);
      final bloc = build()..add(const GrantEditorSubmitted());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(() => repository.put('c1', 'f:ldap-1:alice', level: 'read', expiresAt: null)).called(1);

      bloc
        ..add(GrantEditorExpiryChanged(DateTime(2027, 5, 1, 8)))
        ..add(const GrantEditorRetryRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verifyNoPut();
      expect(bloc.state.expiryIssue, GrantExpiryIssue.notInFuture);
      expect(bloc.state.status, GrantEditorStatus.editing);
      await bloc.close();
    });

    blocTest<GrantEditorBloc, GrantEditorState>(
      'is ignored without a retry banner',
      build: build,
      act: (bloc) => bloc.add(const GrantEditorRetryRequested()),
      verify: (_) => verifyNoPut(),
    );
  });

  test('changing a field clears its refusal', () async {
    answer(Failure(_error(AppErrorCode.platformGrantExpiryRefused)));
    final bloc = build()
      ..add(GrantEditorExpiryChanged(DateTime(2027, 9, 1, 8)))
      ..add(const GrantEditorSubmitted());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.expiryIssue, GrantExpiryIssue.refused);

    bloc.add(const GrantEditorExpiryChanged(null));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.expiryIssue, isNull);
    expect(bloc.state.expiresAt, isNull);
    await bloc.close();
  });
}
