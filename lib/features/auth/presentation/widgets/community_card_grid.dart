import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/utils/external_link.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';

/// The community section as the wide login panel shows it: a grid of tinted cards.
///
/// Wide-only, and it stays in `features/auth/` because only the wide login builds it — no golden renders it either,
/// since `kGoldenScreenSize` is a phone. The phone row is `shared/widgets/community/community_chip_row.dart`.

/// The brand hue each destination is tinted with, and the four colours of the "source available" pill.
///
/// They live here, with the only layout that uses them. The wide login panel is a dark surface of its own, so these
/// are chosen against it rather than against the theme — and the phone row deliberately does not use them: two fall
/// under the 3:1 contrast floor on a light surface (#357). Keyed by the action's key, so a destination added to
/// `communityActions` without a tint fails here rather than rendering untinted.
final _tints = <Key, ({Color background, Color foreground})>{
  communityStarKey: (background: Color(0xFF6366F1), foreground: Color(0xFFA5B4FC)),
  communityIssueKey: (background: Color(0xFFEF4444), foreground: Color(0xFFFCA5A5)),
  communityContributeKey: (background: Color(0xFF8B5CF6), foreground: Color(0xFFC4B5FD)),
  communityTranslateKey: (background: Color(0xFF10B981), foreground: Color(0xFF6EE7B7)),
  communitySponsorKey: (background: Color(0xFFEC4899), foreground: Color(0xFFF9A8D4)),
  communityDocsKey: (background: Color(0xFFF59E0B), foreground: Color(0xFFFCD34D)),
};

class CommunityCardGrid extends StatelessWidget {
  const CommunityCardGrid({super.key, required this.actions});

  final List<CommunityAction> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.community_title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.community_subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _sourceAvailablePill(l10n),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: actions.map((action) => _CommunityCard(action: action)).toList()),
      ],
    );
  }

  Widget _sourceAvailablePill(S l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_open_rounded, size: 13, color: Color(0xFF6EE7B7)),
          const SizedBox(width: 6),
          Text(
            l10n.community_source_available,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6EE7B7),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatefulWidget {
  final CommunityAction action;

  const _CommunityCard({required this.action});

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  /// Pointed at or held. The card used to read the hover alone, which this layout's tablet users do not have (#367).
  bool get _isEngaged => _isHovered || _isPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final action = widget.action;
    // A destination added to communityActions without a tint fails here rather than rendering untinted.
    final tint = _tints[action.key]!;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _isEngaged ? 0.10 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: _isEngaged ? 0.15 : 0.08)),
              ),
              child: Material(
                type: MaterialType.transparency,
                // The splash belongs inside the card's corners, and the padding moved in with it so the whole card
                // takes the press rather than only the text.
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openExternalLink(context, Uri.parse(action.url)),
                  onHighlightChanged: (pressed) => setState(() => _isPressed = pressed),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      key: action.key,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: tint.background.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(action.icon, size: 16, color: tint.foreground),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          action.label(l10n),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: _isEngaged ? 0.95 : 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
