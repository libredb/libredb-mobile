import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/security/screen_capture_guard.dart';
import 'package:libredb_mobile/features/platform_audit/application/audit_log_bloc.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_event.dart';
import 'package:libredb_mobile/features/platform_audit/domain/entities/audit_filter.dart';
import 'package:libredb_mobile/features/platform_audit/navigation/audit_event_args.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/widgets/audit_filter_sheet.dart';
import 'package:libredb_mobile/features/platform_audit/presentation/widgets/audit_labels.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/components/app_status_badge.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/widgets/platform_unreachable_status.dart';

/// The audit log of the install in Platform mode: governed query events, newest first, with the filters set shown as
/// removable chips above them, a filter sheet, Load more while Platform holds more, and the detail of one event.
///
/// The rows show users, connections and the first line of statements, so they are kept out of screenshots while on
/// screen. A plan without the audit log and a refused permission each have their own page, without filters.
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnPlatformReachable(
      onReachable: () => _reloadFailed(context),
      child: BlocBuilder<AuditLogBloc, AuditLogState>(
        builder: (context, state) => switch (state) {
          AuditLogPlanRefused() => _centered(
            AppErrorState(
              icon: Icons.workspace_premium_outlined,
              title: S.of(context).platform_audit_plan_refused_title,
              description: S.of(context).platform_audit_plan_refused_description,
            ),
          ),
          AuditLogPermissionRefused() => _centered(
            AppErrorState(
              icon: Icons.lock_outline,
              title: S.of(context).platform_audit_permission_refused_title,
              description: S.of(context).platform_audit_permission_refused_description,
            ),
          ),
          AuditLogInitial() || AuditLogLoading() || AuditLogLoaded() || AuditLogFailure() => Column(
            children: [
              _FilterBar(state: state),
              Expanded(child: _body(context, state)),
            ],
          ),
        },
      ),
    );
  }

  /// Reads the first page again once Platform answers again under its unreachable page, when it failed meanwhile; a
  /// loaded log keeps its rows, and a plan or permission refusal is Platform's answer, not a failure.
  static void _reloadFailed(BuildContext context) {
    final bloc = context.read<AuditLogBloc>();
    if (bloc.state is AuditLogFailure) bloc.add(const AuditLogRefreshed());
  }

  Widget _body(BuildContext context, AuditLogState state) => switch (state) {
    AuditLogInitial() || AuditLogLoading() => const _Skeleton(),
    AuditLogLoaded(events: []) => Column(
      children: [
        ..._banners(state),
        Expanded(
          child: _Refreshable(
            child: _centered(
              state.filter.setFilterNames.isEmpty
                  ? AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: S.of(context).platform_audit_empty_title,
                      description: S.of(context).platform_audit_empty_description,
                    )
                  : AppEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: S.of(context).platform_audit_filtered_empty_title,
                      description: S.of(context).platform_audit_filtered_empty_description,
                      actionLabel: S.of(context).platform_audit_clear_filters,
                      onAction: () => context.read<AuditLogBloc>().add(const AuditLogFiltersCleared()),
                    ),
            ),
          ),
        ),
      ],
    ),
    final AuditLogLoaded loaded => _LoadedList(state: loaded),
    AuditLogFailure(:final errorCode) => _Refreshable(
      child: _centered(
        AppErrorState(
          title: S.of(context).platform_audit_load_failed,
          description: errorCode.resolve(context),
          retryLabel: S.of(context).retry,
          onRetry: () => context.read<AuditLogBloc>().add(const AuditLogRefreshed()),
        ),
      ),
    ),
    AuditLogPlanRefused() || AuditLogPermissionRefused() => const SizedBox.shrink(),
  };

  /// [child] centred on a page that can scroll, so a pull reaches a [RefreshIndicator] around it.
  static Widget _centered(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: child),
        ),
      ),
    ),
  );
}

/// The banners of a failed refresh or Load more and the bar of a running refresh, above the list they kept.
List<Widget> _banners(AuditLogLoaded state) => [
  if (state.isRefreshing) const LinearProgressIndicator(minHeight: 2),
  if (state.refreshError case final error?)
    _Banner(
      key: const ValueKey('platform-audit-refresh-failed'),
      title: (s) => s.platform_audit_refresh_failed,
      errorCode: error,
      onRetry: (bloc) => bloc.add(const AuditLogRefreshed()),
    ),
  if (state.loadMoreError case final error?)
    _Banner(
      key: const ValueKey('platform-audit-load-more-failed'),
      title: (s) => s.platform_audit_load_more_failed,
      errorCode: error,
      onRetry: (bloc) => bloc.add(const AuditLogLoadMoreRequested()),
    ),
];

/// Opens the event page above the list with [event], whose "Only this" actions narrow the list's filter.
void _openEvent(BuildContext context, AuditEvent event) {
  final bloc = context.read<AuditLogBloc>();
  context.push(
    ApplicationRoutesConstants.platformAuditEvent,
    extra: AuditEventArgs(
      event: event,
      onFilterSelected: (update) {
        if (!bloc.isClosed) bloc.add(AuditLogFilterChanged(update(bloc.state.filter)));
      },
    ),
  );
}

/// The Filters button and a removable chip for every filter set.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state});

  final AuditLogState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final filter = state.filter;
    final events = switch (state) {
      AuditLogLoaded(:final events) => events,
      _ => const <AuditEvent>[],
    };
    final chips = <(String, String, AuditFilter)>[
      if (filter.status case final status?)
        ('status', s.platform_audit_chip_status(auditStatusLabel(s, status)), filter.copyWith(status: () => null)),
      if (filter.statementType case final type?)
        ('statementType', s.platform_audit_chip_statement_type(type), filter.copyWith(statementType: () => null)),
      if (filter.source case final source?)
        ('source', s.platform_audit_chip_source(source), filter.copyWith(source: () => null)),
      if (filter.from case final from?)
        ('from', s.platform_audit_chip_from(auditDate(context, from)), filter.copyWith(from: () => null)),
      if (filter.to case final to?)
        ('to', s.platform_audit_chip_to(auditDate(context, to)), filter.copyWith(to: () => null)),
      if (filter.search case final search?)
        ('search', s.platform_audit_chip_search(search), filter.copyWith(search: () => null)),
      if (filter.subject case final subject?)
        ('subject', s.platform_audit_chip_user(_userOf(subject, events)), filter.copyWith(subject: () => null)),
      if (filter.connectionId case final id?)
        (
          'connectionId',
          s.platform_audit_chip_connection(_connectionOf(s, id, events)),
          filter.copyWith(connectionId: () => null),
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonalIcon(
            key: const ValueKey('platform-audit-filters'),
            onPressed: () => showAuditFilterSheet(context),
            icon: const Icon(Icons.filter_list),
            label: Text(s.platform_audit_filters),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (name, label, without) in chips)
                  InputChip(
                    key: ValueKey('platform-audit-chip-$name'),
                    label: Text(label, overflow: TextOverflow.ellipsis),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    deleteButtonTooltipMessage: s.platform_audit_chip_remove,
                    onDeleted: () => context.read<AuditLogBloc>().add(AuditLogFilterChanged(without)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The user of [subject] as a listed event names it; every listed event is of that user while the filter is set.
  static String _userOf(String subject, List<AuditEvent> events) {
    for (final event in events) {
      if (event.subject == subject) return auditUserLabel(event);
    }
    return auditShortSubject(subject);
  }

  /// The connection [id] as a listed event names it.
  static String _connectionOf(S s, String id, List<AuditEvent> events) {
    for (final event in events) {
      if (event.connectionId == id) return auditConnectionLabel(s, event);
    }
    return id;
  }
}

/// [child] under a [RefreshIndicator] whose pull reads the first page again and waits for the answer.
class _Refreshable extends StatelessWidget {
  const _Refreshable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () {
      final bloc = context.read<AuditLogBloc>();
      // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
      final done = bloc.stream.firstWhere(
        (state) => switch (state) {
          AuditLogLoaded(:final isRefreshing) => !isRefreshing,
          AuditLogFailure() || AuditLogPlanRefused() || AuditLogPermissionRefused() => true,
          AuditLogInitial() || AuditLogLoading() => false,
        },
        orElse: () => bloc.state,
      );
      bloc.add(const AuditLogRefreshed());
      return done;
    },
    child: child,
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      for (var i = 0; i < 6; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSkeleton.listTile(),
        ),
    ],
  );
}

class _LoadedList extends StatelessWidget {
  const _LoadedList({required this.state});

  final AuditLogLoaded state;

  @override
  Widget build(BuildContext context) {
    final events = state.events;
    return Column(
      children: [
        ..._banners(state),
        Expanded(
          child: _Refreshable(
            // The rows name users and connections and quote statements.
            child: ScreenCaptureGuard(
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: events.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) =>
                    index < events.length ? _EventRow(event: events[index]) : _LoadMore(state: state),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Load more while Platform holds more events, or its progress while it runs.
class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.state});

  final AuditLogLoaded state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Center(
        key: ValueKey('platform-audit-loading-more'),
        child: Padding(padding: EdgeInsets.all(AppSpacing.sm), child: CircularProgressIndicator()),
      );
    }
    if (!state.hasMore) return const SizedBox.shrink();
    return Center(
      child: OutlinedButton(
        key: const ValueKey('platform-audit-load-more'),
        onPressed: state.canLoadMore ? () => context.read<AuditLogBloc>().add(const AuditLogLoadMoreRequested()) : null,
        child: Text(S.of(context).platform_audit_load_more),
      ),
    );
  }
}

/// Why a refresh or a Load more failed, above the list it kept, with a retry.
class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.title, required this.errorCode, required this.onRetry});

  final String Function(S s) title;
  final AppErrorCode errorCode;
  final void Function(AuditLogBloc bloc) onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title(S.of(context)),
                      style: textTheme.titleSmall?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      errorCode.resolve(context),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: () => onRetry(context.read<AuditLogBloc>()), child: Text(S.of(context).retry)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final statement = event.statement;
    final captured = statement != null && event.statementCapture != 'none';
    final rowCount = event.rowCount;
    final details = [
      auditRelativeTime(context, event.startedAt),
      s.platform_audit_duration(event.durationMs),
      if (rowCount != null) s.platform_audit_row_count(rowCount),
    ].join('  ·  ');
    return AppCard(
      key: ValueKey('platform-audit-event-${event.eventId}'),
      onTap: () => _openEvent(context, event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(auditUserLabel(event), style: textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppStatusBadge(label: auditStatusLabel(s, event.status), color: auditStatusColor(context, event.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: Text(
                  auditConnectionLabel(s, event),
                  style: event.connectionKnown == false ? secondary?.copyWith(fontStyle: FontStyle.italic) : secondary,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(event.statementType, style: textTheme.labelMedium?.copyWith(color: colorScheme.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(details, style: secondary),
          const SizedBox(height: AppSpacing.sm),
          if (captured)
            Text(
              auditFirstLine(statement),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            )
          else
            Text(s.platform_audit_statement_not_captured, style: secondary?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
