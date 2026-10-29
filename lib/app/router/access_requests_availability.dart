import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/infrastructure/config/environment.dart';

/// Whether a Studio user may ask for access to a connection: the build has a Platform target and Studio's connection
/// policy is loaded and says Platform governs it.
///
/// The two routes of `AccessRequestsFeatureRoutes` redirect to the connection list unless this holds, so a typed
/// location or a `returnUrl` never sends a Platform request outside the visibility rule. It lives here and not in the
/// feature, which must not read another feature's connection policy.
bool accessRequestsAvailable(BuildContext context) {
  if (context.read<AppConfig>().platform is! PlatformConfigured) return false;
  return switch (context.read<ConnectionPolicyCubit>().state) {
    ConnectionPolicyLoaded(:final policy) => policy.governance,
    ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
  };
}
