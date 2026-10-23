@Tags(['widget'])
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/shell/app_studio_subject_scope.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:libredb_mobile/shared/widgets/studio_subject_scope.dart';

import '../../mocks/mock_classes.dart';

void main() {
  late StreamController<StudioIdentityState> states;
  final seen = <String?>[];

  Future<void> pumpScope(WidgetTester tester) {
    final identity = MockStudioIdentityCubit();
    states = StreamController<StudioIdentityState>();
    addTearDown(states.close);
    seen.clear();
    whenListen(identity, states.stream, initialState: const StudioIdentityInitial());
    return tester.pumpWidget(
      BlocProvider<StudioIdentityCubit>.value(
        value: identity,
        child: AppStudioSubjectScope(
          child: Builder(
            builder: (context) {
              seen.add(StudioSubjectScope.of(context));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  Future<void> emit(WidgetTester tester, StudioIdentityState state) async {
    states.add(state);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('answers null until Studio names the subject', (tester) async {
    await pumpScope(tester);
    expect(seen.last, isNull);

    await emit(tester, const StudioIdentityLoading());
    expect(seen.last, isNull);

    await emit(tester, const StudioIdentityLoaded(StudioIdentity(username: 'ada', role: StudioUserRole())));
    expect(seen.last, isNull, reason: 'an identity without a subject keeps nothing on the phone');
  });

  testWidgets('answers the hash of the subject, never the subject, and null again once it is cleared', (tester) async {
    await pumpScope(tester);

    await emit(
      tester,
      const StudioIdentityLoaded(StudioIdentity(username: 'ada', role: StudioUserRole(), subject: 'kc-ada')),
    );
    expect(seen.last, subjectHash('kc-ada'));

    await emit(tester, const StudioIdentityFailure(AppErrorCode.generic));
    expect(seen.last, isNull);

    await emit(tester, const StudioIdentityInitial());
    expect(seen.last, isNull);
  });
}
