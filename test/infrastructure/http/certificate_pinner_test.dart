import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/loopback_tls_server.dart';
import '../../support/pin_test_certificates.dart';

/// A DER element: [tag], its length in the shortest form, then [content].
List<int> _tlv(int tag, List<int> content) {
  final length = content.length;
  final lengthBytes = length < 0x80
      ? [length]
      : length < 0x100
      ? [0x81, length]
      : [0x82, length >> 8, length & 0xff];
  return [tag, ...lengthBytes, ...content];
}

List<int> _sequence(List<List<int>> elements) => _tlv(0x30, [for (final element in elements) ...element]);

/// A key-shaped element, which the walker returns whole and never parses.
final _spki = _sequence([
  _sequence([
    _tlv(0x06, const [0x2a, 0x03]),
  ]),
  _tlv(0x03, const [0x00, 0x01, 0x02, 0x03]),
]);

/// A certificate-shaped DER: the fields before the key are empty elements of the right tag.
Uint8List _certificate({bool withVersion = true, List<int>? spki}) => Uint8List.fromList(
  _sequence([
    _sequence([
      if (withVersion) _tlv(0xa0, _tlv(0x02, const [0x02])),
      _tlv(0x02, const [0x01]),
      _sequence(const []),
      _sequence(const []),
      _sequence(const []),
      _sequence(const []),
      spki ?? _spki,
      _tlv(0xa3, _sequence(const [])),
    ]),
    _sequence(const []),
    _tlv(0x03, const [0x00]),
  ]),
);

void main() {
  group('CertificatePinner.computePin', () {
    // Each expected value is what the openssl command in docs/security.md prints for the certificate.
    test('hashes the SubjectPublicKeyInfo of an RSA certificate as openssl does', () {
      expect(CertificatePinner.computePin(derOf(rsaCertificatePem)), rsaCertificatePin);
    });

    test('hashes the SubjectPublicKeyInfo of an EC certificate as openssl does', () {
      expect(CertificatePinner.computePin(derOf(ecCertificatePem)), ecCertificatePin);
    });

    test('hashes the SubjectPublicKeyInfo of the loopback test certificate as openssl does', () {
      expect(CertificatePinner.computePin(loopbackCertificateDer), 'COJ+oMvPyJM6TDByJCYlNVA8YFGSMZ7jrCg/mRlmNZk=');
    });

    test('gives a certificate renewed over the same key the same pin', () {
      expect(derOf(ecRenewedCertificatePem), isNot(derOf(ecCertificatePem)));
      expect(CertificatePinner.computePin(derOf(ecRenewedCertificatePem)), ecCertificatePin);
    });

    test('is not the hash of the whole certificate', () {
      final der = derOf(ecCertificatePem);
      expect(CertificatePinner.computePin(der), isNot(base64.encode(sha256.convert(der).bytes)));
    });

    test('throws a FormatException for bytes that are not a certificate', () {
      expect(() => CertificatePinner.computePin(Uint8List.fromList([1, 2, 3, 4])), throwsFormatException);
    });
  });

  group('CertificatePinner.subjectPublicKeyInfo', () {
    test('returns the key element of a version 3 certificate whole', () {
      expect(CertificatePinner.subjectPublicKeyInfo(_certificate()), _spki);
    });

    test('returns the key element of a version 1 certificate, which has no version field', () {
      expect(CertificatePinner.subjectPublicKeyInfo(_certificate(withVersion: false)), _spki);
    });

    test('reads a long-form length', () {
      final spki = _sequence([
        _sequence([
          _tlv(0x06, const [0x2a, 0x03]),
        ]),
        _tlv(0x03, List.filled(300, 7)),
      ]);
      expect(CertificatePinner.subjectPublicKeyInfo(_certificate(spki: spki)), spki);
    });

    final malformed = <String, Uint8List>{
      'empty input': Uint8List(0),
      'a certificate cut short': Uint8List.sublistView(_certificate(), 0, 40),
      'bytes after the certificate': Uint8List.fromList([..._certificate(), 0x00]),
      'an outer element that is not a SEQUENCE': Uint8List.fromList([0x31, ..._certificate().sublist(1)]),
      'an indefinite length': Uint8List.fromList([0x30, 0x80, 0x00, 0x00]),
      'a length longer than the input': Uint8List.fromList([0x30, 0x84, 0x7f, 0xff, 0xff, 0xff]),
      'a length that is not in its shortest form': Uint8List.fromList([0x30, 0x81, 0x01, 0x00]),
      'a key element that is not a SEQUENCE': _certificate(spki: _tlv(0x04, const [1, 2])),
      'too few fields before the key': Uint8List.fromList(
        _sequence([
          _sequence([
            _tlv(0x02, const [0x01]),
            _sequence(const []),
          ]),
        ]),
      ),
    };
    for (final MapEntry(key: name, value: der) in malformed.entries) {
      test('throws a FormatException for $name', () {
        expect(() => CertificatePinner.subjectPublicKeyInfo(der), throwsFormatException);
      });
    }
  });

  group('CertificatePinner.matches', () {
    final der = derOf(ecCertificatePem);

    test('accepts a certificate whose key matches a pin', () {
      expect(CertificatePinner.matches(der, [ecCertificatePin]), isTrue);
    });

    test('accepts a certificate whose key matches the backup pin', () {
      expect(CertificatePinner.matches(der, [rsaCertificatePin, ecCertificatePin]), isTrue);
    });

    test('refuses a certificate whose key matches no pin', () {
      expect(CertificatePinner.matches(der, [rsaCertificatePin]), isFalse);
    });

    test('refuses every certificate for an empty pin list, since pinning is switched off one level up', () {
      expect(CertificatePinner.matches(der, const []), isFalse);
    });

    test('refuses a certificate whose DER cannot be read, even when a pin is its whole-certificate hash', () {
      final unreadable = Uint8List.fromList([1, 2, 3, 4]);
      expect(CertificatePinner.matches(unreadable, [base64.encode(sha256.convert(unreadable).bytes)]), isFalse);
    });

    test('compares pins case-sensitively, as base64 is', () {
      expect(ecCertificatePin, isNot(ecCertificatePin.toLowerCase()));
      expect(CertificatePinner.matches(der, [ecCertificatePin.toLowerCase()]), isFalse);
    });
  });
}
