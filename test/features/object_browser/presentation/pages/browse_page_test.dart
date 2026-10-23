@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/object_browser/presentation/pages/browse_page.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/pick_connection_first.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _sales = StudioConnection(id: 'seed:sales-postgres', name: 'Sales (PostgreSQL)', type: 'postgres');

void main() {
  late ActiveConnectionCubit active;

  setUp(() {
    final store = MockIActiveConnectionStore();
    when(() => store.read(any())).thenAnswer((_) async => null);
    when(() => store.write(any(), any())).thenAnswer((_) async {});
    active = ActiveConnectionCubit(store: store);
    addTearDown(active.close);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<ActiveConnectionCubit>.value(
        value: active,
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: const Scaffold(body: BrowsePage()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('asks the user to pick a connection while none is open', (tester) async {
    await pumpPage(tester);

    expect(find.byType(PickConnectionFirst), findsOneWidget);
    expect(find.text(S.current.browse_not_available_yet), findsNothing);
  });

  testWidgets('never asks for a connection while one is open, and says browsing is not there yet', (tester) async {
    active.select(_sales);
    await pumpPage(tester);

    expect(find.byType(PickConnectionFirst), findsNothing);
    expect(find.text(S.current.pick_connection_first_description), findsNothing);
    expect(find.text(S.current.browse_not_available_yet), findsOneWidget);
  });

  testWidgets('asks for a connection again once the open one vanishes', (tester) async {
    active.select(_sales);
    await pumpPage(tester);

    active.connectionsListed(const []);
    // One pump delivers the cubit's change, the next builds it.
    await tester.pump();
    await tester.pump();

    expect(find.byType(PickConnectionFirst), findsOneWidget);
  });
}
