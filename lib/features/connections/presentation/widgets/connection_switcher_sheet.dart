import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/active_connection_feed.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_providers.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_view.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';

/// The bottom sheet that switches the active connection without leaving the page: the grouped, searchable list of the
/// connection list page, asked afresh from Studio, with the user's Favorites section on top and the active connection
/// marked. A tap opens that connection, makes it the first of the recent ones, and closes the sheet; a list that no
/// longer holds the active connection closes it too.
class ConnectionSwitcherSheet extends StatefulWidget {
  const ConnectionSwitcherSheet({super.key});

  /// Opens the sheet over [context], which must reach the connection repositories, [ActiveConnectionCubit] and the
  /// app-scoped [FavoriteConnectionsBloc].
  static Future<void> show(BuildContext context) {
    final active = context.read<ActiveConnectionCubit>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider<ActiveConnectionCubit>.value(
        value: active,
        child: const ConnectionListProviders(child: ConnectionSwitcherSheet()),
      ),
    );
  }

  @override
  State<ConnectionSwitcherSheet> createState() => _ConnectionSwitcherSheetState();
}

class _ConnectionSwitcherSheetState extends State<ConnectionSwitcherSheet> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ConnectionListBloc>().add(const ConnectionListRequested());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(StudioConnection connection) {
    context.read<FavoriteConnectionsBloc>().add(FavoriteConnectionOpened(connection.id));
    context.read<ActiveConnectionCubit>().select(connection);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final activeId = context.select<ActiveConnectionCubit, String?>((cubit) => cubit.state.connection?.id);
    // A list without the active connection closes the sheet, so the shell's message about it is not hidden under it.
    return BlocListener<ActiveConnectionCubit, ActiveConnectionState>(
      listenWhen: (previous, current) => current is ActiveConnectionVanished,
      listener: (context, state) => Navigator.of(context).pop(),
      child: ActiveConnectionFeed(
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(l10n.connection_switcher_title, style: Theme.of(context).textTheme.titleMedium),
                ),
                Expanded(
                  child: BlocBuilder<ConnectionListBloc, ConnectionListState>(
                    builder: (context, state) => switch (state) {
                      ConnectionListInitial() ||
                      ConnectionListLoading() => const Center(child: CircularProgressIndicator()),
                      ConnectionListLoaded(:final connections) when connections.isEmpty => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(l10n.connection_list_empty, textAlign: TextAlign.center),
                        ),
                      ),
                      ConnectionListLoaded() => ConnectionListView(
                        state: state,
                        search: _search,
                        activeId: activeId,
                        onOpen: _open,
                      ),
                      // An outage says nothing about what was granted: the list loaded before stays, greyed.
                      ConnectionListUnavailable(:final previous?) when previous.connections.isNotEmpty =>
                        ConnectionListView(
                          state: previous,
                          search: _search,
                          activeId: activeId,
                          onOpen: _open,
                          enabled: false,
                        ),
                      ConnectionListUnavailable() => SingleChildScrollView(
                        key: const ValueKey('connection-switcher-unavailable'),
                        child: AppErrorState(
                          title: l10n.connection_list_unavailable,
                          retryLabel: l10n.retry,
                          onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
                        ),
                      ),
                      ConnectionListFailure(:final errorCode) => SingleChildScrollView(
                        child: AppErrorState(
                          title: l10n.connection_list_load_failed,
                          description: errorCode.resolve(context),
                          retryLabel: l10n.refresh,
                          onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
                        ),
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
