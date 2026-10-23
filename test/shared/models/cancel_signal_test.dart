import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/models/cancel_signal.dart';

void main() {
  test('is not cancelled until cancel is called', () {
    expect(CancelSignal().isCancelled, isFalse);
  });

  test('cancel completes whenCancelled once, and a second cancel changes nothing', () async {
    final signal = CancelSignal();
    var told = 0;
    signal.whenCancelled.then((_) => told++);

    signal
      ..cancel()
      ..cancel();
    await pumpEventQueue();

    expect(signal.isCancelled, isTrue);
    expect(told, 1);
  });
}
