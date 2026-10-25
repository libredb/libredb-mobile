@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_page.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_directory_repository.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/platform_grants/navigation/platform_grants_routes.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_grant_editor_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _orders = PlatformConnection(
  id: 'c 1',
  name: 'Orders',
  engine: 'postgres',
  status: 'active',
  hasWriteCredential: true,
);

DirectoryUser _user(String id, {bool enabled = true, String? role = 'user', bool needsSeat = false, String? email}) =>
    DirectoryUser(
      id: id,
      username: id,
      email: email,
      firstName: null,
      lastName: null,
      enabled: enabled,
      studioRole: role,
      needsSeat: needsSeat,
    );

final _alice = _user('alice', email: 'alice@example.com');
final _dora = _user('dora', enabled: false);
final _nora = _user('nora', role: null);
final _seat = _user('sam', needsSeat: true);
final _bob = _user('kc-bob');

PlatformGrant _grant({String subject = 'kc-bob', String level = 'read'}) => PlatformGrant(
  id: 'g-$subject',
  subject: subject,
  subjectUsername: subject,
  subjectEmail: null,
  level: level,
  expiresAt: null,
  grantedBy: const PlatformGrantGranter(id: 'u1', name: 'Admin', email: 'admin@example.com'),
  grantedAt: DateTime.utc(2027),
);

void main() {
  late MockIPlatformGrantRepository grants;
  late MockPlatformDirectoryRepository directory;

  setUp(() {
    grants = MockIPlatformGrantRepository();
    directory = MockPlatformDirectoryRepository();
    when(() => grants.list(any())).thenAnswer((_) async => Success([_grant()]));
    when(
      () => directory.search(
        query: any(named: 'query'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => Success(DirectoryPage(users: [_alice, _dora, _nora, _seat, _bob], page: 1, total: 5)));
  });

  void answerPut(Future<Result<String>> Function() answer) => when(
    () => grants.put(
      any(),
      any(),
      level: any(named: 'level'),
      expiresAt: any(named: 'expiresAt'),
    ),
  ).thenAnswer((_) => answer());

  int puts() {
    try {
      return verify(
        () => grants.put(
          any(),
          any(),
          level: any(named: 'level'),
          expiresAt: any(named: 'expiresAt'),
        ),
      ).callCount;
    } on TestFailure {
      return 0;
    }
  }

  Future<GoRouter> pumpRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.platformConnections,
      routes: [
        GoRoute(
          path: ApplicationRoutesConstants.platformConnections,
          builder: (_, _) => const Text('connections list'),
        ),
        ...PlatformGrantsFeatureRoutes.routes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IPlatformGrantRepository>.value(value: grants),
          RepositoryProvider<IPlatformDirectoryRepository>.value(value: directory),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
          builder: (context, child) => Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Opens the grants page of [connection], then its "Add access".
  Future<GoRouter> openPicker(WidgetTester tester, {PlatformConnection connection = _orders}) async {
    final router = await pumpRouter(tester);
    router.push('/platform/connections/${Uri.encodeComponent(connection.id)}', extra: connection);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('platform-grants-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('platform-directory-search')), findsOneWidget);
    return router;
  }

  /// Opens the grants page of [connection], then the "Change access" of the grant of [subject].
  Future<GoRouter> openEdit(
    WidgetTester tester, {
    required PlatformConnection connection,
    required String subject,
  }) async {
    final router = await pumpRouter(tester);
    router.push('/platform/connections/${Uri.encodeComponent(connection.id)}', extra: connection);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('platform-grant-actions-$subject')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.platform_grants_edit));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> pick(WidgetTester tester, DirectoryUser user) async {
    await tester.tap(find.byKey(ValueKey('platform-directory-user-${user.id}')));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('platform-grant-save')));
    await tester.tap(find.byKey(const ValueKey('platform-grant-save')));
    await tester.pumpAndSettle();
  }

  Finder form() => find.byKey(const ValueKey('platform-grant-editor-form'));

  testWidgets('"Add access" waits for the grants to load', (tester) async {
    final pending = Completer<Result<List<PlatformGrant>>>();
    when(() => grants.list(any())).thenAnswer((_) => pending.future);
    final router = await pumpRouter(tester);
    router.push('/platform/connections/c%201', extra: _orders);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('platform-grants-add'))).onPressed, isNull);

    pending.complete(Success([_grant()]));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('platform-grants-add'))).onPressed, isNotNull);
  });

  group('picker', () {
    testWidgets('shows each user with the role, disabled, seat and holder badges', (tester) async {
      await openPicker(tester);

      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text(S.current.platform_grants_picker_role_none), findsOneWidget);
      expect(find.text(S.current.platform_grants_picker_disabled), findsOneWidget);
      expect(find.text(S.current.platform_grants_picker_takes_seat), findsOneWidget);
      expect(find.byKey(const ValueKey('platform-directory-holds-kc-bob')), findsOneWidget);
    });

    testWidgets('a disabled user cannot be picked', (tester) async {
      await openPicker(tester);

      await pick(tester, _dora);

      expect(form(), findsNothing);
      expect(find.byKey(const ValueKey('platform-directory-search')), findsOneWidget);
    });

    testWidgets('a user with no Studio role can be picked, and the form repeats the note', (tester) async {
      await openPicker(tester);

      await pick(tester, _nora);

      expect(form(), findsOneWidget);
      expect(find.text(S.current.platform_grants_editor_title_new('Orders')), findsOneWidget);
      expect(find.byKey(const ValueKey('platform-grant-no-role-note')), findsOneWidget);
    });

    testWidgets('a user who holds a grant opens the form in edit mode, prefilled', (tester) async {
      when(() => grants.list(any())).thenAnswer((_) async => Success([_grant(level: 'write')]));
      await openPicker(tester);

      await pick(tester, _bob);

      expect(find.text(S.current.platform_grants_editor_title_edit('Orders')), findsOneWidget);
      final level = tester.widget<SegmentedButton<String>>(find.byKey(const ValueKey('platform-grant-level')));
      expect(level.selected, {'write'});
    });

    testWidgets('the seat note says the active wording on an active connection', (tester) async {
      await openPicker(tester);

      expect(find.text(S.current.platform_grants_picker_takes_seat), findsOneWidget);
      expect(find.text(S.current.platform_grants_picker_takes_seat_inactive), findsNothing);
    });

    testWidgets('the seat note says the inactive wording on an inactive connection', (tester) async {
      await openPicker(
        tester,
        connection: const PlatformConnection(
          id: 'c 1',
          name: 'Orders',
          engine: 'postgres',
          status: 'inactive',
          hasWriteCredential: true,
        ),
      );

      expect(find.text(S.current.platform_grants_picker_takes_seat_inactive), findsOneWidget);
      expect(find.text(S.current.platform_grants_picker_takes_seat), findsNothing);
    });

    testWidgets('a failed search shows the error state, and Retry asks again', (tester) async {
      var fail = true;
      when(
        () => directory.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => fail
            ? const Failure(ServerError('503', code: 'platform.directory_unavailable'))
            : Success(DirectoryPage(users: [_alice], page: 1, total: 1)),
      );
      await openPicker(tester);
      expect(find.text(S.current.platform_grants_picker_load_failed), findsOneWidget);

      fail = false;
      await tester.tap(find.text(S.current.retry));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('platform-directory-user-alice')), findsOneWidget);
    });

    testWidgets('no match shows the empty state', (tester) async {
      when(
        () => directory.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      ).thenAnswer((_) async => const Success(DirectoryPage(users: [], page: 1, total: 0)));

      await openPicker(tester);

      expect(find.text(S.current.platform_grants_picker_empty_title), findsOneWidget);
    });

    testWidgets('a long query shows the hint and is not sent', (tester) async {
      await openPicker(tester);
      clearInteractions(directory);

      await tester.enterText(find.byKey(const ValueKey('platform-directory-search')), 'x' * 256);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(S.current.platform_grants_picker_query_too_long), findsOneWidget);
      verifyNever(
        () => directory.search(
          query: any(named: 'query'),
          page: any(named: 'page'),
        ),
      );
    });
  });

  group('form', () {
    testWidgets('write is unavailable without a write credential, and an existing write grant saves only as read', (
      tester,
    ) async {
      answerPut(() async => const Success('g1'));
      when(() => grants.list(any())).thenAnswer((_) async => Success([_grant(level: 'write')]));
      await openEdit(
        tester,
        connection: const PlatformConnection(
          id: 'c 1',
          name: 'Orders',
          engine: 'postgres',
          status: 'active',
          hasWriteCredential: false,
        ),
        subject: 'kc-bob',
      );
      expect(find.byKey(const ValueKey('platform-grant-write-unavailable')), findsOneWidget);

      await save(tester);
      expect(puts(), 0);
      expect(find.byKey(const ValueKey('platform-grant-error-level')), findsOneWidget);

      await tester.tap(find.text(S.current.platform_grants_level_read).last);
      await tester.pumpAndSettle();
      await save(tester);

      verify(() => grants.put('c 1', 'kc-bob', level: 'read', expiresAt: null)).called(1);
    });

    testWidgets('on success the page pops with the saved note and the grant list is read again', (tester) async {
      answerPut(() async => const Success('g1'));
      await openPicker(tester);
      await pick(tester, _alice);

      await save(tester);

      expect(form(), findsNothing);
      expect(find.byType(PlatformConnectionGrantsPage), findsOneWidget);
      expect(find.text(S.current.platform_grants_editor_saved), findsOneWidget);
      verify(() => grants.list('c 1')).called(2);
    });

    testWidgets('a license refusal shows the license banner and keeps the form and its values', (tester) async {
      answerPut(() async => const Failure(AuthError('403', code: 'platform.license_user_seats')));
      await openPicker(tester);
      await pick(tester, _alice);
      await tester.tap(find.text(S.current.platform_grants_level_write).last);
      await tester.pumpAndSettle();

      await save(tester);

      expect(find.byKey(const ValueKey('platform-grant-banner-license')), findsOneWidget);
      expect(find.text(AppErrorCode.platformLicenseUserSeats.key), findsNothing);
      expect(form(), findsOneWidget);
      final level = tester.widget<SegmentedButton<String>>(find.byKey(const ValueKey('platform-grant-level')));
      expect(level.selected, {'write'});
    });

    testWidgets('a 404 shows the connection-gone banner, whose action opens the connection list', (tester) async {
      answerPut(() async => const Failure(NotFoundError('404', code: 'platform.not_found')));
      await openPicker(tester);
      await pick(tester, _alice);

      await save(tester);
      expect(find.byKey(const ValueKey('platform-grant-banner-connectionGone')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('platform-grant-back-to-connections')));
      await tester.pumpAndSettle();
      expect(find.text('connections list'), findsOneWidget);
    });

    testWidgets('a 503 shows Retry, and no second PUT is sent until it is tapped', (tester) async {
      var answers = <Result<String>>[
        const Failure(ServerError('503', code: 'platform.directory_unavailable')),
        const Success('g1'),
      ];
      answerPut(() async {
        final next = answers.first;
        answers = answers.sublist(1);
        return next;
      });
      await openPicker(tester);
      await pick(tester, _alice);

      await save(tester);
      expect(find.byKey(const ValueKey('platform-grant-banner-retry')), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(puts(), 1);

      await tester.tap(find.byKey(const ValueKey('platform-grant-retry')));
      await tester.pumpAndSettle();

      expect(puts(), 1, reason: 'one more PUT after the one counted above');
      expect(find.byType(PlatformConnectionGrantsPage), findsOneWidget);
    });

    for (final (name, error) in [
      ('a 500 INTERNAL_ERROR', const ServerError('500', code: 'platform.internal_error')),
      ('an unreadable 200', const ServerError('bad', code: 'platform.unreadable_answer')),
    ]) {
      testWidgets('$name shows a form error, keeps the form, and the grant list is read again on closing', (
        tester,
      ) async {
        answerPut(() async => Failure(error));
        final router = await openPicker(tester);
        await pick(tester, _alice);

        await save(tester);
        expect(find.byKey(const ValueKey('platform-grant-error-form')), findsOneWidget);
        expect(form(), findsOneWidget);
        expect(puts(), 1);

        router.pop();
        await tester.pumpAndSettle();

        expect(find.byType(PlatformConnectionGrantsPage), findsOneWidget);
        verify(() => grants.list('c 1')).called(2);
      });
    }

    testWidgets('a field refusal lands under its field', (tester) async {
      answerPut(() async => const Failure(ValidationError('400', code: 'platform.grant_subject_refused')));
      await openPicker(tester);
      await pick(tester, _alice);

      await save(tester);

      expect(find.byKey(const ValueKey('platform-grant-error-subject')), findsOneWidget);
      expect(find.byKey(const ValueKey('platform-grant-error-form')), findsNothing);
    });

    testWidgets('choose another user returns to the picker with its results', (tester) async {
      await openPicker(tester);
      await pick(tester, _alice);

      await tester.tap(find.text(S.current.platform_grants_editor_change_user));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('platform-directory-user-alice')), findsOneWidget);
      verify(() => directory.search(query: '', page: 1)).called(1);
    });
  });

  testWidgets('without its extra the editor opens the grants location, never guessing', (tester) async {
    final router = await pumpRouter(tester);

    router.go('/platform/connections/c%201/grant');
    await tester.pumpAndSettle();

    expect(find.byType(PlatformGrantEditorPage), findsNothing);
    // The grants location without its connection opens the connection list in turn.
    expect(find.text('connections list'), findsOneWidget);
    verifyNever(
      () => directory.search(
        query: any(named: 'query'),
        page: any(named: 'page'),
      ),
    );
  });
}
