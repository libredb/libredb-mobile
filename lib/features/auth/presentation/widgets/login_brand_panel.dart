import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/community_card_grid.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:libredb_mobile/shared/design_system/theme/theme_colors.dart';
import 'package:libredb_mobile/shared/design_system/tokens/tokens.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';

/// The brand half of the wide login layout: the gradient panel, its orbs and glass pills, the hero text and the
/// feature cards, with the community grid under them.
///
/// Wide-only — `kGoldenScreenSize` is a phone, so no golden renders it, and the phone layout never builds it.
///
/// It used to hold every `Color(0x…)` literal and every raw `fontSize` of the login surface, which was the point
/// of it being here (#379). It holds none of either now: #284's first child put the panel on the design system,
/// and what used to be six hues of its own is the system's two gradients, `--gradient-brand` and `--gradient-data`.
///
/// **The panel is a dark field in both brightnesses.** That is its idea — the product's own ground beside the
/// sign-in form rather than a second copy of the page — so its text comes from the *dark* scope of the system's
/// own palette rather than from `Theme.of(context)`, which may be the light one. The sizes still come from the
/// theme, because the type scale does not change with brightness.
class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key, required this.isDark, required this.urls, required this.fade});

  final bool isDark;

  /// The page's own fade-in. One controller drives both halves of the wide layout, so this takes the animation
  /// rather than a ticker of its own.
  final Animation<double> fade;

  /// The community destinations, resolved by the page: `CommunityUrls` lives under `shared/`, which imports `core/`
  /// only, so the mapping from `ProjectLinks` cannot happen here.
  final CommunityUrls urls;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // The dark scope's page in the dark theme, one step lifted in the light one — beside a white form a
        // page-dark ground reads as a hole rather than as a panel.
        gradient: isDark ? AppGradients.brandField : AppGradients.brandFieldOnLight,
      ),
      child: Stack(
        children: [
          // The four stops of the system's two gradients, in the order they are declared: the mark's indigo and
          // purple, then the chevrons' emerald and blue.
          Positioned(top: -120, left: -80, child: _gradientOrb(420, AppGradients.brandStart, isDark ? 0.25 : 0.3)),
          Positioned(bottom: -180, right: -120, child: _gradientOrb(480, AppGradients.brandEnd, isDark ? 0.2 : 0.25)),
          Positioned(top: 180, right: -60, child: _gradientOrb(280, AppGradients.dataStart, isDark ? 0.15 : 0.18)),
          Positioned(bottom: 100, left: -40, child: _gradientOrb(200, AppGradients.dataEnd, isDark ? 0.12 : 0.15)),
          Padding(
            padding: const EdgeInsets.all(48),
            child: FadeTransition(
              opacity: fade,
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brandBadges(context),
                      const SizedBox(height: 40),
                      _heroText(context),
                      const SizedBox(height: 16),
                      _heroSubtext(context),
                      const SizedBox(height: 40),
                      _featureCards(context),
                      const SizedBox(height: 10),
                      CommunityCardGrid(actions: communityActions(urls)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientOrb(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  /// The system's own palette, dark scope: the ground this panel paints is that scope's, whatever the app's
  /// brightness is.
  static final ColorScheme _onTheField = ThemeColors.getColorScheme(AppThemePalette.classic, Brightness.dark);

  Widget _brandBadges(BuildContext context) {
    return _glassPill(context, AppConstants.appName, _onTheField.onPrimaryContainer);
  }

  Widget _glassPill(BuildContext context, String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    // `display-xl`, the largest level the phone column of the system defines. The 44 pt it used to be is on no
    // scale either side; `display-xxl` is 72 and is the one level this app leaves out.
    return Text(
      S.of(context).login_brand_headline,
      style: Theme.of(context).textTheme.displayLarge?.copyWith(color: _onTheField.onSurface),
    );
  }

  Widget _heroSubtext(BuildContext context) {
    return Text(
      S.of(context).login_brand_description,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: _onTheField.onSurfaceVariant),
    );
  }

  Widget _featureCards(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      children: [
        _glassFeatureCard(
          context,
          Icons.shield_outlined,
          l10n.login_feature_auth_title,
          l10n.login_feature_auth_description,
        ),
        const SizedBox(height: 10),
        _glassFeatureCard(
          context,
          Icons.key_off_outlined,
          l10n.login_feature_credentials_title,
          l10n.login_feature_credentials_description,
        ),
        const SizedBox(height: 10),
        _glassFeatureCard(
          context,
          Icons.table_chart_outlined,
          l10n.login_feature_query_title,
          l10n.login_feature_query_description,
        ),
      ],
    );
  }

  Widget _glassFeatureCard(BuildContext context, IconData icon, String title, String subtitle) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppGradients.brandStart.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: _onTheField.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: _onTheField.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _onTheField.tertiary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
