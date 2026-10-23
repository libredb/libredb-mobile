import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/shared/models/studio_identity.dart';
import 'package:libredb_mobile/shared/widgets/studio_role_scope.dart';

/// Gives the signed-in screens below it a [StudioRoleScope] with the role [StudioIdentityCubit] holds: the role Studio
/// sent once the identity loaded, and null before that and after a failed read.
class AppStudioRoleScope extends StatelessWidget {
  const AppStudioRoleScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<StudioIdentityCubit, StudioIdentityState, StudioRole?>(
      selector: (state) => switch (state) {
        StudioIdentityLoaded(:final identity) => identity.role,
        StudioIdentityInitial() || StudioIdentityLoading() || StudioIdentityFailure() => null,
      },
      builder: (context, role) => StudioRoleScope(role: role, child: child),
    );
  }
}
