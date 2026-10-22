import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/pages/connection_list_page.dart';
import 'package:libredb_mobile/shared/design_system/components/app_page_transition.dart';
import 'package:go_router/go_router.dart';

class ConnectionsFeatureRoutes {
  static Widget _withListBloc(BuildContext context, Widget child) {
    final repo = context.read<IConnectionRepository>();
    final collapsed = context.read<ICollapsedSectionsRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repo)),
        ),
        BlocProvider(create: (_) => CollapsedSectionsCubit(repository: collapsed)..restore()),
      ],
      child: child,
    );
  }

  static final List<GoRoute> routes = <GoRoute>[
    GoRoute(
      name: 'connectionList',
      path: ApplicationRoutesConstants.connectionList,
      pageBuilder: (context, state) => appTransitionPage(
        state: state,
        type: AppPageTransitionType.fade,
        child: _withListBloc(context, const ConnectionListPage()),
      ),
    ),
  ];
}
