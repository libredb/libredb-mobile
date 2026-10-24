import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/core/security/screen_capture_platform.dart';
import 'package:libredb_mobile/core/security/screen_capture_protection.dart';

import '../../support/printed_lines.dart';

/// Records what the protection asks of the platform; [failWith] makes every call throw.
final class _RecordingPlatform implements IScreenCapturePlatform {
  final calls = <String>[];
  Object? failWith;

  @override
  Future<void> protectOn() async {
    calls.add('on');
    if (failWith case final error?) throw error;
  }

  @override
  Future<void> protectOff() async {
    calls.add('off');
    if (failWith case final error?) throw error;
  }
}

void main() {
  late _RecordingPlatform platform;
  late ScreenCaptureProtection protection;

  setUp(() {
    platform = _RecordingPlatform();
    protection = ScreenCaptureProtection(platform: platform, enabled: true);
  });

  group('ScreenCaptureProtection', () {
    test('starts with no lease and protection off', () {
      expect(protection.leases, 0);
      expect(protection.isEngaged, isFalse);
      expect(platform.calls, isEmpty);
    });

    test('the first lease turns protection on', () async {
      await protection.acquire();
      expect(protection.leases, 1);
      expect(protection.isEngaged, isTrue);
      expect(platform.calls, ['on']);
    });

    test('a second lease only counts', () async {
      await protection.acquire();
      await protection.acquire();
      expect(protection.leases, 2);
      expect(platform.calls, ['on']);
    });

    test('nested leases: protection stays on until the last lease is released', () async {
      await protection.acquire();
      await protection.acquire();
      await protection.release();
      expect(protection.isEngaged, isTrue);
      expect(platform.calls, ['on']);

      await protection.release();
      expect(protection.leases, 0);
      expect(protection.isEngaged, isFalse);
      expect(platform.calls, ['on', 'off']);
    });

    test('a release without a lease is refused, so a guard that releases twice is found', () async {
      await expectLater(protection.release, throwsStateError);
      expect(platform.calls, isEmpty);
    });

    test('a failed plugin call keeps the count, so the leases stay balanced', () async {
      platform.failWith = PlatformException(code: 'boom');
      await protection.acquire();
      expect(protection.leases, 1);
      await protection.release();
      expect(protection.leases, 0);
      expect(platform.calls, ['on', 'off']);
    });

    test('a failed plugin call is logged at error level, on and off', () async {
      platform.failWith = PlatformException(code: 'boom');
      final lines = await printedLines(() async {
        await protection.acquire();
        await protection.release();
      });
      final failures = lines.where((line) => line.contains('Turning screen capture protection')).toList();
      expect(failures, hasLength(2));
      expect(failures, everyElement(contains('[E]')));
    });

    test('two instances share no state', () async {
      final other = ScreenCaptureProtection(platform: _RecordingPlatform(), enabled: true);
      await protection.acquire();
      expect(other.leases, 0);
    });
  });

  group('switched off', () {
    test('a lease is no lease: nothing is counted and the platform is never called', () async {
      final off = ScreenCaptureProtection(platform: platform, enabled: false);
      expect(off.isEnabled, isFalse);
      await off.acquire();
      await off.acquire();
      expect(off.leases, 0);
      expect(off.isEngaged, isFalse);
      await off.release();
      await off.release();
      expect(platform.calls, isEmpty);
    });
  });

  group('ScreenCapturePlatform on Android', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    final pluginCalls = <String>[];
    // What MainActivity answers: whether FLAG_SECURE is set on the window after the call.
    late Future<Object?> Function(MethodCall call) answer;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      calls.clear();
      pluginCalls.clear();
      answer = (call) async => (call.arguments as Map)['secure'];
      messenger.setMockMethodCallHandler(ScreenCapturePlatform.channel, (call) async {
        calls.add(call);
        return answer(call);
      });
      messenger.setMockMethodCallHandler(const MethodChannel('screen_protector'), (call) async {
        pluginCalls.add(call.method);
        return true;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(ScreenCapturePlatform.channel, null);
      messenger.setMockMethodCallHandler(const MethodChannel('screen_protector'), null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('the channel is the one MainActivity answers', () {
      expect(ScreenCapturePlatform.channel.name, 'org.libredb.mobile/screen_capture');
      final secureWindow = File('android/app/src/main/kotlin/org/libredb/mobile/SecureWindow.kt').readAsStringSync();
      final activity = File('android/app/src/main/kotlin/org/libredb/mobile/MainActivity.kt').readAsStringSync();
      expect(secureWindow, contains('const val CHANNEL = "${ScreenCapturePlatform.channel.name}"'));
      expect(activity, contains('SecureWindow.register(flutterEngine.dartExecutor.binaryMessenger, this)'));
    });

    test('on sets FLAG_SECURE through MainActivity, not through the plugin', () async {
      await const ScreenCapturePlatform().protectOn();
      expect(calls.single.method, 'setSecure');
      expect(calls.single.arguments, {'secure': true});
      expect(pluginCalls, isEmpty);
    });

    test('off clears FLAG_SECURE through MainActivity', () async {
      await const ScreenCapturePlatform().protectOff();
      expect(calls.single.method, 'setSecure');
      expect(calls.single.arguments, {'secure': false});
      expect(pluginCalls, isEmpty);
    });

    test('a window that does not hold the flag after on is an error, never assumed protected', () async {
      answer = (_) async => false;
      await expectLater(
        const ScreenCapturePlatform().protectOn(),
        throwsA(
          isA<ScreenCaptureFlagException>()
              .having((e) => e.requested, 'requested', isTrue)
              .having((e) => e.isSet, 'isSet', isFalse),
        ),
      );
    });

    test('a window that still holds the flag after off is an error', () async {
      answer = (_) async => true;
      await expectLater(
        const ScreenCapturePlatform().protectOff(),
        throwsA(isA<ScreenCaptureFlagException>().having((e) => e.isSet, 'isSet', isTrue)),
      );
    });

    test('an answer without the flag state is an error', () async {
      answer = (_) async => null;
      await expectLater(
        const ScreenCapturePlatform().protectOn(),
        throwsA(isA<ScreenCaptureFlagException>().having((e) => e.isSet, 'isSet', isNull)),
      );
    });

    test('a refusal from MainActivity, such as no window, reaches the caller', () async {
      answer = (_) async => throw PlatformException(code: 'no_window');
      await expectLater(
        const ScreenCapturePlatform().protectOn(),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'no_window')),
      );
    });

    test('a flag that did not take is logged at error level through the protection, and the lease is kept', () async {
      answer = (_) async => false;
      final protection = ScreenCaptureProtection(platform: const ScreenCapturePlatform(), enabled: true);
      final lines = await printedLines(protection.acquire);
      final failures = lines.where((line) => line.contains('Turning screen capture protection on failed')).toList();
      expect(failures, hasLength(1));
      expect(failures.single, contains('[E]'));
      expect(failures.single, contains('FLAG_SECURE'));
      expect(protection.leases, 1);
    });
  });

  group('ScreenCapturePlatform on iOS', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channelCalls = <String>[];
    final pluginCalls = <String>[];

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      channelCalls.clear();
      pluginCalls.clear();
      messenger.setMockMethodCallHandler(ScreenCapturePlatform.channel, (call) async {
        channelCalls.add(call.method);
        return null;
      });
      messenger.setMockMethodCallHandler(const MethodChannel('screen_protector'), (call) async {
        pluginCalls.add(call.method);
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(ScreenCapturePlatform.channel, null);
      messenger.setMockMethodCallHandler(const MethodChannel('screen_protector'), null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('on blurs the task-switcher snapshot through the plugin', () async {
      await const ScreenCapturePlatform().protectOn();
      expect(pluginCalls, ['protectDataLeakageWithBlur']);
      expect(channelCalls, isEmpty);
    });

    test('off removes the blur', () async {
      await const ScreenCapturePlatform().protectOff();
      expect(pluginCalls, ['protectDataLeakageWithBlurOff']);
      expect(channelCalls, isEmpty);
    });
  });

  test('ScreenCapturePlatform refuses a platform the app does not ship on', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await expectLater(const ScreenCapturePlatform().protectOn(), throwsUnsupportedError);
    await expectLater(const ScreenCapturePlatform().protectOff(), throwsUnsupportedError);
  });
}
