@Tags(['widget'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/connections/data/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// The answer of `assets/mock/GET_connections_managed.json`, which the app shows in local mode.
ManagedConnections _mockAnswer() =>
    ManagedConnectionsModel.read(File('assets/mock/GET_connections_managed.json').readAsStringSync());

void main() {
  late MockIConnectionRepository repository;

  setUp(() {
    repository = MockIConnectionRepository();
  });

  void answer(ManagedConnections managed) =>
      when(() => repository.listManaged()).thenAnswer((_) async => Success(managed));

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    ThemeData? theme,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository)),
              ),
              BlocProvider(create: (_) => CollapsedSectionsCubit(repository: CollapsedSectionsRepository())..restore()),
            ],
            child: const ConnectionListPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder row(String id) => find.byKey(ValueKey('connection-row-$id'));
  Finder header(String key) => find.byKey(ValueKey('connection-section-$key'));

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
  }

  testWidgets('shows the mock data in Analytics, Catalog, Finance and Sales sections, with Other last', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester);

    verify(() => repository.listManaged()).called(1);
    final titles = ['Analytics', 'Catalog', 'Finance', 'Sales', S.current.connection_group_other];
    final tops = [
      for (final key in ['group:Analytics', 'group:Catalog', 'group:Finance', 'group:Sales', 'other'])
        tester.getTopLeft(header(key)).dy,
    ];
    expect(tops, [...tops]..sort());
    for (final title in titles) {
      expect(
        find.descendant(of: find.byKey(const ValueKey('connection-sections')), matching: find.text(title)),
        findsWidgets,
      );
    }
    expect(find.descendant(of: header('other'), matching: find.text(S.current.connection_group_other)), findsOneWidget);
    expect(find.descendant(of: row('seed:sandbox-sqlite'), matching: find.text('Sandbox (SQLite)')), findsOneWidget);
  });

  testWidgets('shows the database, or the host when there is none, under the name', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:sales-postgres'), matching: find.text('sales')), findsOneWidget);
    expect(find.descendant(of: row('seed:erp-oracle'), matching: find.text('oracle.erp.internal')), findsOneWidget);
  });

  for (final (name, theme) in [('light', AppTheme.light()), ('dark', AppTheme.dark())]) {
    testWidgets('shows the PROD badge with its text and semantics on every production row, $name theme', (
      tester,
    ) async {
      final managed = _mockAnswer();
      answer(managed);
      final handle = tester.ensureSemantics();

      await pumpPage(tester, theme: theme);

      final production = managed.connections.where((c) => c.environment == 'production').toList();
      expect(production, hasLength(3));
      for (final connection in production) {
        expect(find.descendant(of: row(connection.id), matching: find.text('PROD')), findsOneWidget);
        // A screen reader reads the badge with the row it belongs to.
        expect(tester.getSemantics(row(connection.id)).label, contains(S.current.connection_environment_badge('PROD')));
      }
      expect(find.descendant(of: row('seed:catalog-mongo'), matching: find.text('STAGING')), findsOneWidget);
      handle.dispose();
    });
  }

  testWidgets('shows no badge for the environment other, as Studio does', (tester) async {
    answer(
      const ManagedConnections(
        connections: [StudioConnection(id: 'seed:x', name: 'X', type: 'postgres', environment: 'other')],
      ),
    );

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:x'), matching: find.byType(EnvironmentBadge)), findsNothing);
  });

  testWidgets('shows the read-only chip only on a read-only row', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester);

    expect(find.descendant(of: row('seed:billing-mysql'), matching: find.byType(ReadOnlyChip)), findsOneWidget);
    expect(find.byType(ReadOnlyChip), findsOneWidget);
    expect(
      find.descendant(of: row('seed:billing-mysql'), matching: find.text(S.current.connection_read_only)),
      findsOneWidget,
    );
  });

  testWidgets('collapses a section, remembers it on the device and expands it again', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.tap(header('group:Finance'));
    await tester.pump();

    expect(row('seed:billing-mysql'), findsNothing);
    expect(row('seed:erp-oracle'), findsNothing);
    expect(row('seed:sales-postgres'), findsOneWidget);

    // A new page on the same device opens with the section still collapsed.
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester);
    expect(row('seed:billing-mysql'), findsNothing);

    await tester.tap(header('group:Finance'));
    await tester.pump();
    expect(row('seed:billing-mysql'), findsOneWidget);
  });

  testWidgets('search narrows across sections, folding the Turkish i', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await search(tester, 'İNTERNAL');
    expect(row('seed:sales-postgres'), findsOneWidget);
    expect(row('seed:sandbox-sqlite'), findsNothing);

    await search(tester, 'fınance');
    expect(row('seed:billing-mysql'), findsOneWidget);
    expect(row('seed:erp-oracle'), findsOneWidget);
    expect(row('seed:sales-postgres'), findsNothing);
    expect(header('group:Sales'), findsNothing);
    expect(header('group:Finance'), findsOneWidget);
  });

  testWidgets("an empty search result says 'No connections match' and clearing brings the rows back", (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await search(tester, 'no such connection');
    expect(find.text(S.current.connection_search_no_match), findsOneWidget);
    expect(find.text('No connections match'), findsOneWidget);

    await tester.tap(find.byTooltip(S.current.connection_search_clear));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text(S.current.connection_search_no_match), findsNothing);
    expect(row('seed:sales-postgres'), findsOneWidget);
  });

  testWidgets('the environment chips narrow the list to one environment', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'DEV'));
    await tester.pump();

    expect(row('seed:reporting-mssql'), findsOneWidget);
    expect(row('seed:sales-postgres'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'DEV'));
    await tester.pump();
    expect(row('seed:sales-postgres'), findsOneWidget);
  });

  testWidgets('a pull to refresh asks Studio again', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    verify(() => repository.listManaged()).called(2);
  });

  testWidgets('a failed refresh keeps the list and says why', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);
    when(() => repository.listManaged())
        .thenAnswer((_) async => Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key)));

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(row('seed:sales-postgres'), findsOneWidget);
    final context = tester.element(find.byType(ConnectionListPage));
    expect(find.text(AppErrorCode.networkCertInvalid.resolve(context)), findsOneWidget);
  });

  testWidgets('a search typed during a refresh that then fails keeps the pull indicator, the query and the message', (
    tester,
  ) async {
    answer(_mockAnswer());
    await pumpPage(tester);
    final pending = Completer<Result<ManagedConnections>>();
    when(() => repository.listManaged()).thenAnswer((_) => pending.future);

    await tester.fling(find.byKey(const ValueKey('connection-sections')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await search(tester, 'billing');

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    pending.complete(Failure(NetworkError('down', code: AppErrorCode.networkCertInvalid.key)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(row('seed:billing-mysql'), findsOneWidget);
    expect(row('seed:sales-postgres'), findsNothing);
    final context = tester.element(find.byType(ConnectionListPage));
    expect(find.text(AppErrorCode.networkCertInvalid.resolve(context)), findsOneWidget);
  });

  testWidgets('tapping a row opens its details', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    await tester.tap(row('seed:billing-mysql'));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Billing (MySQL)')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('mysql')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Finance')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('mysql.billing.internal:3306/billing')), findsOneWidget);
  });

  testWidgets('never offers to add a connection', (tester) async {
    answer(_mockAnswer());
    await pumpPage(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('rows are at least 48 dp tall and lay out without overflow at a large text size', (tester) async {
    answer(_mockAnswer());

    await pumpPage(tester, textScale: 2, size: const Size(360, 1600));

    expect(tester.takeException(), isNull);
    for (final id in ['seed:sales-postgres', 'seed:billing-mysql', 'seed:sandbox-sqlite']) {
      expect(tester.getSize(row(id)).height, greaterThanOrEqualTo(48), reason: id);
    }
    expect(tester.getSize(header('group:Sales')).height, greaterThanOrEqualTo(48));
    final name = tester.renderObject<RenderParagraph>(
      find.descendant(of: row('seed:sales-postgres'), matching: find.text('Sales (PostgreSQL)')),
    );
    expect(name.textScaler, const TextScaler.linear(2));
  });

  testWidgets('shows the empty text when Studio answers no connection', (tester) async {
    answer(const ManagedConnections(connections: <StudioConnection>[]));

    await pumpPage(tester);

    expect(find.text(S.current.connection_list_empty), findsOneWidget);
  });

  testWidgets('shows a failure with a retry that asks again', (tester) async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Failure(NetworkError('down')));

    await pumpPage(tester);

    expect(find.text(S.current.connection_list_load_failed), findsOneWidget);
    await tester.tap(find.text(S.current.refresh));
    await tester.pump();
    await tester.pump();
    verify(() => repository.listManaged()).called(2);
  });
}
