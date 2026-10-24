import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/app_lock/data/services/channel_recents_preview.dart';

void main() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(calls.clear);
  tearDown(() {
    messenger.setMockMethodCallHandler(ChannelRecentsPreview.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(ChannelRecentsPreview.channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  test('the channel is the one MainActivity answers', () {
    expect(ChannelRecentsPreview.channel.name, 'org.libredb.mobile/recents_preview');
  });

  test('on Android asks MainActivity to hide the preview and answers whether it did', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) => true);

    expect(await const ChannelRecentsPreview().setHidden(true), isTrue);
    expect(calls.single.method, 'setHidden');
    expect(calls.single.arguments, {'hidden': true});
  });

  test('on Android before 13 MainActivity answers false, as it has no switch', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) => false);

    expect(await const ChannelRecentsPreview().setHidden(false), isFalse);
    expect(calls.single.arguments, {'hidden': false});
  });

  test('a failed call throws, so the caller logs it and protects the preview another way', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    answer((call) => throw PlatformException(code: 'failed'));

    expect(const ChannelRecentsPreview().setHidden(true), throwsA(isA<PlatformException>()));
  });

  test('on iOS answers false without a call, since no switch exists there', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    answer((call) => true);

    expect(await const ChannelRecentsPreview().setHidden(true), isFalse);
    expect(calls, isEmpty);
  });
}
