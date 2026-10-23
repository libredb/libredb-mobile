import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/shared/utils/subject_hash.dart';
import 'package:libredb_mobile/shared/widgets/studio_subject_scope.dart';

/// Provides [StudioSubjectScope] from the app's [StudioIdentityCubit]: the hash of the subject Studio named, and null
/// while the identity is not loaded, its read failed or it names no subject.
class AppStudioSubjectScope extends StatelessWidget {
  const AppStudioSubjectScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<StudioIdentityCubit, StudioIdentityState, String?>(
      selector: (state) => switch (state) {
        StudioIdentityLoaded(:final identity) => identity.subject,
        StudioIdentityInitial() || StudioIdentityLoading() || StudioIdentityFailure() => null,
      },
      builder: (context, subject) =>
          StudioSubjectScope(subjectHash: subject == null ? null : subjectHash(subject), child: child),
    );
  }
}
