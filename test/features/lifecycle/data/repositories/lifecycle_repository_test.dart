import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/lifecycle/data/repositories/lifecycle_repository.dart';
import 'package:libredb_mobile/features/lifecycle/domain/entities/app_config_entity.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/http/api_client.dart';
import 'package:libredb_mobile/infrastructure/http/token_rotation.dart';
import 'package:libredb_mobile/infrastructure/http/certificate_pinner.dart';
import 'package:libredb_mobile/infrastructure/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production chain (no MockInterceptor) with certificate pinning configured.
const _pinnedProdConfig = AppConfig(
  environment: Environment.prod,
  apiBaseUrl: 'https://api.example.test',
  certificatePins: ['test-pin'],
  idleTimeout: null,
);

/// Fails every request as the pinning adapter fails a server whose certificate matches no configured pin.
class _PinMismatchAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw const CertificatePinningException('api.example.test', 443);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('LifecycleRepository.fetchAppConfig', () {
    test('reports an untrusted certificate with AppErrorCode.networkCertInvalid', () async {
      final apiClient = ApiClient(
        tokenRotation: const RefusingTokenRotation(),
        appConfig: _pinnedProdConfig,
        secureStorage: FlutterSecureStorageAdapter(),
      );
      apiClient.instance.httpClientAdapter = _PinMismatchAdapter();

      final result = await LifecycleRepository(apiClient).fetchAppConfig();

      expect(result, isA<Failure<AppConfigEntity>>());
      final failure = result as Failure<AppConfigEntity>;
      expect(failure.error, isA<NetworkError>());
      expect(failure.error.code, AppErrorCode.networkCertInvalid.key);
    });
  });
}
