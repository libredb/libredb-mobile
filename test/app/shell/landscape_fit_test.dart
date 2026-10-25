@Tags(['widget'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_view.dart';
import 'package:libredb_mobile/features/object_browser/data/models/object_browser_json.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/key_browser_list.dart';
import 'package:libredb_mobile/infrastructure/studio/query_result_json.dart';
import 'package:libredb_mobile/shared/models/query_page.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/object_browser/browse_answers.dart';
import '../../features/object_browser/browse_harness.dart';
import '../../features/object_browser/result_scroll.dart';
import '../../support/test_env.dart';

// #177: a phone held sideways shows at least three rows or entries at open on the pages whose header is fixed.
// Real fonts, so that a line wraps where it wraps on a phone: the test font draws every glyph as wide as it is tall,
// which wraps a sentence that fits on one line in Roboto. The fonts stay registered for this isolate only, which is why
// these tests have a file of their own.

String get _materialFonts {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('FLUTTER_ROOT is not set. Run this test with flutter test.');
  return '$root/bin/cache/artifacts/material_fonts';
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('$_materialFonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// How many of the widgets [items] finds lie whole inside the on-screen part of the scrollable [list].
int _wholeIn(WidgetTester tester, Finder list, Finder items) {
  final view = tester.view;
  final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  final shown = tester.getRect(list).intersect(screen);
  return items
      .evaluate()
      .map((item) => tester.getRect(find.byElementPredicate((candidate) => candidate == item)))
      .where((item) => item.top >= shown.top && item.bottom <= shown.bottom)
      .length;
}

/// Answers every asset from the bundle the test runner built, and each mock answer of [answers], by its asset key, with
/// its text. It reads the files synchronously, since an asset read that waits on real I/O never completes inside the
/// test's fake clock.
void _serveAssets(WidgetTester tester, {Map<String, String> answers = const {}}) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
    if (answers[key] case final answer?) return ByteData.sublistView(Uint8List.fromList(utf8.encode(answer)));
    final file = File('build/unit_test_assets/$key');
    return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
  });
  addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
}

void main() {
  setUpAll(() async {
    await _load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Italic.ttf']);
    await _load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  });

  group('the connection list', () {
    Future<void> pumpList(WidgetTester tester) async {
      sideways(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();
      (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).go(
        ApplicationRoutesConstants.connectionList,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    int wholeRows(WidgetTester tester) =>
        _wholeIn(tester, find.byKey(const ValueKey('connection-sections')), find.byType(ConnectionRow));

    // The list the dev stack's Studio answers (tool/studio-dev), as #177 measured it: five connections in one group.
    final devStack = File('test/fixtures/studio/managed_postgres.json').readAsStringSync();
    const managedKey = 'assets/mock/GET_connections_managed.json';

    testWidgets('shows three whole connections at open', (tester) async {
      _serveAssets(
        tester,
        answers: {
          managedKey: devStack,
          'assets/mock/GET_connections_policy.json': jsonEncode({
            'customConnections': false,
            'governance': false,
            'statementCapture': 'off',
          }),
        },
      );
      await pumpList(tester);

      expect(find.byType(StatementCaptureNote), findsNothing);
      expect(wholeRows(tester), greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows two whole connections at open under the statement capture note, which stays', (tester) async {
      _serveAssets(tester, answers: {managedKey: devStack});
      await pumpList(tester);

      expect(find.byType(StatementCaptureNote), findsOneWidget);
      expect(wholeRows(tester), greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'with the keyboard up, the connection list keeps the whole capture note and the top of the search above it',
    (tester) async {
      _serveAssets(tester);
      sideways(tester);
      TestEnv.authenticate();
      await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en'));
      await tester.pumpAndSettle();
      (tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter).go(
        ApplicationRoutesConstants.connectionList,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      await tester.showKeyboard(find.byType(TextField));
      // As on the device: the keyboard covers the gesture bar, so the bottom padding goes.
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewInsets = const FakeViewPadding(bottom: 255);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      const aboveKeyboard = 393.0 - 255;
      final note = tester.getRect(find.byType(StatementCaptureNote));
      expect(note.bottom, lessThanOrEqualTo(aboveKeyboard));
      final field = tester.getRect(find.byType(TextField));
      expect(field.top, greaterThanOrEqualTo(note.bottom));
      expect(field.top, lessThan(aboveKeyboard), reason: 'the top edge of the search stays above the keyboard');
    },
  );

  group('Browse', () {
    late BrowseHarness harness;

    setUp(() => harness = BrowseHarness());

    testWidgets('the rows page shows three whole rows of the table at open', (tester) async {
      const preview = 'SELECT * FROM sales.ledger;';
      harness.answerMeta('seed:dev-postgres', metaAnswer('meta_postgres'));
      when(
        () => harness.statements.run(
          'seed:dev-postgres',
          preview,
          queryId: any(named: 'queryId'),
          page: const QueryPage(limit: 50),
          catalog: any(named: 'catalog'),
          cancelSignal: any(named: 'cancelSignal'),
        ),
      ).thenAnswer(
        (_) async => Success(
          QueryResultJson.read(File('test/fixtures/studio/query_page_postgres_first.json').readAsStringSync()),
        ),
      );
      sideways(tester);
      await harness.pump(
        tester,
        location: Uri(
          path: '/browse/seed%3Adev-postgres/rows/table',
          queryParameters: {
            'path': ['sales', 'ledger'],
          },
        ).toString(),
      );
      await tester.tap(find.byTooltip('Table'));
      await tester.pumpAndSettle();

      expect(find.text('Count rows'), findsOneWidget);
      expect(find.text('Load 50 more'), findsOneWidget);
      expect(fullyShownTableRows(tester), greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the key browser shows three whole key groups at open', (tester) async {
      harness.answerMeta('seed:dev-redis', metaAnswer('meta_redis'));
      // The first page of a walk that is not done, with keys under five prefixes.
      final keys = [
        for (final prefix in ['cache', 'order', 'queue', 'session', 'user'])
          for (var n = 1; n <= 2; n++) '$prefix:$n',
      ];
      final page = ObjectBrowserJson.keyScanPage(
        jsonEncode({
          'keys': keys,
          'cursor': '406',
          'total': 1207,
          'types': {for (final key in keys) key: 'string'},
          'clustered': false,
        }),
      );
      when(
        () => harness.repository.scanKeys(
          any(),
          cursor: any(named: 'cursor'),
          pattern: any(named: 'pattern'),
          count: any(named: 'count'),
          database: any(named: 'database'),
          level: any(named: 'level'),
        ),
      ).thenAnswer((_) async => Success(page));
      sideways(tester);
      await harness.pump(tester, location: '/browse/seed%3Adev-redis/keys?container=1');

      expect(find.text('Load more'), findsOneWidget);
      expect(
        _wholeIn(
          tester,
          find.byType(KeyBrowserList),
          find.descendant(of: find.byType(KeyBrowserList), matching: find.byType(ListTile)),
        ),
        greaterThanOrEqualTo(3),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
