import 'package:flutter/material.dart';

/// The login page's heading and the line under it.
///
/// Each layout passes its own two strings. The `carriesIdentity` flag this replaces made the widget decide which
/// pair to show from which layout was asking, which is a question the caller already knows the answer to (#379).
class LoginHeading extends StatelessWidget {
  const LoginHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8, color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}
