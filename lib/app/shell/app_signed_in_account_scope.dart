import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/shell/sign_out_flow.dart';
import 'package:libredb_mobile/features/auth/application/studio_identity_cubit.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/user_data/signed_in_account_scope.dart';

/// Provides [SignedInAccountScope] from the app's [StudioIdentityCubit] and its sign-out flow: the subject Studio
/// named, null while the identity is not loaded, its read failed or it names no subject.
class AppSignedInAccountScope extends StatelessWidget {
  const AppSignedInAccountScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<StudioIdentityCubit, StudioIdentityState, String?>(
      selector: (state) => switch (state) {
        StudioIdentityLoaded(:final identity) => identity.subject,
        StudioIdentityInitial() || StudioIdentityLoading() || StudioIdentityFailure() => null,
      },
      // The shell's context, which stays mounted until the login page opens, unlike the page that removed the data.
      builder: (_, subject) => SignedInAccountScope(
        subject: subject,
        signOut: () => signOutAndOpenLogin(context),
        reloadStoredData: () => _reloadStoredData(context, subject),
        child: child,
      ),
    );
  }

  /// Reads again what the device keeps for [subject]: the favorites, and the open connection and its database, which
  /// close and open again only when their stored values are still there.
  static void _reloadStoredData(BuildContext context, String? subject) {
    context.read<FavoriteConnectionsBloc>().add(const FavoriteConnectionsReloaded());
    final connection = context.read<ActiveConnectionCubit>()..clear();
    final catalog = context.read<ActiveCatalogCubit>()..clear();
    connection.signedIn(subject);
    catalog.signedIn(subject);
  }
}
