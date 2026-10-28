import 'package:flutter/material.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';

/// One panel of the introduction: a mark, a heading, a paragraph, and — on the two panels that carry a number — a
/// line of figures under it.
///
/// It scrolls on its own rather than letting the flow scroll. The pager gives every panel the same box, and a panel
/// whose text outgrows that box is the ordinary case rather than the exceptional one: Android's font-size setting
/// reaches well past the largest ordinary step, and the paragraphs here are the longest text the app shows before
/// sign-in. The minimum height keeps the panel centred at the sizes that do fit, so the layout is unchanged there.
class OnboardingPanel extends StatelessWidget {
  const OnboardingPanel({required this.icon, required this.title, required this.body, super.key, this.figures});

  final IconData icon;
  final String title;
  final String body;

  /// The adoption line, on the panels that have one. A panel without it draws no gap for it.
  final String? figures;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final figures = this.figures;

    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      // The mark is decorative: the heading beside it says the same thing, and a screen reader that
                      // announced both would say it twice.
                      child: Icon(icon, size: AppSizes.avatarMd, color: colors.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    body,
                    style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (figures != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      figures,
                      style: text.titleSmall?.copyWith(color: colors.onPrimaryContainer),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
