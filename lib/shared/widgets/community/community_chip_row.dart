import 'package:flutter/material.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/utils/external_link.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';

/// The community section as a phone shows it: a heading and a wrapped row of chips.
///
/// It lives under `shared/` rather than beside the login page because nothing in it is about signing in, and because
/// the onboarding flow shows the same row. The wide layout is a different widget in `features/auth/`: the two share
/// their list of destinations and nothing else, which is why this used to be one file behind an `isDesktop` flag and
/// is now two.
///
/// Every icon is `cs.onSurfaceVariant`. The brand hues the wide grid uses fall under the 3:1 contrast floor on a
/// light surface for two of the six, and the label beside each icon already names the destination (#357).

class CommunityChipRow extends StatelessWidget {
  const CommunityChipRow({super.key, required this.actions});

  final List<CommunityAction> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = S.of(context);

    return Column(
      children: [
        const SizedBox(height: 24),
        Divider(color: cs.outlineVariant),
        const SizedBox(height: 16),
        Text(
          l10n.community_title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.community_subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: actions.map((action) => _CommunityChip(action: action)).toList(),
        ),
      ],
    );
  }
}

class _CommunityChip extends StatelessWidget {
  final CommunityAction action;

  const _CommunityChip({required this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = S.of(context);

    // The pill keeps its drawn height; the tap area around it grows to the minimum. Making the pill itself 48 pt
    // would turn a row of chips into a row of buttons, which is not what this section is.
    return Semantics(
      key: action.key,
      button: true,
      link: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openExternalLink(context, Uri.parse(action.url)),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The brand colour this icon used to carry is written for a background — it sits behind the
                    // desktop icon at alpha 0.18 above — and at full strength on the page's own surface two of the
                    // six fell under the 3:1 floor for a graphical object in the light theme: translate #10B981 at
                    // 2.54:1 and docs #F59E0B at 2.15:1. Measured per WCAG 2.1 relative luminance; #357 has the
                    // table. The label beside each icon already names the destination, so the colour was carrying
                    // no meaning the icon had to spend contrast on.
                    Icon(action.icon, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    // Wraps inside the pill rather than running past the line the Wrap gave it. Turkish shows it
                    // first — its labels are the longest — and one step of Android's accessibility text size was
                    // enough: 11 px over on a 320 pt phone at 1.3 (#375).
                    Flexible(
                      child: Text(
                        action.label(l10n),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
