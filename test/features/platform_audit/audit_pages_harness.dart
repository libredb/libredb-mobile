import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/result/result.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_page.dart';
import 'package:libredb_mobile/features/platform_audit/domain/repositories/platform_audit_repository.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/platform_audit_routes.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';
import '../../support/screen_capture.dart';

/// The audit routes over a mocked repository, as the Platform shell holds them, without the shell's frame.
final class AuditPagesHarness {
  AuditPagesHarness() {
    registerFallbackValue(const AuditFilter());
  }

  final repository = MockIPlatformAuditRepository();
  final protection = recordingScreenCaptureProtection();
  late GoRouter router;

  /// Answers every read with [answer] of its filter and offset.
  void answerWith(Future<Result<AuditPage>> Function(AuditFilter filter, int offset) answer) {
    when(
      () => repository.list(
        filter: any(named: 'filter'),
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (invocation) =>
          answer(invocation.namedArguments[#filter] as AuditFilter, invocation.namedArguments[#offset] as int),
    );
  }

  /// Answers every read with one page of [events] and [total].
  void answer(List<AuditEvent> events, {int? total}) => answerWith(
    (filter, offset) async => Success(AuditPage(events: events, total: total ?? events.length, offset: offset)),
  );

  /// The filters sent since the last call.
  List<AuditFilter> sentFilters() => verify(
    () => repository.list(
      filter: captureAny(named: 'filter'),
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
    ),
  ).captured.cast<AuditFilter>();

  Future<void> pump(
    WidgetTester tester, {
    String location = ApplicationRoutesConstants.platformAudit,
    Object? extra,
    Locale locale = const Locale('en'),
    Size size = const Size(400, 1400),
  }) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    router = GoRouter(initialLocation: location, initialExtra: extra, routes: PlatformAuditFeatureRoutes.routes);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      withScreenCaptureProtection(
        protection: protection,
        RepositoryProvider<IPlatformAuditRepository>.value(
          value: repository,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.delegate.supportedLocales,
            routerConfig: router,
            builder: (context, child) => Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
