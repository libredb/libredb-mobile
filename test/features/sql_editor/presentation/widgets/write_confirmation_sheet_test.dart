@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/sql_editor/domain/interim_write_check.dart';
import 'package:libredb_mobile/features/sql_editor/presentation/widgets/write_confirmation_sheet.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/studio_access.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';

import '../../../../support/printed_lines.dart';

const _development = StudioConnection(
  id: 'seed:dev-postgres',
  name: 'Dev Postgres',
  type: 'postgres',
  environment: 'development',
);

const _production = StudioConnection(
  id: 'seed:sales-prod',
  name: 'Sales Prod',
  type: 'postgres',
  environment: 'production',
);

const _deleteAnswer = AsksBeforeRunning(
  reasons: {WriteCheckReason.mayWrite, WriteCheckReason.severalStatements},
  flaggedWord: FlaggedWord(word: 'DELETE', line: 3),
);

const _text = 'SELECT 1;\nSELECT 2;\nDELETE FROM orders WHERE false';

/// The answer each opening of the sheet gave, in order.
final _answers = <WriteConfirmation>[];

Future<void> _open(
  WidgetTester tester, {
  StudioConnection connection = _development,
  String text = _text,
  AsksBeforeRunning answer = _deleteAnswer,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
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
            onPressed: () async => _answers.add(
              await showWriteConfirmationSheet(context, connection: connection, text: text, answer: answer),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

S get _s => S.current;

Finder get _run => find.widgetWithText(FilledButton, _s.write_confirm_run);

bool _runEnabled(WidgetTester tester) => tester.widget<FilledButton>(_run).onPressed != null;

Finder get _nameField => find.byKey(WriteConfirmationSheet.nameFieldKey);

void main() {
  setUp(_answers.clear);

  group('on a development connection', () {
    testWidgets('shows the name, the environment, every reason with the word and its line, and every line', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text(_s.write_confirm_title), findsOneWidget);
      expect(find.text('Dev Postgres'), findsOneWidget);
      expect(find.byType(EnvironmentBadge), findsOneWidget);
      expect(find.text(_s.write_confirm_reason_may_write_at('DELETE', 3)), findsOneWidget);
      expect(find.text(_s.write_confirm_reason_several), findsOneWidget);
      expect(find.text(_s.write_confirm_reason_not_sql), findsNothing);
      expect(find.text('SELECT 1;'), findsOneWidget);
      expect(find.text('SELECT 2;'), findsOneWidget);
      expect(find.text('DELETE FROM orders WHERE false'), findsOneWidget);
      expect(_nameField, findsNothing);
      expect(find.text(_s.write_confirm_read_grant), findsNothing);
      expect(find.text(_s.write_confirm_read_only_connection), findsNothing);
    });

    testWidgets('Run answers confirmed and closes the sheet', (tester) async {
      await _open(tester);
      expect(_runEnabled(tester), isTrue);

      await tester.tap(_run);
      await tester.pumpAndSettle();

      expect(_answers, [WriteConfirmation.confirmed]);
      expect(find.byType(WriteConfirmationSheet), findsNothing);
    });

    testWidgets('Cancel answers cancelled', (tester) async {
      await _open(tester);

      await tester.tap(find.widgetWithText(TextButton, _s.write_confirm_cancel));
      await tester.pumpAndSettle();

      expect(_answers, [WriteConfirmation.cancelled]);
      expect(find.byType(WriteConfirmationSheet), findsNothing);
    });

    testWidgets('a sheet closed with the back gesture answers cancelled', (tester) async {
      await _open(tester);

      // The sheet is full height, so the barrier is out of reach: close it as the system back gesture does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_answers, [WriteConfirmation.cancelled]);
    });

    testWidgets('a text without a flagged word says may write without a word, and not SQL says so', (tester) async {
      await _open(
        tester,
        text: '/* open comment SELECT 1',
        answer: const AsksBeforeRunning(reasons: {WriteCheckReason.mayWrite}),
      );
      expect(find.text(_s.write_confirm_reason_may_write), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, _s.write_confirm_cancel));
      await tester.pumpAndSettle();

      await _open(
        tester,
        text: 'GET k',
        answer: const AsksBeforeRunning(reasons: {WriteCheckReason.notSql}),
      );
      expect(find.text(_s.write_confirm_reason_not_sql), findsOneWidget);
      expect(find.text(_s.write_confirm_reason_may_write), findsNothing);
      expect(find.text('GET k'), findsOneWidget);
    });

    testWidgets('a bare carriage return starts a line of its own, so the hidden statement shows', (tester) async {
      await _open(tester, text: 'SELECT 1 -- x\r; DELETE FROM t');

      expect(find.text('SELECT 1 -- x'), findsOneWidget);
      expect(find.text('; DELETE FROM t'), findsOneWidget);
    });
  });

  group('the lines of the text', () {
    testWidgets('are built lazily, and the last of 20,000 lines can be scrolled to', (tester) async {
      final text = [for (var i = 1; i <= 20000; i++) 'SELECT $i AS line_$i'].join('\n');
      await _open(tester, text: text);

      expect(find.text('SELECT 1 AS line_1'), findsOneWidget);
      expect(find.text('SELECT 20000 AS line_20000'), findsNothing);
      expect(find.text('SELECT 10000 AS line_10000'), findsNothing);

      final list = find.byKey(WriteConfirmationSheet.linesKey);
      final scrollable = find.descendant(of: list, matching: find.byType(Scrollable));
      for (var i = 0; i < 20 && find.text('SELECT 20000 AS line_20000').evaluate().isEmpty; i++) {
        final position = tester.state<ScrollableState>(scrollable).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
      }

      expect(find.text('SELECT 20000 AS line_20000'), findsOneWidget);
      expect(find.text('20000'), findsOneWidget);
    });
  });

  group('on a production connection', () {
    testWidgets('the header is in the error colour and Run stays disabled until the exact name is typed', (
      tester,
    ) async {
      await _open(tester, connection: _production);
      final context = tester.element(find.byType(WriteConfirmationSheet));
      final error = Theme.of(context).colorScheme.error;

      expect(tester.widget<Text>(find.text(_s.write_confirm_title)).style?.color, error);
      expect(find.text(_s.write_confirm_production_prompt), findsOneWidget);
      expect(find.text(_s.write_confirm_name_label('Sales Prod')), findsOneWidget);
      expect(_runEnabled(tester), isFalse);

      await tester.enterText(_nameField, 'sales prod');
      await tester.pump();
      expect(_runEnabled(tester), isFalse, reason: 'another letter case');

      await tester.enterText(_nameField, 'Sales Prod ');
      await tester.pump();
      expect(_runEnabled(tester), isFalse, reason: 'a trailing space');

      await tester.enterText(_nameField, ' Sales Prod');
      await tester.pump();
      expect(_runEnabled(tester), isFalse, reason: 'a leading space');

      await tester.enterText(_nameField, '');
      await tester.pump();
      expect(_runEnabled(tester), isFalse, reason: 'an empty field');

      await tester.enterText(_nameField, 'Sales Prod');
      await tester.pump();
      expect(_runEnabled(tester), isTrue);

      await tester.tap(_run);
      await tester.pumpAndSettle();
      expect(_answers, [WriteConfirmation.confirmed]);
    });

    testWidgets('the field turns autocorrect, suggestions, capitalisation and smart punctuation off', (tester) async {
      await _open(tester, connection: _production);

      final field = tester.widget<TextField>(_nameField);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.textCapitalization, TextCapitalization.none);
      expect(field.smartDashesType, SmartDashesType.disabled);
      expect(field.smartQuotesType, SmartQuotesType.disabled);
      expect(field.spellCheckConfiguration, const SpellCheckConfiguration.disabled());
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.autofillHints, isEmpty);
    });

    testWidgets('the field is empty each time the sheet opens', (tester) async {
      await _open(tester, connection: _production);
      await tester.enterText(_nameField, 'Sales Prod');
      await tester.tap(find.widgetWithText(TextButton, _s.write_confirm_cancel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_nameField).controller!.text, isEmpty);
      expect(_runEnabled(tester), isFalse);
    });

    testWidgets('a production connection without a name shows the sentence and never enables Run', (tester) async {
      await _open(
        tester,
        connection: const StudioConnection(id: 'seed:x', name: '', type: 'postgres', environment: 'production'),
      );

      expect(find.text(_s.write_confirm_no_name), findsOneWidget);
      expect(_nameField, findsNothing);
      expect(_runEnabled(tester), isFalse);
    });

    testWidgets('applies to a statement that asks only because the engine is not SQL', (tester) async {
      await _open(
        tester,
        connection: const StudioConnection(id: 'seed:cache', name: 'Cache', type: 'redis', environment: 'production'),
        text: 'GET k',
        answer: const AsksBeforeRunning(reasons: {WriteCheckReason.notSql}),
      );

      expect(_runEnabled(tester), isFalse);
      await tester.enterText(_nameField, 'Cache');
      await tester.pump();
      expect(_runEnabled(tester), isTrue);
    });
  });

  group('on a connection Studio refuses writes on', () {
    testWidgets('a read grant says an administrator can raise it', (tester) async {
      await _open(tester, connection: _development.copyWithAccess(StudioAccess.read));

      expect(find.text(_s.write_confirm_read_grant), findsOneWidget);
      expect(find.text(_s.write_confirm_read_only_connection), findsNothing);
    });

    testWidgets('a connection marked read only says it is the operator setting', (tester) async {
      await _open(
        tester,
        connection: const StudioConnection(id: 'seed:ro', name: 'RO', type: 'postgres', readOnly: true),
      );

      expect(find.text(_s.write_confirm_read_only_connection), findsOneWidget);
      expect(find.text(_s.write_confirm_read_grant), findsNothing);
      expect(find.byType(EnvironmentBadge), findsNothing);
    });

    testWidgets('a write grant on a connection that is not read only shows no refusal line', (tester) async {
      await _open(tester, connection: _development.copyWithAccess(StudioAccess.write));

      expect(find.text(_s.write_confirm_read_only_connection), findsNothing);
      expect(find.text(_s.write_confirm_read_grant), findsNothing);
    });
  });

  testWidgets('shows its texts in Turkish', (tester) async {
    await _open(tester, connection: _production.copyWithAccess(StudioAccess.read), locale: const Locale('tr'));

    expect(find.text('Çalıştırmadan önce onaylayın'), findsOneWidget);
    expect(find.text('Veriyi değiştirebilir: 3. satırda DELETE'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Confirm before running'), findsNothing);
  });

  testWidgets('the sheet logs nothing', (tester) async {
    final lines = await printedLines(() async {
      await _open(tester, connection: _production);
      await tester.enterText(_nameField, 'Sales Prod');
      await tester.pump();
      await tester.tap(_run);
      await tester.pumpAndSettle();
    });

    expect(lines, isEmpty);
  });
}

extension on StudioConnection {
  StudioConnection copyWithAccess(StudioAccess access) =>
      StudioConnection(id: id, name: name, type: type, environment: environment, readOnly: readOnly, access: access);
}
