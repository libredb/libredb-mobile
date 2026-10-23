import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/shared/utils/byte_size.dart';

void main() {
  group('formatByteSize', () {
    test('shows bytes under a kilobyte as they are', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1023), '1023 B');
    });

    test('steps by 1024 and keeps one decimal below ten', () {
      expect(formatByteSize(1024), '1.0 KB');
      expect(formatByteSize(1536), '1.5 KB');
      expect(formatByteSize(32768), '32 KB');
      expect(formatByteSize(1835008), '1.8 MB');
      expect(formatByteSize(5 * 1024 * 1024 * 1024), '5.0 GB');
      expect(formatByteSize(3 * 1024 * 1024 * 1024 * 1024 * 1024), '3072 TB');
    });

    test('refuses a negative size', () {
      expect(() => formatByteSize(-1), throwsArgumentError);
    });
  });
}
