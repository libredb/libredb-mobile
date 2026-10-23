import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/collapsed_sections_cubit.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/usecases/list_managed_connections_usecase.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/collapsed_sections_repository.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';

/// A [ConnectionListBloc] and a [CollapsedSectionsCubit] of its own for [child], as the connection list page and the
/// connection switcher each have.
class ConnectionListProviders extends StatelessWidget {
  const ConnectionListProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
}
