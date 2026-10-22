import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';

/// Hands every managed list Studio answers to [ActiveConnectionCubit], so the active connection vanishes when a list no
/// longer holds it and the stored one opens once a list does. A list kept on screen offline is no new answer.
class ActiveConnectionFeed extends StatelessWidget {
  const ActiveConnectionFeed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectionListBloc, ConnectionListState>(
      listenWhen: (previous, current) =>
          current is ConnectionListLoaded &&
          (previous is! ConnectionListLoaded || previous.loadedAt != current.loadedAt),
      listener: (context, state) =>
          context.read<ActiveConnectionCubit>().connectionsListed((state as ConnectionListLoaded).connections),
      child: child,
    );
  }
}
