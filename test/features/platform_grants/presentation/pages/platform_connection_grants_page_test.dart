@Tags(['widget'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/platform_grants_providers.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';
import 'package:libredb_mobile/shared/widgets/platform_unreachable_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _orders = PlatformConnection(
  id: 'c1',
  name: 'Orders',
  engine: 'postgres',
  status: 'active',
  hasWriteCredential: true,
);

final _now = DateTime.utc(2027, 3, 1, 12);

PlatformGrant _grant(
  String id,
  String username, {
  String? email,
  String level = 'read',
  DateTime? expiresAt,
  String? granterName = 'Alice Admin',
}) => PlatformGrant(
  id: id,
  subject: 'kc-$id',
  subjectUsername: username,
  subjectEmail: email,
  level: level,
  expiresAt: expiresAt,
  grantedBy: PlatformGrantGranter(id: 'u1', name: granterName, email: 'alice@example.org'),
  grantedAt: DateTime.utc(2027, 1, 10, 9, 30),
);

final _bob = _grant('g1', 'bob', email: 'bob@example.org', expiresAt: DateTime.utc(2027, 6, 1));
final _carol = _grant('g2', 'carol', level: 'write', granterName: null);
final _dave = _grant('g3', 'dave', expiresAt: DateTime.utc(2027, 2, 1));
final _erin = _grant('g4', 'erin', level: 'owner');

String _date(DateTime value) => DateFormat.yMMMd('en').add_Hm().format(value.toLocal());

void main() {
  late MockIPlatformGrantRepository repository;

  /// Whether the Platform unreachable page covers the page.
  late ValueNotifier<bool> platformUnreachable;

  setUp(() {
    repository = MockIPlatformGrantRepository();
    platformUnreachable = ValueNotifier(false);
    addTearDown(platformUnreachable.dispose);
  });

  void answerList(List<Result<List<PlatformGrant>>> answers) {
    final queue = [...answers];
    when(() => repository.list(any())).thenAnswer((_) async => queue.length > 1 ? queue.removeAt(0) : queue.first);
  }

  /// The connections list with the grants page of [_orders] pushed above it, as the list's tap opens it.
  Future<GoRouter> pumpPage(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    final router = GoRouter(
      initialLocation: ApplicationRoutesConstants.platformConnections,
      routes: [
        GoRoute(
          path: ApplicationRoutesConstants.platformConnections,
          builder: (_, _) => const Text('connections list'),
        ),
        GoRoute(
          path: ApplicationRoutesConstants.platformConnectionGrants,
          builder: (_, state) {
            final connection = state.extra! as PlatformConnection;
            return PlatformGrantsProviders(
              connection: connection,
              child: PlatformConnectionGrantsPage(connection: connection),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider<IPlatformGrantRepository>.value(
        value: repository,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          routerConfig: router,
          // The Platform shell's ResponsiveScaffold frames the page in the app, under the Platform gate.
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: platformUnreachable,
            builder: (context, isUnreachable, _) => PlatformUnreachableStatus(
              isUnreachable: isUnreachable,
              child: Scaffold(body: child),
            ),
          ),
        ),
      ),
    );
    unawaited(router.push('/platform/connections/c1', extra: _orders));
    await tester.pump();
    return router;
  }

  Future<void> openRemoveDialog(WidgetTester tester, String username) async {
    await tester.tap(find.byKey(ValueKey('platform-grant-actions-$username')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove access'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the skeleton while the grants load', (tester) async {
    final pending = Completer<Result<List<PlatformGrant>>>();
    when(() => repository.list(any())).thenAnswer((_) => pending.future);

    await pumpPage(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppSkeleton), findsWidgets);
    pending.complete(const Success([]));
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets("shows the connection's name, engine and status in the header", (tester) async {
    answerList([const Success([])]);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('postgres'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('says no one has access when the connection has no grants', (tester) async {
    answerList([const Success([])]);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('No one has access yet'), findsOneWidget);
    verify(() => repository.list('c1')).called(1);
  });

  testWidgets('a failed load shows the error with a retry that loads again', (tester) async {
    answerList([
      Failure(ServerError('500', code: AppErrorCode.platformInternalError.key)),
      Success([_bob]),
    ]);

    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Could not load the grants'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('bob'), findsOneWidget);
    verify(() => repository.list('c1')).called(2);
  });

  group('once Platform answers again after its unreachable page covered the grants', () {
    testWidgets('grants that failed while covered are asked again, once', (tester) async {
      platformUnreachable.value = true;
      answerList([
        const Failure(NetworkError('Connection refused')),
        Success([_bob]),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();
      verify(() => repository.list('c1')).called(1);

      platformUnreachable.value = false;
      await tester.pumpAndSettle();

      verify(() => repository.list('c1')).called(1);
      expect(find.text('bob'), findsOneWidget);
    });

    testWidgets('a connection that is gone is not asked again', (tester) async {
      platformUnreachable.value = true;
      answerList([Failure(NotFoundError('404', code: AppErrorCode.platformNotFound.key))]);
      await pumpPage(tester);
      await tester.pumpAndSettle();
      verify(() => repository.list('c1')).called(1);

      platformUnreachable.value = false;
      await tester.pumpAndSettle();

      verifyNever(() => repository.list(any()));
    });

    testWidgets('loaded grants ask nothing and stay', (tester) async {
      answerList([
        Success([_bob]),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();
      verify(() => repository.list('c1')).called(1);
      platformUnreachable.value = true;
      await tester.pump();

      platformUnreachable.value = false;
      await tester.pumpAndSettle();

      verifyNever(() => repository.list(any()));
      expect(find.text('bob'), findsOneWidget);
    });
  });

  testWidgets('renders each grant: username, e-mail, level, expiry and who granted it', (tester) async {
    answerList([
      Success([_bob, _carol, _dave, _erin]),
    ]);

    await withClock(Clock.fixed(_now), () async {
      await pumpPage(tester);
      await tester.pumpAndSettle();
    });

    expect(find.text('bob'), findsOneWidget);
    expect(find.text('bob@example.org'), findsOneWidget);
    expect(find.text('Read'), findsNWidgets(2));
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('owner'), findsOneWidget, reason: 'an unknown level is shown as Platform sent it');
    expect(find.text('Expires ${_date(DateTime.utc(2027, 6, 1))}'), findsOneWidget);
    expect(find.text('No expiry'), findsNWidgets(2));
    expect(find.text('Granted by Alice Admin, ${_date(DateTime.utc(2027, 1, 10, 9, 30))}'), findsNWidgets(3));
    expect(
      find.text('Granted by alice@example.org, ${_date(DateTime.utc(2027, 1, 10, 9, 30))}'),
      findsOneWidget,
      reason: "the granter's e-mail stands in for a name Platform does not have",
    );
  });

  testWidgets('flags a grant whose expiry is at or before now as expired', (tester) async {
    answerList([
      Success([_bob, _dave]),
    ]);

    await withClock(Clock.fixed(_now), () async {
      await pumpPage(tester);
      await tester.pumpAndSettle();
    });

    expect(find.text('Expired ${_date(DateTime.utc(2027, 2, 1))}'), findsOneWidget);
    expect(find.byKey(const ValueKey('platform-grant-expired-dave')), findsOneWidget);
    expect(find.byKey(const ValueKey('platform-grant-expired-bob')), findsNothing);
  });

  testWidgets('renders in Turkish', (tester) async {
    answerList([
      Success([_carol]),
    ]);

    await pumpPage(tester, locale: const Locale('tr'));
    await tester.pumpAndSettle();

    expect(find.text('Yazma'), findsOneWidget);
    expect(find.text('Süresiz'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
  });

  group('revoke', () {
    testWidgets('asks first, naming the user, the level and the connection', (tester) async {
      answerList([
        Success([_carol]),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await openRemoveDialog(tester, 'carol');

      expect(find.text('carol will lose write access to Orders.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.revoke(any(), any()));
      expect(find.text('carol'), findsOneWidget);
    });

    testWidgets('a confirmed revoke removes the row and says so', (tester) async {
      answerList([
        Success([_bob, _carol]),
        Success([_carol]),
      ]);
      when(() => repository.revoke(any(), any())).thenAnswer((_) async => const Success(null));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await openRemoveDialog(tester, 'bob');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      verify(() => repository.revoke('c1', 'g1')).called(1);
      expect(find.text('Access removed'), findsOneWidget);
      expect(find.text('bob'), findsNothing);
      expect(find.text('carol'), findsOneWidget);
    });

    testWidgets('a double tap on confirm sends one DELETE and leaves the page open', (tester) async {
      answerList([
        Success([_bob]),
      ]);
      when(() => repository.revoke(any(), any())).thenAnswer((_) async => const Success(null));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await openRemoveDialog(tester, 'bob');
      await tester.tap(find.text('Remove'));
      await tester.tap(find.text('Remove'), warnIfMissed: false);
      await tester.pumpAndSettle();

      verify(() => repository.revoke('c1', 'g1')).called(1);
      expect(find.text('connections list'), findsNothing);
      expect(find.text('Orders'), findsOneWidget);
    });

    testWidgets('a 404 refreshes the list and says it was already removed', (tester) async {
      answerList([
        Success([_bob, _carol]),
        Success([_carol]),
      ]);
      when(() => repository.revoke(any(), any()))
          .thenAnswer((_) async => Failure(NotFoundError('404', code: AppErrorCode.platformNotFound.key)));
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await openRemoveDialog(tester, 'bob');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Already removed'), findsOneWidget);
      expect(find.text('bob'), findsNothing);
      verify(() => repository.list('c1')).called(2);
    });

    testWidgets('a failure says why and keeps the list as it was', (tester) async {
      answerList([
        Success([_bob]),
      ]);
      when(() => repository.revoke(any(), any())).thenAnswer(
        (_) async => Failure(ServerError('503', code: AppErrorCode.platformIdentityProviderUnavailable.key)),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final message = S.current.error_platform_identity_provider_unavailable;

      await openRemoveDialog(tester, 'bob');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
      verify(() => repository.list('c1')).called(1);
    });

    testWidgets("disables every row's actions while a revoke runs", (tester) async {
      answerList([
        Success([_bob, _carol]),
      ]);
      final pending = Completer<Result<void>>();
      when(() => repository.revoke(any(), any())).thenAnswer((_) => pending.future);
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await openRemoveDialog(tester, 'bob');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      for (final username in ['bob', 'carol']) {
        final menu = tester.widget<PopupMenuButton<Object?>>(find.byKey(ValueKey('platform-grant-actions-$username')));
        expect(menu.enabled, isFalse, reason: username);
      }

      pending.complete(const Success(null));
      await tester.pumpAndSettle();

      expect(
        tester.widget<PopupMenuButton<Object?>>(find.byKey(const ValueKey('platform-grant-actions-carol'))).enabled,
        isTrue,
      );
    });
  });

  group('refresh', () {
    testWidgets('a failed refresh keeps the grants and shows the banner with a retry', (tester) async {
      answerList([
        Success([_bob]),
        Failure(ServerError('500', code: AppErrorCode.platformInternalError.key)),
        Success([_bob, _carol]),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.fling(find.text('bob'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('bob'), findsOneWidget);
      expect(find.text('Could not refresh the grants'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh the grants'), findsNothing);
      expect(find.text('carol'), findsOneWidget);
    });

    testWidgets('leaving the page while a pull to refresh waits for Platform throws nothing', (tester) async {
      answerList([
        Success([_bob]),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();
      final pending = Completer<Result<List<PlatformGrant>>>();
      when(() => repository.list(any())).thenAnswer((_) => pending.future);

      await tester.fling(find.text('bob'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      pending.complete(Success([_bob]));
      await tester.pump(const Duration(seconds: 5));
      // The closing bloc lets the pending request finish before its stream ends, outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed refresh of an empty list shows the banner above the empty state', (tester) async {
      answerList([
        const Success([]),
        Failure(ServerError('500', code: AppErrorCode.platformInternalError.key)),
        Success([_bob]),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(AppEmptyState), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      verify(() => repository.list('c1')).called(2);
      expect(find.text('No one has access yet'), findsOneWidget);
      expect(find.text('Could not refresh the grants'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh the grants'), findsNothing);
      expect(find.text('bob'), findsOneWidget);
    });

    testWidgets('a refresh answered 404 says the connection no longer exists, with a way back', (tester) async {
      answerList([
        Success([_bob]),
        Failure(NotFoundError('404', code: AppErrorCode.platformNotFound.key)),
      ]);
      await pumpPage(tester);
      await tester.pumpAndSettle();

      await tester.fling(find.text('bob'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('This connection no longer exists'), findsOneWidget);
      await tester.tap(find.text('Back to connections'));
      await tester.pumpAndSettle();

      expect(find.text('connections list'), findsOneWidget);
    });
  });
}
