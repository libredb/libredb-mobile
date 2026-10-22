@Tags(['widget'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/top_bar/active_connection_title.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_switcher_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/environment_colors.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mock_classes.dart';

void main() {
  late MockActiveConnectionCubit cubit;
  late MockIConnectionRepository connections;
  late MockICollapsedSectionsRepository collapsed;

  setUp(() {
    cubit = MockActiveConnectionCubit();
    connections = MockIConnectionRepository();
    collapsed = MockICollapsedSectionsRepository();
    when(() => connections.listManaged()).thenAnswer((_) async => const Success(ManagedConnections(connections: [])));
    when(() => collapsed.read()).thenAnswer((_) async => <String>{});
  });

  Future<void> pumpTitle(WidgetTester tester, ActiveConnectionState state, {double width = 400}) async {
    whenListen(cubit, const Stream<ActiveConnectionState>.empty(), initialState: state);
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IConnectionRepository>.value(value: connections),
          RepositoryProvider<ICollapsedSectionsRepository>.value(value: collapsed),
        ],
        child: BlocProvider<ActiveConnectionCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            home: const Scaffold(
              body: SizedBox(height: 48, child: ActiveConnectionTitle(fallback: 'Browse')),
            ),
          ),
        ),
      ),
    );
  }

  Color? stripColor(WidgetTester tester) {
    final strip = find.byKey(const ValueKey('active-connection-strip'));
    if (strip.evaluate().isEmpty) return null;
    return (tester.widget<Container>(strip).decoration! as BoxDecoration).color;
  }

  testWidgets('with no connection open, shows the tab title and opens the switcher', (tester) async {
    await pumpTitle(tester, const ActiveConnectionNone());

    expect(find.text('Browse'), findsOneWidget);
    expect(stripColor(tester), isNull);

    await tester.tap(find.byType(ActiveConnectionTitle));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionSwitcherSheet), findsOneWidget);
  });

  testWidgets('after a connection vanished, shows the tab title', (tester) async {
    await pumpTitle(
      tester,
      const ActiveConnectionVanished(StudioConnection(id: 'seed:a', name: 'Gone', type: 'mysql')),
    );

    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Gone'), findsNothing);
  });

  testWidgets('shows the name of the open connection, with no badge, strip or lock when it has none', (tester) async {
    await pumpTitle(tester, const ActiveConnectionSelected(StudioConnection(id: 'seed:a', name: 'Sales', type: 'pg')));

    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Browse'), findsNothing);
    expect(stripColor(tester), isNull);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byTooltip(S.current.connection_switcher_title), findsOneWidget);
  });

  testWidgets('marks a production connection with the PROD label and the production strip', (tester) async {
    await pumpTitle(
      tester,
      const ActiveConnectionSelected(
        StudioConnection(id: 'seed:a', name: 'Billing', type: 'mysql', environment: 'production'),
      ),
    );

    expect(find.text('PROD'), findsOneWidget);
    expect(stripColor(tester), EnvironmentColors.production);
  });

  testWidgets("takes the operator's color for the strip", (tester) async {
    await pumpTitle(
      tester,
      const ActiveConnectionSelected(
        StudioConnection(id: 'seed:a', name: 'Lab', type: 'pg', environment: 'development', color: '#0055aa'),
      ),
    );

    expect(find.text('DEV'), findsOneWidget);
    expect(stripColor(tester), const Color(0xFF0055AA));
  });

  testWidgets('shows a lock, read as read only, on a read-only connection', (tester) async {
    await pumpTitle(
      tester,
      const ActiveConnectionSelected(StudioConnection(id: 'seed:a', name: 'Billing', type: 'mysql', readOnly: true)),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(S.current.connection_read_only)), findsOneWidget);
  });

  testWidgets('shows the lock for a read grant of a governed Studio on a connection that is not read-only', (
    tester,
  ) async {
    await pumpTitle(
      tester,
      const ActiveConnectionSelected(
        StudioConnection(id: 'seed:a', name: 'Sales', type: 'pg', access: StudioAccess.read),
      ),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('shows no lock for a write grant on a connection that is not read-only', (tester) async {
    await pumpTitle(
      tester,
      const ActiveConnectionSelected(
        StudioConnection(id: 'seed:a', name: 'Sales', type: 'pg', access: StudioAccess.write),
      ),
    );

    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('shortens a long name instead of overflowing a narrow top bar', (tester) async {
    await pumpTitle(
      tester,
      const ActiveConnectionSelected(
        StudioConnection(
          id: 'seed:a',
          name: 'A very long connection name that does not fit into a phone top bar at all',
          type: 'mysql',
          environment: 'production',
          readOnly: true,
        ),
      ),
      width: 240,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('PROD'), findsOneWidget);
  });

  testWidgets('opens the switcher on a tap', (tester) async {
    await pumpTitle(tester, const ActiveConnectionSelected(StudioConnection(id: 'seed:a', name: 'Sales', type: 'pg')));

    await tester.tap(find.text('Sales'));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionSwitcherSheet), findsOneWidget);
  });
}
