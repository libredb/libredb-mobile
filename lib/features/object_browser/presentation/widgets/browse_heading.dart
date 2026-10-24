import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_breakpoints.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';

/// The first row of a Browse page's body, since Browse pages build no app bar: Studio's label for what the page shows,
/// such as a level or a kind, or the name of the container it opens, with [overline] above it when set, the page's
/// [actions] at its end, and its [wrappedActions] on a line of their own under the title; on a compact height, such as
/// a phone held sideways, the wrapped actions share the title's row, so the page's content keeps the height.
class BrowseHeading extends StatelessWidget {
  const BrowseHeading({
    super.key,
    required this.title,
    this.overline,
    this.actions = const [],
    this.wrappedActions = const [],
  });

  final String title;
  final String? overline;

  /// Controls for the object the page shows, such as opening its detail from its source.
  final List<Widget> actions;

  /// Controls that run something for the object, such as View rows and Count rows, which wrap onto further lines when
  /// the width or the text size leaves no room beside each other.
  final List<Widget> wrappedActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overline = this.overline;
    final beside = wrappedActions.isNotEmpty && AppBreakpoints.isCompactHeight(MediaQuery.sizeOf(context).height);
    final wrapped = Wrap(
      alignment: beside ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: wrappedActions,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _titles(theme, overline)),
              if (beside) Flexible(child: wrapped),
              ...actions,
            ],
          ),
          if (wrappedActions.isNotEmpty && !beside) wrapped,
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
