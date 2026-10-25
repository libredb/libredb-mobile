import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/auth/application/platform_identity_cubit.dart';
import 'package:libredb_mobile/shared/widgets/platform_identity_scope.dart';

/// Gives the Platform screens below it a [PlatformIdentityScope] with what [PlatformIdentityCubit] holds: the identity
/// once it loaded, a failure after a failed read, and neither before that; its retry loads the identity again.
class AppPlatformIdentityScope extends StatelessWidget {
  const AppPlatformIdentityScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlatformIdentityCubit>();
    return BlocBuilder<PlatformIdentityCubit, PlatformIdentityState>(
      builder: (context, state) {
        final (identity, failed) = switch (state) {
          PlatformIdentityLoaded(:final identity) => (identity, false),
          PlatformIdentityFailure() => (null, true),
          PlatformIdentityInitial() || PlatformIdentityLoading() => (null, false),
        };
        return PlatformIdentityScope(identity: identity, failed: failed, onRetry: cubit.load, child: child);
      },
    );
  }
}
