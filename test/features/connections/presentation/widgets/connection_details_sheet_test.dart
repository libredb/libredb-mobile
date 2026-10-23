@Tags(['widget'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/connection_check_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_test_result.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_details_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/provider_meta.dart';
import 'package:libredb_mobile/shared/models/query_result.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _connection = StudioConnection(
  id: 'seed:billing-mysql',
  name: 'Billing (MySQL)',
  type: 'mysql',
  host: 'mysql.billing.internal',
  port: 3306,
  database: 'billing',
  environment: 'production',
  group: 'Finance',
  readOnly: true,
);

ProviderMeta _meta({bool resumesBilledCompute = false}) => ProviderMeta(
  queryLanguage: 'sql',
  schemaRefreshPattern: r'(CREATE|DROP)\b',
  containerLevels: const [],
  objectKinds: const [],
  resumesBilledCompute: resumesBilledCompute,
);

void main() {
  late MockIConnectionRepository connections;
  late MockIProviderMetaRepository providerMeta;

  setUp(() {
    connections = MockIConnectionRepository();
    providerMeta = MockIProviderMetaRepository();
    when(() => providerMeta.providerMeta(any())).thenAnswer((_) async => Success(_meta()));
  });

  Future<void> pumpSheet(WidgetTester tester, {bool offline = false, StudioConnection connection = _connection}) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      OfflineStatus(
        isOffline: offline,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => FavoriteConnectionsBloc(repository: MockIFavoriteConnectionsRepository())),
                BlocProvider(
                  create: (_) => ConnectionCheckBloc(
                    connectionId: connection.id,
                    connectionRepository: connections,
                    providerMetaRepository: providerMeta,
                  ),
                ),
              ],
              child: ConnectionDetailsSheet(connection: connection),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder checkButton() => find.byKey(const ValueKey('connection-check'));
  Finder checkAnywayButton() => find.byKey(const ValueKey('connection-check-anyway'));
  Finder status() => find.byKey(const ValueKey('connection-check-status'));
  BuildContext contextOf(WidgetTester tester) => tester.element(find.byType(ConnectionDetailsSheet));

  testWidgets('shows the engine, host, database, environment, group and read-only, and checks nothing on open', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Billing (MySQL)'), findsOneWidget);
    expect(find.text('mysql'), findsOneWidget);
    expect(find.text('mysql.billing.internal:3306'), findsOneWidget);
    expect(find.text('billing'), findsOneWidget);
    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.byType(ReadOnlyChip), findsOneWidget);
    expect(find.descendant(of: status(), matching: find.text('Not checked yet')), findsOneWidget);
    expect(checkButton(), findsOneWidget);
    verifyZeroInteractions(connections);
    verifyZeroInteractions(providerMeta);
  });

  testWidgets('a check shows the latency in the status chip', (tester) async {
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async =>
          const Success(ConnectionTestResult(message: 'Connection successful', latency: Duration(milliseconds: 42))),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Reachable, 42 ms')), findsOneWidget);
    expect(find.bySemanticsLabel('Status: Reachable, 42 ms'), findsOneWidget);
  });

  testWidgets('a check with Studio its warnings shows Reachable and each warning under it', (tester) async {
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async => const Success(
        ConnectionTestResult(
          message: 'Connection successful',
          latency: Duration(milliseconds: 42),
          warnings: [
            QueryWarning(message: 'database "nope" does not exist', severity: 'notice'),
            QueryWarning(message: 'index not ready'),
            QueryWarning(message: '', code: 'MZ1'),
          ],
        ),
      ),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Reachable, 42 ms')), findsOneWidget);
    final warnings = find.byKey(const ValueKey('connection-check-warnings'));
    expect(
      find.descendant(of: warnings, matching: find.text('notice: database "nope" does not exist')),
      findsOneWidget,
    );
    expect(find.descendant(of: warnings, matching: find.text('index not ready')), findsOneWidget);
    expect(find.descendant(of: warnings, matching: find.text('Warning MZ1')), findsOneWidget);
    expect(find.descendant(of: warnings, matching: find.byIcon(Icons.warning_amber)), findsNWidgets(3));
  });

  testWidgets('a check without warnings shows Reachable alone', (tester) async {
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async =>
          const Success(ConnectionTestResult(message: 'Connection successful', latency: Duration(milliseconds: 42))),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Reachable, 42 ms')), findsOneWidget);
    expect(find.byKey(const ValueKey('connection-check-warnings')), findsNothing);
  });

  testWidgets('a degraded check shows its message and then the warnings', (tester) async {
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async => const Success(
        ConnectionTestResult(
          message: 'no health',
          degraded: true,
          warnings: [QueryWarning(message: 'careful')],
        ),
      ),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(find.text('no health'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('connection-check-warnings')), matching: find.text('careful')),
      findsOneWidget,
    );
  });

  testWidgets('shows the check running and disables the button until Studio answers', (tester) async {
    final answer = Completer<Result<ConnectionTestResult>>();
    when(() => connections.test(_connection.id)).thenAnswer((_) => answer.future);
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Checking')), findsOneWidget);
    expect(tester.widget<FilledButton>(checkButton()).onPressed, isNull);
    answer.complete(
      const Success(ConnectionTestResult(message: 'Connection successful', latency: Duration(seconds: 1))),
    );
    await tester.pump();
    expect(find.descendant(of: status(), matching: find.text('Reachable, 1000 ms')), findsOneWidget);
  });

  testWidgets('a degraded check shows Studio its message under the chip', (tester) async {
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async => const Success(
        ConnectionTestResult(message: 'Connected, but this server answered no health data: x', degraded: true),
      ),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Reachable, without health data')), findsOneWidget);
    expect(find.text('Connected, but this server answered no health data: x'), findsOneWidget);
  });

  testWidgets('a billed-compute engine is not checked and offers Check anyway, which checks it', (tester) async {
    when(() => providerMeta.providerMeta(any())).thenAnswer((_) async => Success(_meta(resumesBilledCompute: true)));
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async =>
          const Success(ConnectionTestResult(message: 'Connection successful', latency: Duration(milliseconds: 7))),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(of: status(), matching: find.text('Not checked: checking would start billed compute')),
      findsOneWidget,
    );
    expect(checkButton(), findsNothing);
    verifyNever(() => connections.test(any()));

    await tester.tap(checkAnywayButton());
    await tester.pump();
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Reachable, 7 ms')), findsOneWidget);
    verify(() => connections.test(_connection.id)).called(1);
  });

  testWidgets('a refused database credential shows the translated message and the fix statement', (tester) async {
    when(() => connections.test(_connection.id)).thenAnswer(
      (_) async => Failure(
        AuthError(
          'password authentication failed for user "app"',
          code: AppErrorCode.studioDatabaseAuth.key,
          fixStatement: "ALTER USER app WITH PASSWORD '...'",
        ),
      ),
    );
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    expect(find.descendant(of: status(), matching: find.text('Check failed')), findsOneWidget);
    expect(find.text(AppErrorCode.studioDatabaseAuth.resolve(contextOf(tester))), findsOneWidget);
    expect(find.text("ALTER USER app WITH PASSWORD '...'"), findsOneWidget);
    expect(find.textContaining('password authentication failed'), findsNothing);
  });

  testWidgets('a rate limit counts down before the check can run again', (tester) async {
    var calls = 0;
    when(() => connections.test(_connection.id)).thenAnswer((_) async {
      calls++;
      return Failure(
        RateLimitedError('slow down', code: AppErrorCode.studioRateLimited.key, retryAfter: const Duration(seconds: 2)),
      );
    });
    await pumpSheet(tester);

    await tester.tap(checkButton());
    await tester.pump();
    await tester.pump();

    final s = S.of(contextOf(tester));
    // A rate limit says nothing about the database, so the chip does not claim it is unreachable.
    expect(find.descendant(of: status(), matching: find.text('Check failed')), findsOneWidget);
    expect(find.text(s.studio_error_retry_in(2)), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, s.retry);
    expect(tester.widget<OutlinedButton>(retry).onPressed, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('offline, the check is disabled with the reason', (tester) async {
    await pumpSheet(tester, offline: true);

    expect(tester.widget<FilledButton>(checkButton()).onPressed, isNull);
    expect(find.text(S.of(contextOf(tester)).offline_action_unavailable), findsOneWidget);
  });

  testWidgets('a connection without host, database, environment or group shows only what Studio sent', (tester) async {
    await pumpSheet(
      tester,
      connection: const StudioConnection(id: 'seed:x', name: 'X', type: 'sqlite'),
    );

    final s = S.of(contextOf(tester));
    expect(find.text(s.connection_host), findsNothing);
    expect(find.text(s.connection_database), findsNothing);
    expect(find.text(s.connection_environment), findsNothing);
    expect(find.text(s.connection_group), findsNothing);
    expect(find.byType(ReadOnlyChip), findsNothing);
  });
}
