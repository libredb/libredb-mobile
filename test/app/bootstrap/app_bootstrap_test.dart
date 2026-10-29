@Tags(['widget'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap.dart';
import 'package:libredb_mobile/app/bootstrap/app_bootstrap_config.dart';
import 'package:libredb_mobile/app/bootstrap/sentry_start.dart';
import 'package:libredb_mobile/infrastructure/config/auth_config.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Records what AppBootstrap.run asks of the Sentry start, answers the gate with [gated], and starts nothing.
class _RecordingSentryStart implements SentryStart {
  _RecordingSentryStart(this.gated);

  final AppConfig gated;
  final gatedConfigs = <AppConfig>[];
  final runDsns = <String?>[];

  @override
  Future<bool> Function() get isNativeSdkReady => throw UnimplementedError();

  @override
  SentryInit get sentryInit => throw UnimplementedError();

  @override
  Future<AppConfig> gate(AppConfig config) async {
    gatedConfigs.add(config);
    return gated;
  }

  @override
  Future<void> run(String? dsn, {required String release, required AppRunner appRunner}) async => runDsns.add(dsn);
}

void main() {
  group('AppBootstrap.run', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'app',
        packageName: 'app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      addTearDown(LicenseRegistry.reset);
    });

    // The gate decides before anything reads the config, so a release build whose host did not start the native SDK
    // runs as without a DSN, and the DSN SentryFlutter starts with is the one the gate kept.
    testWidgets('passes its config through the Sentry gate and starts Sentry with the DSN the gate kept', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['none'],
      );
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      final sentry = _RecordingSentryStart(
        const AppConfig(
          environment: Environment.prod,
          apiBaseUrl: null,
          certificatePins: [],
          idleTimeout: null,
          sentryDsnDefine: 'https://public@example.invalid/1',
        ),
      );
      final flutterErrorHandler = FlutterError.onError;
      final platformErrorHandler = PlatformDispatcher.instance.onError;
      final observer = Bloc.observer;

      await tester.runAsync(
        () => AppBootstrap.run(const AppBootstrapConfig(environment: Environment.mock), sentry: sentry),
      );
      FlutterError.onError = flutterErrorHandler;
      PlatformDispatcher.instance.onError = platformErrorHandler;
      Bloc.observer = observer;

      expect(sentry.gatedConfigs.map((config) => config.environment), [Environment.mock]);
      expect(sentry.runDsns, ['https://public@example.invalid/1']);
    });

    testWidgets('builds the config from the entry point\'s own values, not the build-time defines', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'app',
        packageName: 'app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final sentry = _RecordingSentryStart(const AppConfig.local(apiBaseUrl: 'https://studio.lab.test/api'));
      final flutterErrorHandler = FlutterError.onError;
      final platformErrorHandler = PlatformDispatcher.instance.onError;
      final observer = Bloc.observer;

      await tester.runAsync(
        () => AppBootstrap.run(
          const AppBootstrapConfig(
            environment: Environment.local,
            authDefines: AuthDefines(oidcIssuer: 'https://sso.lab.test/realms/libredb', oidcClientId: 'libredb-mobile'),
            apiBaseUrl: 'https://studio.lab.test/api',
            platformApiUrl: 'https://libredb.lab.test/api',
          ),
          sentry: sentry,
        ),
      );
      FlutterError.onError = flutterErrorHandler;
      PlatformDispatcher.instance.onError = platformErrorHandler;
      Bloc.observer = observer;

      expect(sentry.gatedConfigs.single.apiBaseUrl, 'https://studio.lab.test/api');
      expect(
        sentry.gatedConfigs.single.platform,
        isA<PlatformConfigured>().having((p) => p.baseUrl, 'baseUrl', 'https://libredb.lab.test/api'),
      );
    });

    testWidgets('leaves the language unstored on a first start, so the app follows the configured default', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'app',
        packageName: 'app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['none'],
      );
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      final flutterErrorHandler = FlutterError.onError;
      final platformErrorHandler = PlatformDispatcher.instance.onError;
      final observer = Bloc.observer;

      await tester.runAsync(() => AppBootstrap.run(const AppBootstrapConfig(environment: Environment.mock)));
      // The crash reporter and the bloc observer are global; the test binding needs its own error handler back.
      FlutterError.onError = flutterErrorHandler;
      PlatformDispatcher.instance.onError = platformErrorHandler;
      Bloc.observer = observer;

      expect(await AppLocalStorage().read(StorageKeys.language.key), isNull);
    });

    // The app is held upright on every form factor (#419): portrait up alone, so no device rotates it. No large
    // screen is exempted, because an exemption protected nothing — see `AppBootstrapConfig.preferredOrientations`.
    test('defaults to portrait up alone', () {
      expect(const AppBootstrapConfig(environment: Environment.mock).preferredOrientations, const [
        DeviceOrientation.portraitUp,
      ]);
    });

    testWidgets('asks the platform for portrait up alone', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['none'],
      );
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      final orientationCalls = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') orientationCalls.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final flutterErrorHandler = FlutterError.onError;
      final platformErrorHandler = PlatformDispatcher.instance.onError;
      final observer = Bloc.observer;

      await tester.runAsync(() => AppBootstrap.run(const AppBootstrapConfig(environment: Environment.mock)));
      FlutterError.onError = flutterErrorHandler;
      PlatformDispatcher.instance.onError = platformErrorHandler;
      Bloc.observer = observer;

      expect(orientationCalls, [
        ['DeviceOrientation.portraitUp'],
      ]);
    });

    // The app ships code of the MIT-licensed template, whose licence must travel with every copy, so the store build
    // carries the NOTICE and the licences page shows it.
    testWidgets('registers the NOTICE, with the MIT notice of the template, among the app licences', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => ['none'],
      );
      tester.binding.defaultBinaryMessenger.setMockStreamHandler(
        const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      final flutterErrorHandler = FlutterError.onError;
      final platformErrorHandler = PlatformDispatcher.instance.onError;
      final observer = Bloc.observer;

      await tester.runAsync(() => AppBootstrap.run(const AppBootstrapConfig(environment: Environment.mock)));
      FlutterError.onError = flutterErrorHandler;
      PlatformDispatcher.instance.onError = platformErrorHandler;
      Bloc.observer = observer;

      final licenses = (await tester.runAsync(() => LicenseRegistry.licenses.toList()))!;
      final notice = licenses.where((license) => license.packages.contains('libredb_mobile')).toList();
      expect(notice, hasLength(1));
      final text = notice.single.paragraphs.map((paragraph) => paragraph.text).join('\n');
      expect(text, contains('LibreDB Mobile is licensed under the Elastic License 2.0'));
      expect(text, contains('Copyright (c) 2025 Mehmet Cevheri BOZOGLAN'));
      expect(text, contains('Permission is hereby granted, free of charge'));
    });
  });
}
