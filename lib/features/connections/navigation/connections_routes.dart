import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_advance/app/router/app_routes_constants.dart';
import 'package:flutter_bloc_advance/features/connections/application/connection_list_bloc.dart';
import 'package:flutter_bloc_advance/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:flutter_bloc_advance/features/connections/domain/repositories/connection_repository.dart';
import 'package:flutter_bloc_advance/features/connections/presentation/pages/connection_list_page.dart';
import 'package:flutter_bloc_advance/shared/design_system/components/app_page_transition.dart';
import 'package:go_router/go_router.dart';

class ConnectionsFeatureRoutes {
  static Widget _withListBloc(BuildContext context, Widget child) {
    final repo = context.read<IConnectionRepository>();
    return BlocProvider(
      create: (_) => ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repo)),
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
