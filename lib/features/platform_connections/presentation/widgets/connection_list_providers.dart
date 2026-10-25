import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/application/platform_connection_list_bloc.dart';
import 'package:libredb_mobile/features/platform_connections/application/usecases/list_connections_usecase.dart';
import 'package:libredb_mobile/features/platform_connections/domain/repositories/platform_connection_repository.dart';

/// A [PlatformConnectionListBloc] of its own for [child], which starts loading the list at once.
class PlatformConnectionListProviders extends StatelessWidget {
  const PlatformConnectionListProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<IPlatformConnectionRepository>();
    return BlocProvider(
      create: (_) =>
          PlatformConnectionListBloc(listPlatformConnectionsUseCase: ListPlatformConnectionsUseCase(repository))
            ..add(const PlatformConnectionListRequested()),
      child: child,
    );
  }
}
