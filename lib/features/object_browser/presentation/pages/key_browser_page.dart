import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/features/object_browser/application/key_browser_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/key_browser_list.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// The key browser of [container] of [connectionId], or of its level folder [prefix]: a pattern field, the walk's
/// progress and what Studio said about it, Load more and Load all, and the keys grouped into folders.
class KeyBrowserPage extends StatelessWidget {
  const KeyBrowserPage({super.key, required this.connectionId, required this.container, this.prefix});

  final String connectionId;
  final List<String> container;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => KeyBrowserBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
        container: container,
        prefix: prefix,
      )..add(const KeyBrowserStarted()),
      child: _KeyBrowserView(connectionId: connectionId, container: container, prefix: prefix),
    );
  }
}

class _KeyBrowserView extends StatelessWidget {
  const _KeyBrowserView({required this.connectionId, required this.container, required this.prefix});

  final String connectionId;
  final List<String> container;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final heading = BrowseHeading(
      title: prefix ?? S.of(context).keys_title,
      overline: prefix == null ? null : S.of(context).keys_title,
    );
    return BlocBuilder<KeyBrowserBloc, KeyBrowserState>(
      builder: (context, state) => switch (state) {
        KeyBrowserLoading() => const Center(child: CircularProgressIndicator()),
        KeyBrowserUnavailable() => ListView(
          children: [
            heading,
            Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(S.of(context).keys_unavailable)),
          ],
        ),
        KeyBrowserLoaded() => _buildWalk(context, heading, state),
        KeyBrowserFailure(:final error, :final previous?) => _buildWalk(context, heading, previous, error: error),
        KeyBrowserFailure(:final error) => ListView(
          children: [
            heading,
            BrowseFailureView(
              runsStatement: false,
              connectionId: connectionId,
              error: error,
              onRetry: () => context.read<KeyBrowserBloc>().add(const KeyBrowserStarted()),
            ),
          ],
        ),
      },
    );
  }

  Widget _buildWalk(BuildContext context, Widget heading, KeyBrowserLoaded walk, {AppError? error}) {
    return KeyBrowserList(
      connectionId: connectionId,
      container: container,
      prefix: prefix,
      walk: walk,
      header: [
        heading,
        KeyPatternField(walk: walk),
        if (error != null)
          BrowseFailureView(
            runsStatement: false,
            connectionId: connectionId,
            error: error,
            onRetry: () => context.read<KeyBrowserBloc>().add(const KeyBrowserMoreRequested()),
          ),
        KeyWalkSummary(walk: walk),
      ],
    );
  }
}
