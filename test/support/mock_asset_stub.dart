import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _stubs = <String, String>{};

/// Serves [body] as the asset [key], such as `assets/mock/PUT_test.json`, for the rest of the current test.
///
/// Every other asset still loads from the bundle. A test that needs a mock answer that no repository method sends uses
/// this, so it does not depend on a recorded answer that a feature may remove.
void stubAsset(String key, String body) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  if (_stubs.isEmpty) {
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final requested = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
      final stub = _stubs[requested];
      if (stub == null) return messenger.delegate.send('flutter/assets', message);
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(stub)));
    });
    addTearDown(() {
      _stubs.clear();
      messenger.setMockMessageHandler('flutter/assets', null);
    });
  }
  _stubs[Uri(path: Uri.encodeFull(key)).path] = body;
}
