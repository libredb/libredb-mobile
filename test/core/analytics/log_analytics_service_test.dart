import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/analytics/log_analytics_service.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/printed_lines.dart';

void main() {
  late LogAnalyticsService service;

  setUpAll(() {
    AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);
  });

  setUp(() {
    service = LogAnalyticsService();
  });

  group('LogAnalyticsService', () {
    test('implements IAnalyticsService', () {
      expect(service, isA<IAnalyticsService>());
    });

    group('logScreenView', () {
      test('does not throw with screenName only', () {
        expect(() => service.logScreenView(screenName: 'HomeScreen'), returnsNormally);
      });

      test('does not throw with screenName and screenClass', () {
        expect(() => service.logScreenView(screenName: 'HomeScreen', screenClass: 'HomePage'), returnsNormally);
      });

      test('does not throw with empty screenName', () {
        expect(() => service.logScreenView(screenName: ''), returnsNormally);
      });
    });

    group('logEvent', () {
      test('does not throw with name only', () {
        expect(() => service.logEvent(name: 'button_click'), returnsNormally);
      });

      test('does not throw with name and parameters', () {
        expect(
          () => service.logEvent(name: 'button_click', parameters: {'button_id': 'submit', 'count': 1}),
          returnsNormally,
        );
      });

      test('does not throw with null parameters', () {
        expect(() => service.logEvent(name: 'event', parameters: null), returnsNormally);
      });

      test('does not throw with empty parameters', () {
        expect(() => service.logEvent(name: 'event', parameters: {}), returnsNormally);
      });
    });

    group('logUserAction', () {
      test('does not throw with action only', () {
        expect(() => service.logUserAction(action: 'tap'), returnsNormally);
      });

      test('does not throw with action and target', () {
        expect(() => service.logUserAction(action: 'tap', target: 'login_button'), returnsNormally);
      });

      test('does not throw with all parameters', () {
        expect(
          () => service.logUserAction(action: 'tap', target: 'login_button', parameters: {'page': 'login'}),
          returnsNormally,
        );
      });

      test('does not throw with null target and null parameters', () {
        expect(() => service.logUserAction(action: 'tap', target: null, parameters: null), returnsNormally);
      });
    });

    group('setUserId', () {
      test('does not throw with a valid userId', () {
        expect(() => service.setUserId('user-123'), returnsNormally);
      });

      test('does not throw with null userId', () {
        expect(() => service.setUserId(null), returnsNormally);
      });

      test('does not throw with empty userId', () {
        expect(() => service.setUserId(''), returnsNormally);
      });
    });

    group('setUserProperty', () {
      test('does not throw with name and value', () {
        expect(() => service.setUserProperty(name: 'role', value: 'admin'), returnsNormally);
      });

      test('does not throw with null value', () {
        expect(() => service.setUserProperty(name: 'role', value: null), returnsNormally);
      });

      test('does not throw with empty name', () {
        expect(() => service.setUserProperty(name: '', value: 'admin'), returnsNormally);
      });
    });

    group('logError', () {
      test('does not throw with error only', () {
        expect(() => service.logError(error: Exception('test error')), returnsNormally);
      });

      test('does not throw with error and reason', () {
        expect(() => service.logError(error: Exception('test error'), reason: 'network failure'), returnsNormally);
      });

      test('does not throw with error and stackTrace', () {
        final stackTrace = StackTrace.current;
        expect(() => service.logError(error: Exception('test error'), stackTrace: stackTrace), returnsNormally);
      });

      test('does not throw with all parameters', () {
        final stackTrace = StackTrace.current;
        expect(
          () => service.logError(error: Exception('test error'), stackTrace: stackTrace, reason: 'network failure'),
          returnsNormally,
        );
      });

      test('does not throw with string error', () {
        expect(() => service.logError(error: 'simple string error'), returnsNormally);
      });

      test('does not throw with null stackTrace and null reason', () {
        expect(() => service.logError(error: 'error', stackTrace: null, reason: null), returnsNormally);
      });

      // The header that an obfuscated release build (--obfuscate --split-debug-info) prints before the first frame.
      const obfuscatedHeader = [
        '*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***',
        'pid: 4361, tid: 4404, name 1.ui',
        'os: android arch: arm64 comp: yes sim: no',
        "build_id: '6d4b5d2c8a9f1e7b3c2a1d0e9f8b7a6c'",
        'isolate_dso_base: 7a2c4b6000, vm_dso_base: 7a2c4b6000',
        'isolate_instructions: 7a2c5d1000, vm_instructions: 7a2c5c4000',
      ];

      String obfuscatedFrame(int index) =>
          '    #${index.toString().padLeft(2, '0')} abs 0000007a2c6e5f2b virt 000000000022ff2b '
          '_kDartIsolateSnapshotInstructions+0x11ef2b';

      // The printed stack trace line, joined, after the non_fatal_error line that serves as a positive control.
      Future<String> printedStack(StackTrace stackTrace) async {
        final printed = await printedLines(() => service.logError(error: Exception('boom'), stackTrace: stackTrace));
        expect(printed.where((line) => line.contains('non_fatal_error: Exception: boom')), hasLength(1));
        final stack = printed.join('\n');
        expect(stack, contains('stack_trace: '));
        return stack.substring(stack.indexOf('stack_trace: '));
      }

      test('keeps the build id and the first frames after an obfuscated header', () async {
        final trace = [...obfuscatedHeader, for (var i = 0; i < 30; i++) obfuscatedFrame(i)].join('\n');

        final stack = await printedStack(StackTrace.fromString(trace));

        for (final line in obfuscatedHeader) {
          expect(stack, contains(line));
        }
        for (var i = 0; i < 10; i++) {
          expect(stack, contains(obfuscatedFrame(i)));
        }
        expect(stack, isNot(contains(obfuscatedFrame(10))));
      });

      test('keeps the first frames of a symbolic stack trace', () async {
        final trace = [for (var i = 0; i < 30; i++) '#$i      frame$i (package:libredb_mobile/a.dart:$i:1)'].join('\n');

        final stack = await printedStack(StackTrace.fromString(trace));

        for (var i = 0; i < 10; i++) {
          expect(stack, contains('frame$i '));
        }
        expect(stack, isNot(contains('frame10 ')));
      });

      test('bounds a stack trace without frame lines', () async {
        final trace = [for (var i = 0; i < 30; i++) 'line$i end'].join('\n');

        final stack = await printedStack(StackTrace.fromString(trace));

        expect(stack, contains('line0 end'));
        expect(stack, isNot(contains('line29 end')));
      });

      test('masks a secret in a kept stack line', () async {
        final trace = [...obfuscatedHeader, 'Bearer eyJhbGciOiJSUzI1NiJ9.e30.c2ln', obfuscatedFrame(0)].join('\n');

        final stack = await printedStack(StackTrace.fromString(trace));

        expect(stack, contains(obfuscatedFrame(0)));
        expect(stack, isNot(contains('eyJhbGciOiJSUzI1NiJ9')));
      });
    });
  });
}
