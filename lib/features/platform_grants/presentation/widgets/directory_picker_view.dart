import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/application/directory_picker_bloc.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/directory_user.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/grant_target.dart';
import 'package:libredb_mobile/features/platform_grants/domain/entities/platform_grant.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/pages/platform_connection_grants_page.dart';
import 'package:libredb_mobile/features/platform_grants/presentation/widgets/directory_user_badges.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/components/app_badge.dart';
import 'package:libredb_mobile/shared/design_system/components/app_card.dart';
import 'package:libredb_mobile/shared/design_system/components/app_empty_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_error_state.dart';
import 'package:libredb_mobile/shared/design_system/components/app_skeleton.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The directory search of the grant editor's first step: a search field, the users found, and "load more".
///
/// A disabled user cannot be picked, because Platform refuses the grant; a user who already holds a grant on the
/// connection shows its level, and picking them changes that grant.
class DirectoryPickerView extends StatefulWidget {
  const DirectoryPickerView({super.key, required this.target, required this.holders, required this.onPicked});

  final GrantTarget target;
  final Map<String, PlatformGrant> holders;
  final ValueChanged<DirectoryUser> onPicked;

  @override
  State<DirectoryPickerView> createState() => _DirectoryPickerViewState();
}

class _DirectoryPickerViewState extends State<DirectoryPickerView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<DirectoryPickerBloc>().add(const DirectoryPickerQueryChanged(''));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bloc = context.read<DirectoryPickerBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Text(s.platform_grants_picker_title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => BlocSelector<DirectoryPickerBloc, DirectoryPickerState, bool>(
              selector: (state) => state.queryTooLong,
              builder: (context, tooLong) => TextField(
                key: const ValueKey('platform-directory-search'),
                controller: _controller,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                textInputAction: TextInputAction.search,
                onChanged: (text) => bloc.add(DirectoryPickerQueryChanged(text)),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: s.platform_grants_picker_search_hint,
                  prefixIcon: const Icon(Icons.search),
                  errorText: tooLong ? s.platform_grants_picker_query_too_long : null,
                  errorMaxLines: 2,
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: s.platform_grants_picker_clear,
                          onPressed: _clear,
                        ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<DirectoryPickerBloc, DirectoryPickerState>(
            builder: (context, state) => switch (state.status) {
              DirectoryPickerStatus.loading => const _Skeleton(),
              DirectoryPickerStatus.failure => _centered(
                AppErrorState(
                  title: s.platform_grants_picker_load_failed,
                  description: state.error?.resolve(context),
                  retryLabel: s.retry,
                  onRetry: () => bloc.add(const DirectoryPickerRetryRequested()),
                ),
              ),
              DirectoryPickerStatus.loaded when state.users.isEmpty => _centered(
                AppEmptyState(
                  icon: Icons.person_search_outlined,
                  title: s.platform_grants_picker_empty_title,
                  description: s.platform_grants_picker_empty_description,
                ),
              ),
              DirectoryPickerStatus.loaded => _UserList(
                state: state,
                target: widget.target,
                holders: widget.holders,
                onPicked: widget.onPicked,
              ),
            },
          ),
        ),
      ],
    );
  }

  static Widget _centered(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Center(child: child),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      for (var i = 0; i < 5; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppSkeleton.listTile(),
        ),
    ],
  );
}

class _UserList extends StatelessWidget {
  const _UserList({required this.state, required this.target, required this.holders, required this.onPicked});

  final DirectoryPickerState state;
  final GrantTarget target;
  final Map<String, PlatformGrant> holders;
  final ValueChanged<DirectoryUser> onPicked;

  @override
  Widget build(BuildContext context) {
    final hasFooter = state.loadingMore || state.loadMoreError != null || state.canLoadMore;
    return ListView.separated(
      key: const ValueKey('platform-directory-list'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.users.length + (hasFooter ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == state.users.length) return _Footer(state: state);
        final user = state.users[index];
        return _UserRow(user: user, target: target, holding: holders[user.id], onPicked: onPicked);
      },
    );
  }
}

/// "Load more", its progress, or the retry row after it failed.
class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final DirectoryPickerState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bloc = context.read<DirectoryPickerBloc>();
    if (state.loadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final error = state.loadMoreError;
    if (error != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Row(
        key: const ValueKey('platform-directory-load-more-failed'),
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${s.platform_grants_picker_load_more_failed}. ${error.resolve(context)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
          TextButton(onPressed: () => bloc.add(const DirectoryPickerLoadMoreRequested()), child: Text(s.retry)),
        ],
      );
    }
    return Center(
      child: TextButton(
        key: const ValueKey('platform-directory-load-more'),
        onPressed: () => bloc.add(const DirectoryPickerLoadMoreRequested()),
        child: Text(s.platform_grants_picker_load_more),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.target, required this.holding, required this.onPicked});

  final DirectoryUser user;
  final GrantTarget target;
  final PlatformGrant? holding;
  final ValueChanged<DirectoryUser> onPicked;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final holding = this.holding;
    final row = AppCard(
      key: ValueKey('platform-directory-user-${user.id}'),
      onTap: user.enabled ? () => onPicked(user) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.username, style: textTheme.titleSmall),
                if (user.fullName case final name?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(name, style: secondary),
                ],
                if (user.email case final email?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(email, style: secondary),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StudioRoleBadge(role: user.studioRole),
                    if (!user.enabled)
                      AppBadge(
                        label: s.platform_grants_picker_disabled,
                        variant: AppBadgeVariant.destructive,
                        icon: Icons.person_off_outlined,
                      ),
                    if (user.needsSeat) SeatNote(active: target.active),
                    if (holding != null)
                      AppBadge(
                        key: ValueKey('platform-directory-holds-${user.id}'),
                        label: levelLabel(s, holding.level),
                        icon: Icons.key_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (user.enabled) Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
    return user.enabled ? row : Opacity(opacity: 0.6, child: row);
  }
}
