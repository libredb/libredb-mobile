import 'package:flutter/material.dart';

import '../tokens/app_durations.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_radius.dart';

/// Card variants.
enum AppCardVariant { elevated, outlined, filled }

/// A composable card component replacing raw Container+BoxDecoration.
///
/// A card with an [onTap] answers both a pointer and a finger: the ripple is clipped to the card's own radius, and the
/// press carries the same emphasis the hover state does, so the variant's design — the lift of `elevated`, the border
/// of `outlined`, the fill of `filled` — is reachable on the touch devices this app ships to. A card without an
/// [onTap] stays inert under a finger, because a card that cannot be tapped must not look tappable (#367).
class AppCard extends StatefulWidget {
  final Widget? child;
  final Widget? header;
  final Widget? footer;
  final AppCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    this.child,
    this.header,
    this.footer,
    this.variant = AppCardVariant.outlined,
    this.onTap,
    this.padding,
    this.width,
    this.height,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  /// Whether the card is currently being pointed at or held. The variants read this rather than the hover alone, which
  /// is what made every one of their interaction states unreachable without a mouse.
  bool get _isEngaged => _isHovered || _isPressed;

  @override
  void didUpdateWidget(AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A card can lose its onTap under the finger — `onTap: user.enabled ? ... : null` and a reload that brings the row
    // back disabled. The InkWell then goes away, and `InkResponse.deactivate` disposes its highlights without going
    // through `updateHighlight`, so `onHighlightChanged` never fires and nothing else would ever clear this.
    if (_isPressed && widget.onTap == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onTap == null) setState(() => _isPressed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectivePadding = widget.padding ?? const EdgeInsets.all(AppSpacing.lg);

    Widget body = Padding(
      padding: effectivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.header != null) ...[widget.header!, const SizedBox(height: AppSpacing.md)],
          if (widget.child != null) Flexible(child: widget.child!),
          if (widget.footer != null) ...[const SizedBox(height: AppSpacing.md), widget.footer!],
        ],
      ),
    );

    if (widget.onTap != null) {
      // The highlight is what a held card reads from; the ripple on its own fades, and a card has to stay changed for
      // as long as the finger is down.
      body = InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onHighlightChanged: (pressed) => setState(() => _isPressed = pressed),
        child: body,
      );
    }

    Widget content = AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppDurations.easeOut,
      width: widget.width,
      height: widget.height,
      decoration: _decoration(colorScheme),
      // The Material(type: transparency) wrapper gives descendant ListTiles a Material ancestor for their ink
      // splashes. Without it, Flutter 3.44 asserts because the AnimatedContainer's BoxDecoration becomes the nearest
      // coloured DecoratedBox above the ListTile. It is also what paints this card's own splash; the splash is kept
      // inside the card's corners by the InkWell's own borderRadius, measured, rather than by a clip on this
      // Material — a Material with a shape emits a ClipPath whose hitTest refuses every position outside it, which
      // took the card's four corners out of its tap target (#367).
      child: Material(type: MaterialType.transparency, child: body),
    );

    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: content,
      );
    } else if (widget.variant == AppCardVariant.elevated || widget.variant == AppCardVariant.outlined) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: content,
      );
    }

    return content;
  }

  BoxDecoration _decoration(ColorScheme cs) {
    switch (widget.variant) {
      case AppCardVariant.elevated:
        return BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withAlpha(_isEngaged ? 35 : 20),
              blurRadius: _isEngaged ? 12 : 8,
              offset: Offset(0, _isEngaged ? 4 : 2),
            ),
          ],
        );
      case AppCardVariant.outlined:
        return BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _isEngaged ? cs.onSurfaceVariant : cs.outline),
          boxShadow: _isEngaged
              ? [BoxShadow(color: cs.shadow.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        );
      case AppCardVariant.filled:
        return BoxDecoration(
          color: _isEngaged ? cs.surfaceContainerLow.withAlpha(230) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        );
    }
  }
}
