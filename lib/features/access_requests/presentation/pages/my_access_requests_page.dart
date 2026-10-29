import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:libredb_mobile/app/router/app_routes_constants.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/features/access_requests/application/my_access_requests_bloc.dart';
import 'package:libredb_mobile/features/access_requests/application/withdraw_access_request_bloc.dart';
import 'package:libredb_mobile/features/access_requests/domain/entities/my_access_request.dart';
import 'package:libredb_mobile/features/access_requests/presentation/widgets/access_request_formatting.dart';
import 'package:libredb_mobile/features/access_requests/presentation/widgets/access_request_status_badge.dart';
import 'package:libredb_mobile/features/access_requests/presentation/widgets/withdraw_access_request_dialog.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The signed-in Studio user's own access requests, newest first as Platform answers them: what each asked for, how it
/// stands, the administrator's reason for a refusal, and the withdrawal of a pending one.
///
/// Every Platform refusal is shown here, with Retry, because a Studio session has no Platform gate or refusal page.
class MyAccessRequestsPage extends StatelessWidget {
  const MyAccessRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WithdrawAccessRequestBloc, WithdrawAccessRequestState>(listener: _onWithdraw),
        BlocListener<MyAccessRequestsBloc, MyAccessRequestsState>(
          listenWhen: (previous, current) =>
              current is MyAccessRequestsLoaded &&
              current.refreshError != null &&
              !(previous is MyAccessRequestsLoaded && previous.refreshError == current.refreshError),
          listener: (context, state) {
            final error = (state as MyAccessRequestsLoaded).refreshError!;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(error.resolve(context))));
          },
        ),
      ],
      child: Scaffold(
        body: BlocBuilder<MyAccessRequestsBloc, MyAccessRequestsState>(
          builder: (context, state) => switch (state) {
            MyAccessRequestsInitial() || MyAccessRequestsLoading() => const Center(
              child: CircularProgressIndicator(key: ValueKey('access-requests-loading')),
            ),
            MyAccessRequestsLoaded(requests: []) => _Refreshable(
              child: _OneScreen(
                child: AppEmptyState(
                  icon: Icons.lock_open_outlined,
                  title: S.of(context).access_requests_empty_title,
                  description: S.of(context).access_requests_empty_description,
                  actionLabel: S.of(context).access_requests_empty_action,
                  onAction: () => context.push(ApplicationRoutesConstants.accessRequestNew),
                ),
              ),
            ),
            MyAccessRequestsLoaded(:final requests) => _RequestList(requests: requests),
            MyAccessRequestsFailure(:final errorCode) => _OneScreen(
              child: AppErrorState(
                title: S.of(context).access_requests_load_failed,
                description: errorCode.resolve(context),
                retryLabel: S.of(context).retry,
                onRetry: () => context.read<MyAccessRequestsBloc>().add(const MyAccessRequestsLoadRequested()),
              ),
            ),
          },
        ),
        floatingActionButton: BlocBuilder<MyAccessRequestsBloc, MyAccessRequestsState>(
          builder: (context, state) => switch (state) {
            MyAccessRequestsLoaded(requests: [_, ...]) => FloatingActionButton.extended(
              key: const ValueKey('access-requests-new'),
              icon: const Icon(Icons.add),
              label: Text(S.of(context).access_requests_new_title),
              onPressed: () => context.push(ApplicationRoutesConstants.accessRequestNew),
            ),
            MyAccessRequestsLoaded() ||
            MyAccessRequestsInitial() ||
            MyAccessRequestsLoading() ||
            MyAccessRequestsFailure() => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  void _onWithdraw(BuildContext context, WithdrawAccessRequestState state) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    switch (state) {
      case WithdrawAccessRequestIdle() || WithdrawAccessRequestInProgress():
        break;
      case WithdrawAccessRequestDone(:final request):
        context.read<MyAccessRequestsBloc>().add(MyAccessRequestReplaced(request));
        messenger.showSnackBar(SnackBar(content: Text(S.of(context).access_requests_withdrawn_snackbar)));
      case WithdrawAccessRequestFailed(:final errorCode):
        messenger.showSnackBar(SnackBar(content: Text(errorCode.resolve(context))));
        // The request was decided or is gone meanwhile: the list says how it stands now.
        if (errorCode == AppErrorCode.platformAccessRequestDecided || errorCode == AppErrorCode.platformNotFound) {
          context.read<MyAccessRequestsBloc>().add(const MyAccessRequestsRefreshRequested());
        }
    }
  }
}

/// Lets a pull on [child] read the list again.
class _Refreshable extends StatelessWidget {
  const _Refreshable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      final bloc = context.read<MyAccessRequestsBloc>()..add(const MyAccessRequestsRefreshRequested());
      await bloc.stream.firstWhere((state) => state is! MyAccessRequestsLoading && !_isRefreshing(state));
    },
    child: child,
  );

  static bool _isRefreshing(MyAccessRequestsState state) => state is MyAccessRequestsLoaded && state.isRefreshing;
}

/// A message that fills the screen and still scrolls, so a pull reaches the [RefreshIndicator].
class _OneScreen extends StatelessWidget {
  const _OneScreen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: constraints.maxHeight, child: child),
    ),
  );
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests});

  final List<MyAccessRequest> requests;

  @override
  Widget build(BuildContext context) {
    final withdrawing = context.select<WithdrawAccessRequestBloc, bool>(
      (bloc) => bloc.state is WithdrawAccessRequestInProgress,
    );
    return _Refreshable(
      child: ListView.separated(
        key: const ValueKey('access-requests-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        // Clear of the floating button.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxxxl + AppSpacing.xl,
        ),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => _RequestRow(request: requests[index], canWithdraw: !withdrawing),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.canWithdraw});

  final MyAccessRequest request;

  /// False while any withdraw runs: a second one would be dropped, so no row offers it.
  final bool canWithdraw;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final secondary = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final decisionReason = request.decisionReason;
    return AppCard(
      key: ValueKey('access-request-row-${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(request.connectionName, style: textTheme.titleSmall)),
              const SizedBox(width: AppSpacing.sm),
              AccessRequestStatusBadge(request: request),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(requestLevelLabel(s, request.level), style: textTheme.bodyMedium),
          Text(s.access_requests_sent_at(formatRequestDate(context, request.createdAt)), style: secondary),
          if (request.status == AccessRequestStatus.refused) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              decisionReason == null || decisionReason.isEmpty
                  ? s.access_requests_refused_no_reason
                  : s.access_requests_refused_reason(decisionReason),
              style: textTheme.bodyMedium,
            ),
          ],
          if (request.status == AccessRequestStatus.approved) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(s.access_requests_approved_note, style: secondary),
          ],
          if (request.status == AccessRequestStatus.pending)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: ValueKey('access-request-withdraw-${request.id}'),
                onPressed: canWithdraw ? () => _confirmWithdraw(context) : null,
                child: Text(s.access_requests_withdraw),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context) async {
    final confirmed = await showWithdrawAccessRequestDialog(context, request: request);
    if (confirmed != true || !context.mounted) return;
    context.read<WithdrawAccessRequestBloc>().add(WithdrawAccessRequestRequested(request.id));
  }
}
