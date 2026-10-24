import 'dart:convert';

import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/core/security/security_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  group('SecurityUtils', () {
    group('hasToken', () {
      test('returns false for null', () {
        expect(SecurityUtils.hasToken(null), isFalse);
      });

      test('returns false for empty', () {
        expect(SecurityUtils.hasToken(''), isFalse);
      });

      test('returns true for non-empty', () {
        expect(SecurityUtils.hasToken('MOCK_TOKEN'), isTrue);
      });
    });

    group('getTokenExpiration', () {
      test('returns null for invalid token', () {
        expect(SecurityUtils.getTokenExpiration('invalid'), isNull);
      });

      test('returns null for token without exp claim', () {
        final payload = base64Url.encode('{"sub":"test"}'.codeUnits);
        expect(SecurityUtils.getTokenExpiration('header.$payload.signature'), isNull);
      });

      test('returns DateTime for valid token', () {
        final future = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
        final payload = base64Url.encode('{"exp":$future}'.codeUnits);
        final result = SecurityUtils.getTokenExpiration('header.$payload.signature');
        expect(result, isNotNull);
        expect(result!.millisecondsSinceEpoch ~/ 1000, future);
      });
    });

    // Regression: a three-part access token that is not a JWT failed to parse with a FormatException whose text
    // quotes the decoded middle part, or the encoded one when it is not base64url, and getTokenExpiration logged that
    // text at error level, which every build of main_prod prints.
    group('log output for a token that is not a JWT', () {
      late List<String> lines;

      setUp(() {
        AppLogger.configure(isProduction: true);
        lines = [];
        void collect(OutputEvent event) => lines.addAll(event.lines);
        Logger.addOutputListener(collect);
        addTearDown(() => Logger.removeOutputListener(collect));
      });

      tearDown(() => AppLogger.configure(isProduction: false));

      for (final (shape, middle) in [
        ('is not JSON', base64Url.encode(utf8.encode('opaque-middle-SECRET-segment')).replaceAll('=', '')),
        ('is not base64url', 'opaque*middle*SECRET*segment'),
      ]) {
        test('logs the failure without the token when the middle part $shape', () {
          final token = 'part1SECRET.$middle.part3SECRET';

          expect(SecurityUtils.getTokenExpiration(token), isNull);

          expect(lines, hasLength(1));
          expect(lines, everyElement(allOf(contains('FormatException'), isNot(contains('SECRET')))));
        });
      }
    });
  });
}
