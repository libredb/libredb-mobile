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

  group('ScreenProtectorPlatform', () {
    const channel = MethodChannel('screen_protector');
    final methods = <String>[];

    setUp(() {
      methods.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('on blocks the capture on Android and blurs the snapshot on iOS', () async {
      await const ScreenProtectorPlatform().protectOn();
      expect(methods, ['protectDataLeakageOn', 'protectDataLeakageWithBlur']);
    });

    test('off undoes both', () async {
      await const ScreenProtectorPlatform().protectOff();
      expect(methods, ['protectDataLeakageOff', 'protectDataLeakageWithBlurOff']);
    });
  });
}
