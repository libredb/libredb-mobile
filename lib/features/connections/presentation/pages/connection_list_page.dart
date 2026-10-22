import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/widgets/app_data_table.dart';
import 'package:libredb_mobile/shared/widgets/app_responsive_list_view.dart';

/// The connections Studio offers the signed-in user.
class ConnectionListPage extends StatefulWidget {
  const ConnectionListPage({super.key});

  @override
  State<ConnectionListPage> createState() => _ConnectionListPageState();
}

class _ConnectionListPageState extends State<ConnectionListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ConnectionListBloc>().add(const ConnectionListRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionListBloc, ConnectionListState>(
      builder: (context, state) => switch (state) {
        ConnectionListInitial() => _buildList(context),
        ConnectionListLoading() => _buildList(context, isLoading: true),
        ConnectionListLoaded(:final connections) => _buildList(context, items: connections),
        ConnectionListFailure(:final errorCode) => _buildList(
          context,
          errorWidget: AppErrorState(
            title: S.of(context).connection_list_load_failed,
            description: errorCode.resolve(context),
            retryLabel: S.of(context).refresh,
            onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
          ),
        ),
      },
    );
  }

  Widget _buildList(
    BuildContext context, {
    List<StudioConnection>? items,
    bool isLoading = false,
    Widget? errorWidget,
  }) {
    final l10n = S.of(context);
    return AppResponsiveListView<StudioConnection>(
      title: l10n.connections,
      subtitle: l10n.connection_list_subtitle,
      items: items,
      isLoading: isLoading,
      errorWidget: errorWidget,
      emptyIcon: Icons.storage_outlined,
      emptyText: l10n.connection_list_empty,
      columns: [
        AppTableColumn(label: l10n.connection_name, flex: 4, builder: (context, c) => Text(c.name)),
        AppTableColumn(label: l10n.connection_type, flex: 2, builder: (context, c) => Text(c.type)),
        AppTableColumn(label: l10n.connection_environment, flex: 2, builder: (context, c) => Text(c.environment ?? '')),
        AppTableColumn(label: l10n.connection_target, flex: 4, builder: (context, c) => Text(_target(c))),
      ],
      mobileCardBuilder: (context, connection) => _ConnectionCard(connection: connection),
    );
  }
}

/// `host:port/database`, or whichever of them Studio sent.
String _target(StudioConnection c) {
  final address = [if (c.host != null) c.host!, if (c.port != null) '${c.port}'].join(':');
  return [if (address.isNotEmpty) address, if (c.database != null) c.database!].join('/');
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection});

  final StudioConnection connection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = _target(connection);
    final details = [connection.type, if (connection.environment != null) connection.environment!].join(' · ');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(Icons.storage_outlined, color: cs.primary),
        title: Text(connection.name),
        subtitle: Text(target.isEmpty ? details : '$details\n$target'),
        isThreeLine: target.isNotEmpty,
      ),
    );
  }
}
