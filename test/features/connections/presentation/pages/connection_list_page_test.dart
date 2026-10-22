@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_advance/core/errors/app_error.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/connections/application/connection_list_bloc.dart';
import 'package:flutter_bloc_advance/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:flutter_bloc_advance/features/connections/domain/entities/studio_connection.dart';
import 'package:flutter_bloc_advance/features/connections/presentation/pages/connection_list_page.dart';
import 'package:flutter_bloc_advance/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

void main() {
  late MockIConnectionRepository repository;

  setUp(() {
    repository = MockIConnectionRepository();
  });

  Future<void> pumpPage(WidgetTester tester, {Size size = const Size(400, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: BlocProvider(
            create: (_) => ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository)),
            child: const ConnectionListPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('asks for the connections on open and lists them', (tester) async {
    when(() => repository.listManaged()).thenAnswer(
      (_) async => const Success([
        StudioConnection(id: 'seed:sales', name: 'Sales', type: 'postgres', environment: 'production'),
        StudioConnection(id: 'seed:sample', name: 'Sample', type: 'sqlite'),
      ]),
    );

    await pumpPage(tester);

    verify(() => repository.listManaged()).called(1);
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('Sample'), findsOneWidget);
    expect(find.textContaining('postgres'), findsOneWidget);
  });

  testWidgets('shows the empty text when Studio answers no connection', (tester) async {
    when(() => repository.listManaged()).thenAnswer((_) async => const Success(<StudioConnection>[]));

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
