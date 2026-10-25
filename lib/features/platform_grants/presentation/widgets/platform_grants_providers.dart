import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/grant_list_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/revoke_grant_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/list_connection_grants_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/application/usecases/revoke_grant_usecase.dart';
import 'package:libredb_mobile/features/platform_grants/domain/repositories/platform_grant_repository.dart';
import 'package:libredb_mobile/shared/models/platform_connection.dart';

/// A [GrantListBloc], loading the grants of [connection], and a [RevokeGrantBloc] of their own for [child].
///
/// Built in the route's page, so both die with the page and a sign-out has nothing of this feature to clear.
class PlatformGrantsProviders extends StatelessWidget {
  const PlatformGrantsProviders({super.key, required this.connection, required this.child});

  final PlatformConnection connection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<IPlatformGrantRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              GrantListBloc(listConnectionGrantsUseCase: ListConnectionGrantsUseCase(repository))
                ..add(GrantListLoadRequested(connection.id)),
        ),
        BlocProvider(create: (_) => RevokeGrantBloc(revokeGrantUseCase: RevokeGrantUseCase(repository))),
      ],
      child: child,
    );
  }
}
