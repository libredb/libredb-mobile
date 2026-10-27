import 'package:flutter/material.dart';

/// The product mark the login page shows above its heading.
///
/// Its own file so the identity work of M15 has one place to change the mark, rather than a method inside a 655-line
/// page (#379).
class LoginBrandIcon extends StatelessWidget {
  const LoginBrandIcon({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Icon(Icons.bolt_rounded, size: 24, color: cs.onSurface),
    );
  }

  /// The heading above the sign-in entries.
  ///
  /// With [carriesIdentity] it names the product and says what it does, which is what a phone needs: the brand panel
  /// that carries both renders only above [AppBreakpoints.tablet], and the app has no onboarding flow, so this
  /// screen is a first-time user's whole introduction. Without it the heading stays as it was, because the panel
  /// already says the same two things and a form panel should not repeat them.
}
