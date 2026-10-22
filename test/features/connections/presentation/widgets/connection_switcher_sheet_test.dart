@Tags(['widget'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_favorites.dart';
import 'package:libredb_mobile/features/connections/data/models/managed_connections_model.dart';
import 'package:libredb_mobile/features/connections/domain/entities/managed_connections.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_switcher_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

/// The answer of `assets/mock/GET_connections_managed.json`, which the app shows in local mode.
ManagedConnections _mockAnswer() =>
    ManagedConnectionsModel.read(File('assets/mock/GET_connections_managed.json').readAsStringSync());

void main() {
  late MockIConnectionRepository connections;
  late MockICollapsedSectionsRepository collapsed;
  late MockIActiveConnectionStore store;
  late ActiveConnectionCubit cubit;
  late MockIFavoriteConnectionsRepository favoritesStore;
  late FavoriteConnectionsBloc favorites;

  setUp(() {
    favoritesStore = MockIFavoriteConnectionsRepository();
    when(() => favoritesStore.read(any())).thenAnswer((_) async => ConnectionFavorites.empty);
    when(() => favoritesStore.write(any(), any())).thenAnswer((_) async {});
    connections = MockIConnectionRepository();
    collapsed = MockICollapsedSectionsRepository();
    store = MockIActiveConnectionStore();
    when(() => collapsed.read()).thenAnswer((_) async => <String>{});
    when(() => collapsed.write(any())).thenAnswer((_) async {});
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    when(() => connections.listManaged()).thenAnswer((_) async => Success(_mockAnswer()));
    cubit = ActiveConnectionCubit(store: store);
  });

  tearDown(() => cubit.close());

  Finder row(String id) => find.byKey(ValueKey('connection-row-$id'));
  Finder inSheet(Finder finder) => find.descendant(of: find.byType(ConnectionSwitcherSheet), matching: finder);

  Finder header(String key) => find.byKey(ValueKey('connection-section-$key'));

  /// A page with a button that opens the switcher, as the shell's top bar does, under the app-scoped favorites of
  /// [subject], who Studio says signed in.
  Future<void> openSheet(WidgetTester tester, {String? subject = 'subject-alice'}) async {
    // Made in the test's zone, so the favorites it reads arrive while the test pumps.
    favorites = FavoriteConnectionsBloc(repository: favoritesStore)..add(FavoriteConnectionsSubjectChanged(subject));
    addTearDown(favorites.close);
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<IConnectionRepository>.value(value: connections),
          RepositoryProvider<ICollapsedSectionsRepository>.value(value: collapsed),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ActiveConnectionCubit>.value(value: cubit),
            BlocProvider<FavoriteConnectionsBloc>.value(value: favorites),
          ],
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
              body: Builder(
                builder: (context) =>
                    TextButton(onPressed: () => ConnectionSwitcherSheet.show(context), child: const Text('open')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the managed connections in their sections, with the search of the connection list', (
    tester,
  ) async {
    await openSheet(tester);

    expect(inSheet(find.text(S.current.connection_switcher_title)), findsOneWidget);
    expect(inSheet(find.byKey(const ValueKey('connection-section-group:Finance'))), findsOneWidget);
    expect(inSheet(row('seed:billing-mysql')), findsOneWidget);

    await tester.enterText(inSheet(find.byType(TextField)), 'billing');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(inSheet(row('seed:billing-mysql')), findsOneWidget);
    expect(inSheet(row('seed:sales-postgres')), findsNothing);
  });

  testWidgets('marks the active connection with a dot', (tester) async {
    cubit.select(_mockAnswer().connections.firstWhere((c) => c.id == 'seed:catalog-mongo'));
    await openSheet(tester);
    expect(tester.getSemantics(row('seed:catalog-mongo')).label, contains(S.current.connection_active));
    expect(tester.getSemantics(row('seed:billing-mysql')).label, isNot(contains(S.current.connection_active)));
  });

  testWidgets('a tap opens that connection and closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(row('seed:billing-mysql'));
    await tester.pumpAndSettle();

    expect(cubit.state, isA<ActiveConnectionSelected>().having((s) => s.connection.id, 'id', 'seed:billing-mysql'));
    expect(find.byType(ConnectionSwitcherSheet), findsNothing);
  });

  testWidgets('shows the starred connections first, in a Favorites section with their stars', (tester) async {
    when(() => favoritesStore.read('subject-alice'))
        .thenAnswer((_) async => const ConnectionFavorites(starred: {'seed:billing-mysql'}, recent: []));
    await openSheet(tester);

    final favoritesHeader = inSheet(header('favorites'));
    expect(find.descendant(of: favoritesHeader, matching: find.text(S.current.connection_favorites)), findsOneWidget);
    expect(find.descendant(of: favoritesHeader, matching: find.text('1')), findsOneWidget);
    expect(tester.getTopLeft(favoritesHeader).dy, lessThan(tester.getTopLeft(inSheet(row('seed:billing-mysql'))).dy));
    expect(
      tester.getTopLeft(inSheet(row('seed:billing-mysql'))).dy,
      lessThan(tester.getTopLeft(inSheet(header('group:Analytics'))).dy),
    );
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: inSheet(find.byKey(const ValueKey('connection-star-seed:billing-mysql'))),
              matching: find.byType(IconButton),
            ),
          )
          .tooltip,
      S.current.connection_unstar,
    );
  });

  testWidgets('shows no Favorites section and no star while no favorites can be read', (tester) async {
    when(() => favoritesStore.read(any())).thenThrow(const FormatException('not JSON'));
    await openSheet(tester);

    expect(inSheet(row('seed:billing-mysql')), findsOneWidget);
    expect(inSheet(header('favorites')), findsNothing);
    expect(inSheet(find.byKey(const ValueKey('connection-star-seed:billing-mysql'))), findsNothing);
  });

  testWidgets('a tap makes the connection the first of the recent ones', (tester) async {
    when(() => favoritesStore.read('subject-alice'))
        .thenAnswer((_) async => const ConnectionFavorites(starred: {}, recent: ['seed:sales-postgres']));
    await openSheet(tester);

    await tester.tap(row('seed:billing-mysql'));
    await tester.pumpAndSettle();

    const opened = ConnectionFavorites(starred: {}, recent: ['seed:billing-mysql', 'seed:sales-postgres']);
    expect(favorites.state, const FavoriteConnectionsReady(opened));
    verify(() => favoritesStore.write('subject-alice', opened)).called(1);
  });

  testWidgets('a list without the active connection makes it vanish', (tester) async {
    cubit.select(const StudioConnection(id: 'seed:revoked', name: 'Revoked', type: 'pg'));
    await openSheet(tester);

    expect(
      cubit.state,
      const ActiveConnectionVanished(StudioConnection(id: 'seed:revoked', name: 'Revoked', type: 'pg')),
    );
  });

  testWidgets('says when Studio offers no connection', (tester) async {
    when(() => connections.listManaged()).thenAnswer((_) async => const Success(ManagedConnections(connections: [])));
    await openSheet(tester);

    expect(inSheet(find.text(S.current.connection_list_empty)), findsOneWidget);
  });

  testWidgets('shows a failure with a retry that asks again', (tester) async {
    when(() => connections.listManaged()).thenAnswer((_) async => const Failure(ServerError('down')));
    await openSheet(tester);

    expect(inSheet(find.text(S.current.connection_list_load_failed)), findsOneWidget);

    when(() => connections.listManaged()).thenAnswer((_) async => Success(_mockAnswer()));
    await tester.tap(inSheet(find.text(S.current.refresh)));
    await tester.pumpAndSettle();

    expect(inSheet(row('seed:billing-mysql')), findsOneWidget);
  });
}
