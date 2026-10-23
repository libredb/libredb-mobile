import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The first row of a Browse page's body, since Browse pages build no app bar: Studio's label for what the page shows,
/// such as a level or a kind, or the name of the container it opens, with [overline] above it when set, and the page's
/// [actions] at its end.
class BrowseHeading extends StatelessWidget {
  const BrowseHeading({super.key, required this.title, this.overline, this.actions = const []});

  final String title;
  final String? overline;

  /// Controls for the object the page shows, such as opening its detail from its source.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overline = this.overline;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: _titles(theme, overline)),
          ...actions,
        ],
      ),
    );
  }

  Widget _titles(ThemeData theme, String? overline) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (overline != null)
        Text(
          overline,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
