import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/infrastructure/http/public_endpoint.dart';

void main() {
  group('publicEndpoints', () {
    // Studio serves only its liveness and readiness without a session (libredb-studio src/proxy.ts), and Platform its
    // /api/health paths, of which the app asks only liveness (libredb-platform src/shared/lib/public-paths.ts).
    test('holds only Studio liveness and readiness and Platform liveness', () {
      expect(publicEndpoints, {
        (method: 'GET', path: '/health'),
        (method: 'GET', path: '/ready'),
        (method: 'GET', path: '/health/live'),
      });
    });
  });
}
