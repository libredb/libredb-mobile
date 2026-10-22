import 'package:flutter_bloc_advance/core/errors/app_error.dart';
import 'package:flutter_bloc_advance/core/result/result.dart';
import 'package:flutter_bloc_advance/features/auth/data/models/studio_identity_model.dart';
import 'package:flutter_bloc_advance/features/auth/data/repositories/studio_identity_repository.dart';
import 'package:flutter_bloc_advance/shared/models/studio_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_env.dart';

void main() {
  group('StudioIdentityRepository.fetch', () {
    test('reads the session of GET /auth/me', () async {
      TestEnv.authenticate();

      final result = await StudioIdentityRepository(TestEnv.apiClient()).fetch();

      expect(
        result,
        isA<Success<StudioIdentity>>().having(
          (s) => s.data,
          'data',
          StudioIdentity(
            username: 'admin@example.com',
            role: StudioRole.admin,
            subject: '6f1c9a52-0d7e-4b8e-9f43-2b0c4b1f7a10',
            issuer: 'https://localhost:8443/realms/libredb',
            expiresAt: DateTime.fromMillisecondsSinceEpoch(1792620060 * 1000, isUtc: true),
            viaBearer: true,
          ),
        ),
      );
    });

    test('fails with an AuthError without a session', () async {
      final result = await StudioIdentityRepository(TestEnv.apiClient()).fetch();

      expect(result, isA<Failure<StudioIdentity>>().having((f) => f.error, 'error', isA<AuthError>()));
    });
  });

  group('StudioIdentityModel.fromJsonString', () {
    test('reads a cookie session, which has no channel and no identity provider fields', () {
      final identity = StudioIdentityModel.fromJsonString(
        '{"authenticated":true,"user":{"role":"user","username":"user","iat":1,"exp":2}}',
      );

      expect(identity.role, StudioRole.user);
      expect(identity.viaBearer, isFalse);
      expect(identity.subject, isNull);
    });

    test('refuses an answer that is not signed in, or names an unknown role', () {
      for (final body in [
        '{"authenticated":false}',
        '{"authenticated":true}',
        '{"authenticated":true,"user":{"role":"owner","username":"x"}}',
        '{"authenticated":true,"user":{"role":"user"}}',
      ]) {
        expect(() => StudioIdentityModel.fromJsonString(body), throwsFormatException, reason: body);
      }
    });
  });
}
