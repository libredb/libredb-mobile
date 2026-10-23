import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';

void main() {
  test('is the lower-case SHA-256 hex of the subject', () {
    expect(subjectHash('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
