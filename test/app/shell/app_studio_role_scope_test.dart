@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/app_studio_role_scope.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/security/result_masking/masking_policy.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';

import '../../mocks/mock_classes.dart';

void main() {
  late MockStudioIdentityCubit identity;
  late StreamController<StudioIdentityState> states;
  final seen = <StudioRole?>[];

  // Made inside the test body, so the states it streams are delivered in the test's fake async zone.
  Future<void> pumpScope(WidgetTester tester) {
    identity = MockStudioIdentityCubit();
    states = StreamController<StudioIdentityState>();
    addTearDown(states.close);
    seen.clear();
    whenListen(identity, states.stream, initialState: const StudioIdentityInitial());
    return tester.pumpWidget(
      BlocProvider<StudioIdentityCubit>.value(
        value: identity,
        child: AppStudioRoleScope(
          child: Builder(
            builder: (context) {
              seen.add(StudioRoleScope.of(context));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  /// Streams [state] and lets the scope rebuild with it.
  Future<void> emit(WidgetTester tester, StudioIdentityState state) async {
    states.add(state);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('answers null, and so the user settings, before the identity loads', (tester) async {
    await pumpScope(tester);

    expect(seen.last, isNull);
    expect(MaskingPolicy.forRole(seen.last).roleKind, MaskingRoleKind.user);

    await emit(tester, const StudioIdentityLoading());
    expect(seen.last, isNull);
  });

  testWidgets('answers the role Studio sent once the identity loads', (tester) async {
    await pumpScope(tester);

    await emit(tester, const StudioIdentityLoaded(StudioIdentity(username: 'ada', role: StudioAdminRole())));

    expect(seen.last, const StudioAdminRole());
    expect(MaskingPolicy.forRole(seen.last).roleKind, MaskingRoleKind.admin);
  });

  testWidgets('answers null again when the identity read fails or is cleared', (tester) async {
    await pumpScope(tester);
    await emit(tester, const StudioIdentityLoaded(StudioIdentity(username: 'ada', role: StudioAdminRole())));

    await emit(tester, const StudioIdentityFailure(AppErrorCode.generic));
    expect(seen.last, isNull);

    await emit(tester, const StudioIdentityLoaded(StudioIdentity(username: 'ada', role: StudioUnknownRole('owner'))));
    expect(seen.last, const StudioUnknownRole('owner'));
    expect(MaskingPolicy.forRole(seen.last).roleKind, MaskingRoleKind.user);

    await emit(tester, const StudioIdentityInitial());
    expect(seen.last, isNull);
  });
}
