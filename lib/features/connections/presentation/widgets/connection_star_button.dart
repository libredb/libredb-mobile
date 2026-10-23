import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

/// Stars the connection on this device, or removes its star.
class ConnectionStarButton extends StatelessWidget {
  const ConnectionStarButton({super.key, required this.connection, required this.starred});

  final StudioConnection connection;
  final bool starred;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return IconButton(
      tooltip: starred ? l10n.connection_unstar : l10n.connection_star,
      isSelected: starred,
      icon: const Icon(Icons.star_border),
      selectedIcon: const Icon(Icons.star),
      onPressed: () => context.read<FavoriteConnectionsBloc>().add(FavoriteConnectionStarToggled(connection.id)),
    );
  }
}
