import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/sensitive_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('the channel is the one MainActivity and AppDelegate answer', () {
    expect(SensitiveClipboard.channel.name, 'org.libredb.mobile/sensitive_clipboard');
  });

  test('on Android the text is copied marked sensitive', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await SensitiveClipboard.copy('j***@example.com');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'copy');
    expect(calls.single.arguments, {'text': 'j***@example.com', 'sensitive': true});
  });

  test('on iOS the text expires after 2 minutes and stays on the device', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await SensitiveClipboard.copy(r'\xdeadbeef');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'copy');
    expect(calls.single.arguments, {'text': r'\xdeadbeef', 'expiresInSeconds': 120, 'localOnly': true});
    expect(SensitiveClipboard.iosExpiry, const Duration(minutes: 2));
  });

  test('an empty text is copied as it is', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await SensitiveClipboard.copy('');

    expect(calls.single.arguments, {'text': '', 'sensitive': true});
  });

  test('a refused copy throws the platform error to the caller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
      throw PlatformException(code: 'clipboard_unavailable');
    });

    await expectLater(
      SensitiveClipboard.copy('value'),
      throwsA(isA<PlatformException>().having((error) => error.code, 'code', 'clipboard_unavailable')),
    );
  });

  test('a build without the native side throws MissingPluginException', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null);

    await expectLater(SensitiveClipboard.copy('value'), throwsA(isA<MissingPluginException>()));
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.fuchsia]) {
    test('${platform.name}, where the app does not ship, throws and copies nothing', () async {
      debugDefaultTargetPlatformOverride = platform;

      await expectLater(SensitiveClipboard.copy('value'), throwsA(isA<UnsupportedError>()));
      expect(calls, isEmpty);
    });
  }
}
