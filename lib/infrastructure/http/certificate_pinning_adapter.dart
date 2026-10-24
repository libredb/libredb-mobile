import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';

/// Builds the Dio adapter that enforces [pins].
///
/// - **Empty pins** → default adapter (`IOHttpClientAdapter` with system
///   trust). Pinning is disabled; behaviour matches today.
/// - **Non-empty pins** → custom adapter whose `HttpClient` comes from
///   [createPinnedHttpClient]. A mismatch fails the TLS handshake with a
///   [CertificatePinningException], which Dio reports as the `error` of a
///   `DioExceptionType.unknown`, not `badCertificate` (Dio raises that only
///   for `IOHttpClientAdapter.validateCertificate`). `ResilienceInterceptor`
///   does not retry `unknown` errors, and `CacheInterceptor` never answers a
///   pin mismatch from cache.
HttpClientAdapter buildPinnedAdapter(List<String> pins) {
  if (pins.isEmpty) {
    return IOHttpClientAdapter();
  }
  return IOHttpClientAdapter()..createHttpClient = () => createPinnedHttpClient(pins);
}

/// A `package:http` client that enforces [pins] through [createPinnedHttpClient], for the identity provider's calls.
/// A mismatch fails the request with a [CertificatePinningException], which `IOClient` passes on unwrapped.
http.Client pinnedHttpClient(List<String> pins) => IOClient(createPinnedHttpClient(pins));

/// An `HttpClient` that accepts a server only when the public key of its certificate matches one of [pins].
///
/// It is built with `SecurityContext(withTrustedRoots: false)`, so **every** certificate falls through
/// `badCertificateCallback`: the only way to enforce pinning even against a system-trusted but adversarial CA, such as
/// a corporate interception proxy or a root that malware or the user installed. With no trusted roots dart:io hands
/// the callback the server's leaf certificate, once per handshake, whatever the server sends above it
/// (`test/infrastructure/http/certificate_pinning_adapter_test.dart`, docs/security.md), so a pin is the key of the
/// leaf. The callback returns true only when that key matches a pin; otherwise it throws a
/// [CertificatePinningException], and the handshake fails with that exception.
///
/// Throws [ArgumentError] for empty [pins]: an empty list means pinning is off, and the caller keeps the system trust
/// store instead.
HttpClient createPinnedHttpClient(List<String> pins) {
  if (pins.isEmpty) throw ArgumentError.value(pins, 'pins', 'must not be empty; an empty list keeps system trust');
  final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
  client.badCertificateCallback = (X509Certificate cert, String host, int port) {
    final accepted = CertificatePinner.matches(cert.der, pins);
    if (!accepted) {
      AppLogger.getLogger('CertificatePinningAdapter')
          .warn('Pin mismatch: rejecting connection to {}:{} (subject={})', [host, port, cert.subject]);
      // Thrown instead of returning false: dart:io fails the handshake with this exception, so the layers above
      // can tell a pin mismatch from a network failure. Returning false would surface as a HandshakeException.
      throw CertificatePinningException(host, port);
    }
    return accepted;
  };
  return client;
}
