@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/governance_status_scope.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_bloc.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_event.dart';
import 'package:libredb_mobile/features/studio_status/application/studio_status_state.dart';
import 'package:libredb_mobile/features/studio_status/domain/entities/governance_outage.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/widgets/governance_status.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mock_classes.dart';

void main() {
  const cannotServe = GovernanceOutage(
    kind: GovernanceOutageKind.cannotServeConnections,
    detail: 'libredb_grants: permission denied (42501)',
  );

  late MockStudioStatusBloc status;
  late MockStudioIdentityCubit identity;

  setUp(() {
    status = MockStudioStatusBloc();
    identity = MockStudioIdentityCubit();
    when(() => status.state).thenReturn(const StudioReachable());
    when(() => identity.state).thenReturn(const StudioIdentityInitial());
  });

  /// A screen under the scope that shows the notice; [onScreen] gets the scope's [GovernanceStatus].
  Future<void> pumpScope(WidgetTester tester, {void Function(GovernanceStatus status)? onScreen}) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<StudioStatusBloc>.value(value: status),
          BlocProvider<StudioIdentityCubit>.value(value: identity),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(
            body: GovernanceStatusScope(
              child: Builder(
                builder: (context) {
                  final governance = GovernanceStatus.of(context);
                  onScreen?.call(governance);
                  return governance.noticeBuilder(context);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('reports an outage and its end to the Studio status', (tester) async {
    late GovernanceStatus governance;
    await pumpScope(tester, onScreen: (status) => governance = status);

    governance.reportOutage();
    governance.reportRecovered();

    verifyInOrder([
      () => status.add(const StudioGovernanceOutageReported()),
      () => status.add(const StudioGovernanceRecovered()),
    ]);
  });

  testWidgets('words the outage as temporary until readiness chose the wording', (tester) async {
    await pumpScope(tester);

    expect(find.text(S.current.studio_governance_temporarily_unavailable), findsOneWidget);
  });

  testWidgets('words the outage as readiness chose it, without the detail for a user', (tester) async {
    when(() => status.state).thenReturn(const StudioGovernanceUnavailable(outage: cannotServe));
    when(() => identity.state)
        .thenReturn(const StudioIdentityLoaded(StudioIdentity(username: 'user@example.com', role: StudioUserRole())));

    await pumpScope(tester);

    expect(find.text(S.current.studio_governance_cannot_serve), findsOneWidget);
    expect(find.textContaining('42501'), findsNothing);
  });

  testWidgets("shows Studio's detail to an admin", (tester) async {
    when(() => status.state).thenReturn(const StudioGovernanceUnavailable(outage: cannotServe));
    when(() => identity.state)
        .thenReturn(const StudioIdentityLoaded(StudioIdentity(username: 'admin@example.com', role: StudioAdminRole())));

    await pumpScope(tester);

    expect(find.textContaining('42501'), findsOneWidget);
  });

  testWidgets('shows no detail before Studio named the role', (tester) async {
    when(() => status.state).thenReturn(const StudioGovernanceUnavailable(outage: cannotServe));

    await pumpScope(tester);

    expect(find.text(S.current.studio_governance_cannot_serve), findsOneWidget);
    expect(find.textContaining('42501'), findsNothing);
  });
}
