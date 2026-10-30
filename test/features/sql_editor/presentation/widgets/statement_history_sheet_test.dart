@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/sql_editor/domain/entities/statement_history_entry.dart';
import 'package:libredb_mobile/features/sql_editor/domain/repositories/statement_history_repository.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/statement_history_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mock_classes.dart';

const _account = 'account-hash';
const _sales = 'seed:sales';

StatementHistoryEntry _entry(
  String id,
  String? text, {
  String connectionId = _sales,
  String connectionName = 'Sales',
  StatementRunStatus status = StatementRunStatus.success,
  int? rowCount,
}) => StatementHistoryEntry(
  id: id,
  connectionId: connectionId,
  connectionName: connectionName,
  text: text,
  textTooLong: text == null,
  status: status,
  duration: const Duration(milliseconds: 12),
  rowCount: rowCount,
  executedAt: DateTime.utc(2026, 10, 23, 12),
);

final _orders = _entry('4', 'SELECT * FROM orders', rowCount: 3);
final _invoices = _entry('3', 'SELECT * FROM invoices', connectionId: 'seed:billing', connectionName: 'Billing');
final _failed = _entry('2', 'SELECT * FROM missing', status: StatementRunStatus.failure);
final _tooLong = _entry('1', null);

void main() {
  late MockIStatementHistoryRepository repository;
  late List<StatementHistoryEntry?> picked;

  setUp(() {
    repository = MockIStatementHistoryRepository();
    picked = [];
  });

  void answerRead(Result<List<StatementHistoryEntry>> answer) =>
      when(() => repository.read(_account)).thenAnswer((_) async => answer);

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<IStatementHistoryRepository>.value(
        value: repository,
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked.add(
                  await showStatementHistorySheet(context, subjectHash: _account, activeConnectionId: _sales),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder entry(StatementHistoryEntry entry) => find.byKey(StatementHistorySheet.entryKey(entry.id));

  testWidgets('says that nothing ran yet on an empty history', (tester) async {
    answerRead(const Success([]));
    await open(tester);

    expect(find.text('History'), findsOneWidget);
    expect(find.text('No statements yet'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(StatementHistorySheet.clearAllKey)).enabled, isFalse);
  });

  testWidgets('shows the open connection by default, and every connection with the switch', (tester) async {
    answerRead(Success([_orders, _invoices, _failed]));
    await open(tester);

    expect(entry(_orders), findsOneWidget);
    expect(entry(_failed), findsOneWidget);
    expect(entry(_invoices), findsNothing);
    expect(find.textContaining('3 rows'), findsOneWidget);

    await tester.tap(find.byKey(StatementHistorySheet.allConnectionsKey));
    await tester.pumpAndSettle();

    expect(entry(_invoices), findsOneWidget);
    expect(find.textContaining('Billing'), findsOneWidget);
  });

  testWidgets('a failed run says Failed and nothing of the database', (tester) async {
    answerRead(Success([_failed]));
    await open(tester);

    expect(find.descendant(of: entry(_failed), matching: find.textContaining('Failed')), findsOneWidget);
    expect(find.textContaining('does not exist'), findsNothing);
  });

  testWidgets('the search and the status filter narrow the list', (tester) async {
    answerRead(Success([_orders, _failed]));
    await open(tester);

    await tester.enterText(find.byType(TextField), 'ORDERS');
    await tester.pumpAndSettle();
    expect(entry(_orders), findsOneWidget);
    expect(entry(_failed), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Failed'));
    await tester.pumpAndSettle();
    expect(entry(_orders), findsNothing);
    expect(entry(_failed), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Succeeded'));
    await tester.pumpAndSettle();
    expect(entry(_orders), findsOneWidget);
    expect(entry(_failed), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like it');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches the filter.'), findsOneWidget);
  });

  testWidgets('a swipe deletes one entry', (tester) async {
    answerRead(Success([_orders, _failed]));
    when(() => repository.delete(_account, _orders.id)).thenAnswer((_) async => const Success(null));
    await open(tester);

    await tester.drag(entry(_orders), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(entry(_orders), findsNothing);
    expect(entry(_failed), findsOneWidget);
    verify(() => repository.delete(_account, _orders.id)).called(1);
  });

  testWidgets('a swipe whose delete the store refuses at once keeps the entry and says why', (tester) async {
    answerRead(Success([_orders, _failed]));
    when(() => repository.delete(_account, _orders.id))
        .thenAnswer((_) async => const Failure(UnknownError('io', code: 'editor.saved_text_not_stored')));
    await open(tester);

    await tester.drag(entry(_orders), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(entry(_orders), findsOneWidget);
    expect(
      find.text('This phone could not save the statement text. Check its free storage and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('Clear all asks first, and a cancel keeps the history', (tester) async {
    answerRead(Success([_orders]));
    when(() => repository.clear(_account)).thenAnswer((_) async => const Success(null));
    await open(tester);

    await tester.tap(find.byKey(StatementHistorySheet.clearAllKey));
    await tester.pumpAndSettle();
    expect(find.text('Clear the history?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.clear(any()));
    expect(entry(_orders), findsOneWidget);

    await tester.tap(find.byKey(StatementHistorySheet.clearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear all'));
    await tester.pumpAndSettle();

    verify(() => repository.clear(_account)).called(1);
    expect(find.text('No statements yet'), findsOneWidget);
  });

  testWidgets('a tap on a kept entry answers it, of another connection too; one too long to keep answers nothing', (
    tester,
  ) async {
    answerRead(Success([_orders, _invoices, _tooLong]));
    await open(tester);
    await tester.tap(find.byKey(StatementHistorySheet.allConnectionsKey));
    await tester.pumpAndSettle();

    expect(find.text('Too long to keep'), findsOneWidget);
    await tester.tap(entry(_tooLong));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(entry(_invoices));
    await tester.pumpAndSettle();

    expect(picked, [_invoices]);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('a tap on an entry of the open connection answers it', (tester) async {
    answerRead(Success([_orders]));
    await open(tester);

    await tester.tap(entry(_orders));
    await tester.pumpAndSettle();

    expect(picked, [_orders]);
  });

  testWidgets('a history that cannot be read offers Discard behind a confirmation', (tester) async {
    answerRead(const Failure(UnknownError('Could not read', code: 'editor.saved_text_unreadable')));
    when(() => repository.clear(_account)).thenAnswer((_) async => const Success(null));
    await open(tester);

    expect(find.textContaining('cannot be read'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard the saved text?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard').last);
    await tester.pumpAndSettle();

    verify(() => repository.clear(_account)).called(1);
    expect(find.text('No statements yet'), findsOneWidget);
  });

  testWidgets('closing the sheet answers nothing', (tester) async {
    answerRead(Success([_orders]));
    await open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(picked, [null]);
  });

  testWidgets('on a phone with a home indicator the last entry scrolls clear of it', (tester) async {
    // The ListView takes MediaQuery.padding by itself; this guards that the sheet keeps it.
    // 34 logical points, as FakeViewPadding takes physical pixels.
    final inset = 34 * tester.view.devicePixelRatio;
    tester.view.viewPadding = FakeViewPadding(bottom: inset);
    tester.view.padding = FakeViewPadding(bottom: inset);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    answerRead(Success([for (var i = 0; i < 30; i++) _entry('many-$i', 'SELECT $i')]));
    await open(tester);

    final list = find.byType(ListView);
    for (var i = 0; i < 10; i++) {
      await tester.drag(list, const Offset(0, -2000));
      await tester.pumpAndSettle();
    }

    final last = tester.getBottomLeft(find.byType(Dismissible).last).dy;
    expect(last, lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio - 34));
  });

  group('with the keyboard up', () {
    // The keyboard covers the foot of the screen: viewInsets.bottom is its height, padding.bottom shrinks to zero and
    // viewPadding.bottom keeps the home indicator.
    const keyboard = 300.0;

    Future<double> openWithKeyboard(WidgetTester tester) async {
      final dpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(390 * dpr, 844 * dpr);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.viewPadding = FakeViewPadding(bottom: 34 * dpr);
      addTearDown(tester.view.resetViewPadding);
      answerRead(Success([for (var i = 0; i < 30; i++) _entry('many-$i', 'SELECT $i')]));
      await open(tester);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      return tester.view.physicalSize.height / dpr - keyboard;
    }

    testWidgets('the last entry scrolls above the keyboard', (tester) async {
      final keyboardTop = await openWithKeyboard(tester);

      final list = find.byType(ListView);
      for (var i = 0; i < 10; i++) {
        await tester.drag(list, const Offset(0, -2000));
        await tester.pumpAndSettle();
      }

      expect(tester.getBottomLeft(find.byType(Dismissible).last).dy, lessThanOrEqualTo(keyboardTop));
    });

    testWidgets('the search field stays above the keyboard', (tester) async {
      final keyboardTop = await openWithKeyboard(tester);

      expect(tester.getBottomLeft(find.byType(TextField)).dy, lessThanOrEqualTo(keyboardTop));
    });
  });
}
