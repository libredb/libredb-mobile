import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:libredb_mobile/features/auth/presentation/widgets/community_card_grid.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/utils/app_constants.dart';
import 'package:libredb_mobile/shared/widgets/community/community_actions.dart';
import 'package:libredb_mobile/shared/widgets/community/community_urls.dart';

/// The brand half of the wide login layout: the gradient panel, its orbs and glass pills, the hero text and the
/// feature cards, with the community grid under them.
///
/// Wide-only — `kGoldenScreenSize` is a phone, so no golden renders it, and the phone layout never builds it. It
/// holds every `Color(0x…)` literal and every raw `fontSize` of the login surface, which is the point of it being
/// here: the owner's ruling is that the iPad layout stays and gets no further investment, and a ruling like that
/// cannot be enforced while the code sits in the file every other change has to open (#379).
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF020617), const Color(0xFF0C1222), const Color(0xFF020617)]
              : [const Color(0xFF0f172a), const Color(0xFF1B2B4B), const Color(0xFF0f172a)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, left: -80, child: _gradientOrb(420, const Color(0xFF6366F1), isDark ? 0.25 : 0.3)),
          Positioned(bottom: -180, right: -120, child: _gradientOrb(480, const Color(0xFF8B5CF6), isDark ? 0.2 : 0.25)),
          Positioned(top: 180, right: -60, child: _gradientOrb(280, const Color(0xFF06B6D4), isDark ? 0.15 : 0.18)),
          Positioned(bottom: 100, left: -40, child: _gradientOrb(200, const Color(0xFF3B82F6), isDark ? 0.12 : 0.15)),
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
                      _brandBadges(),
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

  Widget _brandBadges() {
    return _glassPill(AppConstants.appName, const Color(0xFFA5B4FC));
  }

  Widget _glassPill(String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, letterSpacing: -0.2),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    return Text(
      S.of(context).login_brand_headline,
      style: const TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
        letterSpacing: -1.5,
      ),
    );
  }

  Widget _heroSubtext(BuildContext context) {
    return Text(
      S.of(context).login_brand_description,
      style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.55), height: 1.65),
    );
  }

  Widget _featureCards(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      children: [
        _glassFeatureCard(Icons.shield_outlined, l10n.login_feature_auth_title, l10n.login_feature_auth_description),
        const SizedBox(height: 10),
        _glassFeatureCard(
          Icons.key_off_outlined,
          l10n.login_feature_credentials_title,
          l10n.login_feature_credentials_description,
        ),
        const SizedBox(height: 10),
        _glassFeatureCard(
          Icons.table_chart_outlined,
          l10n.login_feature_query_title,
          l10n.login_feature_query_description,
        ),
      ],
    );
  }

  Widget _glassFeatureCard(IconData icon, String title, String subtitle) {
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
                  color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFFA5B4FC)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45), height: 1.4),
                    ),
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
