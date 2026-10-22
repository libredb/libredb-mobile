import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/connections/application/connection_check_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/domain/repositories/connection_repository.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_star_button.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/design_system/tokens/engine_icons.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/models/studio_environment.dart';
import 'package:libredb_mobile/shared/widgets/connection_badges.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// Opens the details of [connection] in a bottom sheet, with a Check that asks Studio to connect once.
///
/// The repositories and the favorites are read from [context], the page's, so the sheet's own check bloc lives as long
/// as the sheet and its star changes the page's favorites.
Future<void> showConnectionDetailsSheet(BuildContext context, StudioConnection connection) {
  final connectionRepository = context.read<IConnectionRepository>();
  final providerMetaRepository = context.read<IProviderMetaRepository>();
  final favorites = context.read<FavoriteConnectionsBloc>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // The sheet's route sits above the page, so it gets the page's favorites itself.
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: favorites),
        BlocProvider(
          create: (_) => ConnectionCheckBloc(
            connectionId: connection.id,
            connectionRepository: connectionRepository,
            providerMetaRepository: providerMetaRepository,
          ),
        ),
      ],
      child: ConnectionDetailsSheet(connection: connection),
    ),
  );
}

/// What the app knows about a connection, with its star, and its status once the user checks it. It never checks on its
/// own.
class ConnectionDetailsSheet extends StatelessWidget {
  const ConnectionDetailsSheet({super.key, required this.connection});

  final StudioConnection connection;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final environment = connection.environment;
    final address = _address(connection);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          ListTile(
            leading: Icon(engineIcon(connection.type), semanticLabel: connection.type),
            title: Text(connection.name, style: Theme.of(context).textTheme.titleMedium),
            subtitle: connection.readOnlyForUser
                ? const Align(alignment: AlignmentDirectional.centerStart, child: ReadOnlyChip())
                : null,
            trailing: BlocBuilder<FavoriteConnectionsBloc, FavoriteConnectionsState>(
              builder: (context, state) => switch (state) {
                FavoriteConnectionsReady(:final favorites) => ConnectionStarButton(
                  key: const ValueKey('connection-detail-star'),
                  connection: connection,
                  starred: favorites.starred.contains(connection.id),
                ),
                FavoriteConnectionsNone() ||
                FavoriteConnectionsLoading() ||
                FavoriteConnectionsUnavailable() => const SizedBox.shrink(),
              },
            ),
          ),
          _Detail(label: l10n.connection_type, value: connection.type),
          if (address.isNotEmpty) _Detail(label: l10n.connection_host, value: address),
          if (connection.database != null) _Detail(label: l10n.connection_database, value: connection.database!),
          if (environment != null)
            _Detail(
              label: l10n.connection_environment,
              value: StudioEnvironment.label(environment) ?? l10n.connection_environment_other,
            ),
          if (connection.group != null) _Detail(label: l10n.connection_group, value: connection.group!),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: _CheckSection(),
          ),
        ],
      ),
    );
  }
}

class _CheckSection extends StatelessWidget {
  const _CheckSection();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return BlocBuilder<ConnectionCheckBloc, ConnectionCheckState>(
      builder: (context, state) {
        final bloc = context.read<ConnectionCheckBloc>();
        void check() => bloc.add(const ConnectionCheckRequested());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.connection_status, style: Theme.of(context).textTheme.labelLarge),
            _StatusChip(state: state),
            ...switch (state) {
              ConnectionCheckIdle() || ConnectionCheckOnline() => [_CheckButton(onPressed: check)],
              ConnectionCheckChecking() => [const _CheckButton(onPressed: null)],
              ConnectionCheckDegraded(:final message) => [
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                _CheckButton(onPressed: check),
              ],
              ConnectionCheckNotChecked() => [
                OnlineOnlyAction(
                  builder: (context, enabled) => OutlinedButton.icon(
                    key: const ValueKey('connection-check-anyway'),
                    onPressed: enabled ? () => bloc.add(const ConnectionCheckForced()) : null,
                    icon: const Icon(Icons.bolt),
                    label: Text(l10n.connection_check_anyway),
                  ),
                ),
              ],
              // The banner's retry waits out a rate limit before it checks again.
              ConnectionCheckFailed(:final error) => [StudioErrorBanner(error: error, onRetry: check)],
            },
          ],
        );
      },
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.onPressed});

  /// Null while a check runs.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OnlineOnlyAction(
    builder: (context, enabled) => FilledButton.icon(
      key: const ValueKey('connection-check'),
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.network_check),
      label: Text(S.of(context).connection_check),
    ),
  );
}

/// The status of the last check as a chip: an icon and words, so color is never the only signal.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final ConnectionCheckState state;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (state) {
      ConnectionCheckIdle() => (l10n.connection_check_idle, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      ConnectionCheckNotChecked() => (
        l10n.connection_check_not_checked,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ConnectionCheckChecking() => (
        l10n.connection_check_checking,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      ConnectionCheckOnline(:final latency) => (
        latency == null
            ? l10n.connection_check_online_no_latency
            : l10n.connection_check_online(latency.inMilliseconds),
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ConnectionCheckDegraded() => (
        l10n.connection_check_degraded,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ConnectionCheckFailed() => (l10n.connection_check_failed, scheme.errorContainer, scheme.onErrorContainer),
    };
    final iconSize = 16 * MediaQuery.textScalerOf(context).scale(1);
    final Widget icon = switch (state) {
      ConnectionCheckChecking() => SizedBox.square(
        dimension: iconSize,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      ),
      ConnectionCheckIdle() => Icon(Icons.help_outline, size: iconSize, color: foreground),
      ConnectionCheckNotChecked() => Icon(Icons.pause_circle_outline, size: iconSize, color: foreground),
      ConnectionCheckOnline() => Icon(Icons.check_circle_outline, size: iconSize, color: foreground),
      ConnectionCheckDegraded() => Icon(Icons.warning_amber, size: iconSize, color: foreground),
      ConnectionCheckFailed() => Icon(Icons.error_outline, size: iconSize, color: foreground),
    };
    return Semantics(
      key: const ValueKey('connection-check-status'),
      container: true,
      liveRegion: true,
      label: l10n.connection_status_semantics(label),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.sm,
            children: [
              icon,
              Flexible(
                child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(dense: true, title: Text(label), subtitle: Text(value));
}

/// `host:port`, or whichever of them Studio sent.
String _address(StudioConnection c) => [if (c.host != null) c.host!, if (c.port != null) '${c.port}'].join(':');
