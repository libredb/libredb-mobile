@Tags(['widget'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

import 'test_env.dart';

void main() {
  // Regression: only the first testWidgets in a file got mock responses, because rootBundle kept the asset Future that
  // test created in its FakeAsync zone (see the asset cache reset in test/flutter_test_config.dart). Two runs on
  // purpose: only the one that runs second can fail. The response is checked after pumping instead of awaited, so a
  // regression fails here at once instead of hanging until the test times out.
  group('TestEnv.apiClient', () {
    for (final run in const ['first', 'second']) {
      testWidgets('serves the mocked /auth/me in the $run testWidgets of a file', (tester) async {
        TestEnv.authenticate();

        Response<String>? response;
        unawaited(TestEnv.apiClient().get('/auth/me').then((value) => response = value));
        // Dio runs each interceptor in a Timer.run, so the request only moves while fake time does.
        await tester.pump(const Duration(seconds: 1));

        expect(response, isNotNull, reason: 'the mock request never completed');
        expect(response!.statusCode, 200);
        expect(jsonDecode(response!.data!), containsPair('authenticated', true));
      });
    }
  });

  // Every sign-out clears the share files in the temporary directory, so a test that signs out needs one.
  group('TestEnv temporary directory', () {
    test('answers a temporary directory, which the reset removes', () async {
      final temporary = await getTemporaryDirectory();
      File('${temporary.path}/left.txt').writeAsStringSync('x');

      await TestEnv.reset();

      expect(temporary.existsSync(), isFalse);
      expect((await getTemporaryDirectory()).path, isNot(temporary.path));
    });

    test('leaves the other directories unanswered, as without a mock', () async {
      await expectLater(getApplicationSupportDirectory(), throwsA(isA<MissingPluginException>()));
    });
  });
}
