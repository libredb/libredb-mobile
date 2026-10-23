import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/background_run_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  var nextId = 0;

  setUp(() {
    calls.clear();
    nextId = 0;
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, (call) async {
      calls.add(call);
      return call.method == 'begin' ? ++nextId : null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('the channel is the one AppDelegate answers', () {
    expect(ChannelBackgroundRunTime.channel.name, 'org.libredb.mobile/background_run_time');
  });

  test('iOS asks the channel for background time, and Android asks nothing', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(BackgroundRunTime.forPlatform(), isA<ChannelBackgroundRunTime>());
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(BackgroundRunTime.forPlatform(), isA<NoBackgroundRunTime>());
  });

  test('a lease begins a background task and its end ends that task', () async {
    final lease = const ChannelBackgroundRunTime().begin();
    await pumpEventQueue();
    await lease.end();

    expect(calls.map((call) => call.method), ['begin', 'end']);
    expect(calls.last.arguments, {'id': 1});
  });

  test('an end sent before the task id came back waits for it, so the task is still ended', () async {
    final id = Completer<int>();
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, (call) async {
      calls.add(call);
      return call.method == 'begin' ? id.future : null;
    });
    final lease = const ChannelBackgroundRunTime().begin();
    final ended = lease.end();
    await pumpEventQueue();
    expect(calls.map((call) => call.method), ['begin']);

    id.complete(7);
    await ended;

    expect(calls.map((call) => call.method), ['begin', 'end']);
    expect(calls.last.arguments, {'id': 7});
  });

  test('a second end sends nothing', () async {
    final lease = const ChannelBackgroundRunTime().begin();
    await lease.end();
    await lease.end();

    expect(calls.map((call) => call.method), ['begin', 'end']);
  });

  test('a task the platform did not grant (no id) is not ended', () async {
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, (call) async {
      calls.add(call);
      return null;
    });
    await const ChannelBackgroundRunTime().begin().end();

    expect(calls.map((call) => call.method), ['begin']);
  });

  test('a refused begin does not throw into the run, and its end sends nothing', () async {
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'unavailable');
    });
    await const ChannelBackgroundRunTime().begin().end();

    expect(calls.map((call) => call.method), ['begin']);
  });

  test('a refused end does not throw into the run', () async {
    messenger.setMockMethodCallHandler(ChannelBackgroundRunTime.channel, (call) async {
      calls.add(call);
      if (call.method == 'end') throw PlatformException(code: 'unavailable');
      return 3;
    });
    await const ChannelBackgroundRunTime().begin().end();

    expect(calls.map((call) => call.method), ['begin', 'end']);
  });

  test('the Android lease asks nothing and ends at once', () async {
    await const NoBackgroundRunTime().begin().end();

    expect(calls, isEmpty);
  });
}
