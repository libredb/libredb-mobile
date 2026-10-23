import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/studio/cancel_answer_json.dart';

void main() {
  test('reads the cancelled flag', () {
    expect(CancelAnswerJson.cancelled('{"cancelled":true}'), isTrue);
    expect(CancelAnswerJson.cancelled('{"cancelled":false}'), isFalse);
  });

  test('refuses an answer without the flag, or one that is not an object', () {
    for (final body in ['{"error":"x"}', '{"cancelled":"yes"}', '[]', 'not json']) {
      expect(() => CancelAnswerJson.cancelled(body), throwsFormatException, reason: body);
    }
  });
}
