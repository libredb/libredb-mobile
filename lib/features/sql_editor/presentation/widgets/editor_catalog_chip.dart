import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/features/sql_editor/application/editor_catalog_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/active_connection/active_catalog_cubit.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/widgets/studio_error_banner.dart';

/// The database a server-level connection runs statements in, above the editor's text: a chip that opens the picker of
/// the databases the server lists, named with the level's own label. Nothing shows on any other connection. A list
/// that could not be read shows Studio's error with a retry, and while it does Run waits.
class EditorCatalogChip extends StatelessWidget {
  const EditorCatalogChip({super.key, required this.connectionId});

  final String connectionId;

  static const chipKey = ValueKey('sql-editor-catalog');

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final active = context.select<ActiveCatalogCubit, String?>((cubit) => cubit.catalogOf(connectionId));
    final state = context.watch<EditorCatalogBloc>().state;
    final child = switch (state) {
      EditorCatalogChecking() || EditorCatalogNotUsed() => null,
      EditorCatalogLoading(:final label) => Chip(
        key: chipKey,
        avatar: const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        label: Text(label ?? s.sql_editor_catalog_label),
      ),
      EditorCatalogFailure(:final error) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.sql_editor_catalog_failed),
          const SizedBox(height: AppSpacing.xs),
          StudioErrorBanner(
            error: error,
            onRetry: () => context.read<EditorCatalogBloc>().add(const EditorCatalogRequested()),
          ),
        ],
      ),
      EditorCatalogListed(:final catalogs) when catalogs.isEmpty || active == null => Text(s.sql_editor_catalog_none),
      EditorCatalogListed(:final label, :final catalogs) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          key: chipKey,
          avatar: const Icon(Icons.storage_outlined),
          label: Text(s.sql_editor_catalog_chip(label ?? s.sql_editor_catalog_label, active!)),
          onPressed: () => _pick(context, catalogs, active),
        ),
      ),
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0), child: child);
  }

  /// Opens the picker of [catalogs] with [active] marked; the database tapped becomes the active one.
  Future<void> _pick(BuildContext context, List<String> catalogs, String active) async {
    final cubit = context.read<ActiveCatalogCubit>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  S.of(sheetContext).sql_editor_catalog_picker_title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final catalog in catalogs)
                      ListTile(
                        leading: const Icon(Icons.storage_outlined),
                        title: Text(catalog),
                        trailing: catalog == active ? const Icon(Icons.check) : null,
                        selected: catalog == active,
                        onTap: () => Navigator.of(sheetContext).pop(catalog),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) cubit.choose(connectionId, picked);
  }
}
