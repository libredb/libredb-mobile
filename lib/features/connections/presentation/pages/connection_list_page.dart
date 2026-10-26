import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/connections/application/connection_list_bloc.dart';
import 'package:libredb_mobile/features/connections/application/favorite_connections_bloc.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/active_connection_feed.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_details_sheet.dart';
import 'package:libredb_mobile/features/connections/presentation/widgets/connection_list_view.dart';
import 'package:libredb_mobile/features/connections/application/connection_policy_cubit.dart';
import 'package:libredb_mobile/features/connections/domain/entities/connection_policy.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_connection_cubit.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/models/studio_connection.dart';
import 'package:libredb_mobile/shared/widgets/account_refusal_status.dart';
import 'package:libredb_mobile/shared/widgets/governance_status.dart';
import 'package:libredb_mobile/shared/widgets/offline_status.dart';
import 'package:libredb_mobile/shared/widgets/statement_capture.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';
import 'package:libredb_mobile/shared/widgets/studio_unreachable_status.dart';

/// The connections Studio offers the signed-in user, in sections by the operator's group, with a search and an
/// environment filter. It never offers to add a connection: Studio's operator configures them.
///
/// The connections the user starred on this device come first, in a Favorites section, after a Recent strip of the
/// last connections the user opened; without readable favorites the list shows neither and no star.
///
/// Offline it keeps the list it loaded, marked with the time it was loaded, a pull to refresh says the device is
/// offline instead of asking Studio, and the list is asked again once the device is back online.
///
/// While it is on screen with the app in the foreground and the device online, the list follows grant changes by
/// itself ([ConnectionListBloc]), and the policy is asked again with it. A governance outage keeps the rows loaded
/// before greyed under the outage notice, or covers the page with it on a cold start, and never reads as an empty list.
class ConnectionListPage extends StatefulWidget {
  const ConnectionListPage({super.key});

  @override
  State<ConnectionListPage> createState() => _ConnectionListPageState();
}

class _ConnectionListPageState extends State<ConnectionListPage> {
  final _search = TextEditingController();
  late final AppLifecycleListener _lifecycle;

  /// Whether the app is in the foreground; an inactive app, such as one under the notification shade, still is.
  bool _foreground = true;

  /// Whether this page's tickers run: they stop while a page covers it, such as Studio's unreachable page.
  bool _visible = true;
  bool _online = true;

  /// The last foreground state sent to the bloc.
  bool? _sentActive;

  /// Whether the page shows a governance outage it has reported.
  bool _inOutage = false;

  /// Whether a list Studio answered has reported governance as answering since the page opened. The first one does
  /// even without an outage of its own, because a page closed during an outage, by a tab switch for example, leaves
  /// the outage in the app's status.
  bool _answerReported = false;

  /// Whether a list arrived since the page opened; the shell asks for the policy on its own before the first one.
  bool _listShown = false;

  @override
  void initState() {
    super.initState();
    context.read<ConnectionListBloc>().add(const ConnectionListRequested());
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final wasForeground = _foreground;
        _foreground = _isForeground(state);
        // Back from the background, the grants may have changed meanwhile.
        _sendActive(askNow: !wasForeground && _foreground);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _online = !OfflineStatus.isOfflineOf(context);
    _sendActive();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _search.dispose();
    super.dispose();
  }

  static bool _isForeground(AppLifecycleState? state) => switch (state) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
  };

  void _sendActive({bool askNow = false}) {
    final active = _foreground && _visible && _online;
    if (active == _sentActive) return;
    _sentActive = active;
    context.read<ConnectionListBloc>().add(ConnectionListAutoRefreshChanged(active: active, askNow: askNow));
  }

  /// Asks Studio again and completes once the answer, or its failure, is on screen, which ends the pull indicator;
  /// offline it says so with the banner's words instead.
  Future<void> _refresh() async {
    if (OfflineStatus.isOfflineOf(context)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(S.of(context).connectivity_offline)));
      return;
    }
    final bloc = context.read<ConnectionListBloc>();
    // Leaving the page closes the bloc, which ends its stream: that ends the refresh too, it is no error.
    final done = bloc.stream.firstWhere(
      (state) => switch (state) {
        ConnectionListLoaded(:final isRefreshing) => !isRefreshing,
        ConnectionListUnavailable(:final isRetrying) => !isRetrying,
        ConnectionListFailure() => true,
        ConnectionListInitial() || ConnectionListLoading() => false,
      },
      orElse: () => bloc.state,
    );
    bloc.add(const ConnectionListRefreshed());
    await done;
  }

  /// Asks Studio again once it accepts the account, or answers again under its unreachable page, when the list failed
  /// meanwhile, as under either page; a loaded list keeps its rows and its live refresh, and an unavailable one keeps
  /// retrying by itself.
  void _reloadFailed() {
    final bloc = context.read<ConnectionListBloc>();
    if (bloc.state is ConnectionListFailure) bloc.add(const ConnectionListRefreshed());
  }

  /// Reports where a governance outage starts and ends, for the wording the notice shows.
  void _followOutage(BuildContext context, ConnectionListState state) {
    final status = GovernanceStatus.of(context);
    switch (state) {
      case ConnectionListUnavailable():
        if (_inOutage) return;
        _inOutage = true;
        status.reportOutage();
      case ConnectionListLoaded(:final refreshError):
        // A failed refresh never reached governance, so it says nothing about it.
        if (refreshError != null || (!_inOutage && _answerReported)) return;
        _inOutage = false;
        _answerReported = true;
        status.reportRecovered();
      case ConnectionListFailure(:final errorCode):
        // An offline failure never reached Studio, so it says nothing about governance.
        if (!_inOutage || errorCode == AppErrorCode.networkOffline) return;
        _inOutage = false;
        status.reportRecovered();
      case ConnectionListInitial() || ConnectionListLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActiveConnectionFeed(
      child: OnReconnect(
        onReconnect: () => context.read<ConnectionListBloc>().add(const ConnectionListRefreshed()),
        child: OnAccountAccepted(
          onAccepted: _reloadFailed,
          child: OnStudioReachable(
            onReachable: _reloadFailed,
            child: MultiBlocListener(
              listeners: [
                BlocListener<ConnectionListBloc, ConnectionListState>(listener: _followOutage),
                BlocListener<ConnectionListBloc, ConnectionListState>(
                  listenWhen: (previous, current) =>
                      current is ConnectionListLoaded &&
                      (previous is! ConnectionListLoaded || previous.loadedAt != current.loadedAt),
                  listener: (context, state) {
                    final policy = context.read<ConnectionPolicyCubit>();
                    final first = !_listShown;
                    _listShown = true;
                    if (first && policy.state is ConnectionPolicyLoaded) return;
                    if (first && policy.state is ConnectionPolicyLoading) return;
                    policy.refresh();
                  },
                ),
              ],
              // The keyboard of a phone held sideways can leave less height than the note and the search need: the
              // note stays on top, scrolling inside the height there is rather than overflow, and the list gives way.
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: box.maxHeight),
                      child: const SingleChildScrollView(primary: false, child: _StatementCaptureNote()),
                    ),
                    Expanded(child: _buildState(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildState(BuildContext context) {
    return BlocBuilder<ConnectionListBloc, ConnectionListState>(
      builder: (context, state) => switch (state) {
        ConnectionListInitial() || ConnectionListLoading() => const Center(child: CircularProgressIndicator()),
        ConnectionListLoaded() => _buildLoaded(context, state),
        ConnectionListUnavailable(:final previous?) => _buildLoaded(context, previous, unavailable: true),
        ConnectionListUnavailable() => _buildFullScreen(
          context,
          child: Column(
            key: const ValueKey('connection-list-unavailable'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context).connection_list_unavailable,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              GovernanceStatus.of(context).noticeBuilder(context),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(S.of(context).retry),
              ),
            ],
          ),
        ),
        ConnectionListFailure(:final errorCode) => _buildFullScreen(
          context,
          child: AppErrorState(
            title: S.of(context).connection_list_load_failed,
            description: errorCode.resolve(context),
            retryLabel: S.of(context).refresh,
            onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRequested()),
          ),
        ),
      },
    );
  }

  /// [child] centred on a page that a pull refreshes.
  Widget _buildFullScreen(BuildContext context, {required Widget child}) => RefreshIndicator(
    onRefresh: _refresh,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(padding: const EdgeInsets.all(AppSpacing.xl), child: child),
          ),
        ),
      ),
    ),
  );

  /// The list in [state]; [unavailable] greys it under the governance outage notice and disables its rows.
  Widget _buildLoaded(BuildContext context, ConnectionListLoaded state, {bool unavailable = false}) {
    final refreshError = state.refreshError;
    final header = [
      OfflineStaleMarker(loadedAt: state.loadedAt),
      if (unavailable)
        Padding(
          key: const ValueKey('connection-list-outage'),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: _OutageBanner(child: GovernanceStatus.of(context).noticeBuilder(context)),
        )
      else if (refreshError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
          child: StudioErrorBanner(
            error: refreshError,
            onRetry: () => context.read<ConnectionListBloc>().add(const ConnectionListRefreshed()),
          ),
        ),
    ];
    if (state.connections.isEmpty) {
      return _underHeader(
        header,
        RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const ValueKey('connection-sections'),
            physics: const AlwaysScrollableScrollPhysics(),
            // An outage says nothing about what was granted, so it shows no empty state: the notice says why.
            children: [if (!unavailable) const _EmptyList()],
          ),
        ),
      );
    }
    return _underHeader(
      header,
      BlocSelector<ActiveConnectionCubit, ActiveConnectionState, String?>(
        selector: (active) => active.connection?.id,
        builder: (context, activeId) => ConnectionListView(
          state: state,
          search: _search,
          activeId: activeId,
          onRefresh: _refresh,
          showRecent: true,
          enabled: !unavailable,
          onOpen: (connection) => _open(context, connection),
          onLongPress: (connection) => showConnectionDetailsSheet(context, connection),
        ),
      ),
    );
  }

  /// [body] under the [header] banners. The keyboard of a phone held sideways can leave less height than the banners
  /// need: they stay on top, scrolling inside the height there is rather than overflow, and [body] gives way.
  Widget _underHeader(List<Widget> header, Widget body) => LayoutBuilder(
    builder: (context, box) => Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: box.maxHeight),
          child: SingleChildScrollView(
            primary: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: header),
          ),
        ),
        Expanded(child: body),
      ],
    ),
  );

  /// Makes [connection] the active one and the first of the recent ones, and opens it in the Browse tab.
  void _open(BuildContext context, StudioConnection connection) {
    context.read<FavoriteConnectionsBloc>().add(FavoriteConnectionOpened(connection.id));
    context.read<ActiveConnectionCubit>().select(connection);
    context.go(ApplicationRoutesConstants.browse);
  }
}

/// The statement capture note under the app bar while governance records statements in full; nothing otherwise.
class _StatementCaptureNote extends StatelessWidget {
  const _StatementCaptureNote();

  @override
  Widget build(BuildContext context) {
    final recordsInFull = context.select<ConnectionPolicyCubit, bool>(
      (cubit) => switch (cubit.state) {
        ConnectionPolicyLoaded(:final policy) => policy.statementCapture == ConnectionPolicy.statementCaptureFull,
        ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
      },
    );
    return recordsInFull ? const StatementCaptureNote() : const SizedBox.shrink();
  }
}

/// The empty list: under governance the user has no grants, which an administrator gives, as Studio's web client says;
/// otherwise Studio offers no connection. Until the policy is known it says the latter, which holds either way.
class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final governed = context.select<ConnectionPolicyCubit, bool>(
      (cubit) => switch (cubit.state) {
        ConnectionPolicyLoaded(:final policy) => policy.governance,
        ConnectionPolicyInitial() || ConnectionPolicyLoading() || ConnectionPolicyFailure() => false,
      },
    );
    final l10n = S.of(context);
    return AppEmptyState(
      icon: Icons.storage_outlined,
      title: governed ? l10n.connection_list_empty_governed : l10n.connection_list_empty,
    );
  }
}

/// The governance outage notice above the greyed rows it keeps.
class _OutageBanner extends StatelessWidget {
  const _OutageBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: child,
    ),
  );
}
