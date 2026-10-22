@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/features/studio_status/presentation/widgets/studio_governance_notice.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';

void main() {
  const cannotServe = GovernanceOutage(
    kind: GovernanceOutageKind.cannotServeConnections,
    detail: 'libredb_grants: permission denied (42501)',
  );

  Future<void> pumpNotice(WidgetTester tester, GovernanceOutage outage, StudioRole role) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: StudioGovernanceNotice(outage: outage, role: role),
        ),
      ),
    );
  }

  testWidgets('words a temporary outage as temporarily unavailable', (tester) async {
    await pumpNotice(
      tester,
      const GovernanceOutage(kind: GovernanceOutageKind.temporarilyUnavailable),
      StudioRole.user,
    );

    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
    expect(find.textContaining('cannot serve connections'), findsNothing);
  });

  testWidgets('words a misconfigured or incompatible Studio as unable to serve connections', (tester) async {
    await pumpNotice(tester, cannotServe, StudioRole.user);

    expect(find.textContaining('Studio cannot serve connections right now'), findsOneWidget);
    expect(find.textContaining('temporarily unavailable'), findsNothing);
  });

  testWidgets("shows Studio's detail to an admin", (tester) async {
    await pumpNotice(tester, cannotServe, StudioRole.admin);

    expect(find.textContaining('libredb_grants: permission denied (42501)'), findsOneWidget);
  });

  testWidgets("never shows Studio's detail to a user", (tester) async {
    await pumpNotice(tester, cannotServe, StudioRole.user);

    expect(find.textContaining('libredb_grants'), findsNothing);
  });
}
