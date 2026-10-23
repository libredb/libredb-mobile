import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/object_browser/application/object_source_bloc.dart';
import 'package:libredb_mobile/features/object_browser/domain/repositories/object_browser_repository.dart';
import 'package:libredb_mobile/features/object_browser/navigation/browse_navigation.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_failure_view.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/browse_heading.dart';
import 'package:libredb_mobile/features/object_browser/presentation/widgets/object_source_view.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/provider_meta_repository.dart';

/// The source of the object at [path] of [connectionId], of [kind]: its name as the heading, with Details when its kind
/// has columns, then the viewer.
class ObjectSourcePage extends StatelessWidget {
  const ObjectSourcePage({super.key, required this.connectionId, required this.path, required this.kind});

  final String connectionId;
  final List<String> path;
  final String kind;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ObjectSourceBloc(
        repository: context.read<IObjectBrowserRepository>(),
        providerMeta: context.read<IProviderMetaRepository>(),
        connectionId: connectionId,
        path: path,
        kind: kind,
      )..add(const ObjectSourceRequested()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<ObjectSourceBloc, ObjectSourceState>(
            builder: (context, state) => BrowseHeading(
              title: path.isEmpty ? kind : path.last,
              overline: S.of(context).browse_source,
              actions: [
                if (state case ObjectSourceLoaded(hasDetails: true) || ObjectSourceFailure(hasDetails: true))
                  TextButton(
                    onPressed: () => openBrowseDetail(context, connectionId, path, kind),
                    child: Text(S.of(context).browse_details),
                  ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<ObjectSourceBloc, ObjectSourceState>(
              builder: (context, state) => switch (state) {
                ObjectSourceLoading() => const Center(child: CircularProgressIndicator()),
                ObjectSourceLoaded(:final source) => ObjectSourceView(source: source),
                ObjectSourceFailure(:final error) => ListView(
                  children: [
                    BrowseFailureView(
                      connectionId: connectionId,
                      error: error,
                      onRetry: () => context.read<ObjectSourceBloc>().add(const ObjectSourceRequested()),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
