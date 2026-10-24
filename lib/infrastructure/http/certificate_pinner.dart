import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Matches a server certificate against pins of its public key.
///
/// A pin is the base64 SHA-256 of the certificate's DER-encoded SubjectPublicKeyInfo (RFC 7469 section 2.4), what
/// `openssl x509 -pubkey -noout | openssl pkey -pubin -outform der` piped to
/// `openssl dgst -sha256 -binary | openssl enc -base64` prints. A certificate renewed over the same key keeps its
/// pin; a new key needs a new pin.
///
/// The key is read with a small DER walker instead of a package: it reads only the outer TLV structure down to the
/// seventh field of `tbsCertificate` (RFC 5280 section 4.1) and hashes that element's bytes as they are, so it never
/// parses a key, and a certificate it cannot read fails closed.
///
/// The pin list is local build configuration, not user input, so plain string comparison is enough.
class CertificatePinner {
  CertificatePinner._();

  /// True if the key of [certDer] matches one of [pins]. False for an empty list, since an empty list reaching this
  /// function means pinning is misconfigured (switching it off happens one level up), and false for a certificate
  /// whose DER cannot be read.
  static bool matches(Uint8List certDer, List<String> pins) {
    if (pins.isEmpty) return false;
    final String pin;
    try {
      pin = computePin(certDer);
    } on FormatException {
      return false;
    }
    return pins.contains(pin);
  }

  /// The base64 SHA-256 of the SubjectPublicKeyInfo of [certDer].
  ///
  /// Throws a [FormatException] when [certDer] is not a DER certificate this walker can read.
  static String computePin(Uint8List certDer) => base64.encode(sha256.convert(subjectPublicKeyInfo(certDer)).bytes);

  /// The DER bytes of the SubjectPublicKeyInfo element of [certDer], tag and length included.
  ///
  /// Throws a [FormatException] when [certDer] is not a single DER SEQUENCE whose first element, `tbsCertificate`,
  /// holds an optional `[0]` version and then six more elements, the last of them a SEQUENCE.
  static Uint8List subjectPublicKeyInfo(Uint8List certDer) {
    final certificate = _Der.read(certDer, 0);
    if (certificate.end != certDer.length) throw const FormatException('Bytes follow the certificate');
    certificate.expectTag(_sequenceTag, 'Certificate');
    final tbs = _Der.read(certDer, certificate.contentStart);
    if (tbs.end > certificate.end) throw const FormatException('tbsCertificate runs past the certificate');
    tbs.expectTag(_sequenceTag, 'tbsCertificate');
    var element = _Der.read(certDer, tbs.contentStart);
    // version [0] EXPLICIT is absent from a version 1 certificate.
    if (element.tag == _versionTag) element = _next(certDer, element, tbs);
    // serialNumber, signature, issuer, validity and subject come before subjectPublicKeyInfo.
    for (var skipped = 0; skipped < 5; skipped++) {
      element = _next(certDer, element, tbs);
    }
    element.expectTag(_sequenceTag, 'subjectPublicKeyInfo');
    return Uint8List.sublistView(certDer, element.start, element.end);
  }

  static const _sequenceTag = 0x30;
  static const _versionTag = 0xa0;

  /// The element after [element] inside [parent].
  static _Der _next(Uint8List bytes, _Der element, _Der parent) {
    if (element.end >= parent.end) throw const FormatException('tbsCertificate has too few fields');
    final next = _Der.read(bytes, element.end);
    if (next.end > parent.end) throw const FormatException('A field runs past tbsCertificate');
    return next;
  }
}

/// One DER element: its tag, where it starts, where its content starts and where it ends.
final class _Der {
  const _Der(this.tag, this.start, this.contentStart, this.end);

  /// Reads the element at [start] of [bytes]: a single-byte tag and a definite length in its shortest form.
  static _Der read(Uint8List bytes, int start) {
    if (start + 2 > bytes.length) throw const FormatException('The DER ends inside an element header');
    final tag = bytes[start];
    if (tag & 0x1f == 0x1f) throw const FormatException('A multi-byte DER tag is not expected in a certificate');
    final first = bytes[start + 1];
    var offset = start + 2;
    int length;
    if (first < 0x80) {
      length = first;
    } else {
      final count = first & 0x7f;
      if (count == 0) throw const FormatException('An indefinite length is not DER');
      if (count > 3) throw const FormatException('A DER length longer than 16 MB is not expected in a certificate');
      if (offset + count > bytes.length) throw const FormatException('The DER ends inside a length');
      length = 0;
      for (var i = 0; i < count; i++) {
        length = (length << 8) | bytes[offset + i];
      }
      offset += count;
      if (length < 0x80 || length >> (8 * (count - 1)) == 0) {
        throw const FormatException('A DER length is not in its shortest form');
      }
    }
    final end = offset + length;
    if (end > bytes.length) throw const FormatException('A DER element runs past the end of the input');
    return _Der(tag, start, offset, end);
  }

  final int tag;
  final int start;
  final int contentStart;
  final int end;

  void expectTag(int expected, String name) {
    if (tag != expected) throw FormatException('$name is not a SEQUENCE');
  }
}

/// Thrown when the certificate a server presents matches none of the
/// configured pins.
///
/// The pinning adapter throws it from the TLS bad-certificate callback and
/// dart:io fails the handshake with it, so it reaches dio as the `error` of
/// a `DioException`. A pin mismatch means the connection may be
/// intercepted, so it must fail closed: it is never answered from cache.
class CertificatePinningException implements Exception {
  const CertificatePinningException(this.host, this.port);

  final String host;
  final int port;

  @override
  String toString() => 'CertificatePinningException: the certificate of $host:$port matches no configured pin';
}
