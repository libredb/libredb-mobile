import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/core/testing/app_key_constants.dart';
import 'package:libredb_mobile/features/auth/application/login_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/models/session_target.dart';
import 'package:libredb_mobile/shared/models/target_reachability.dart';
import 'package:libredb_mobile/shared/widgets/target_reachability_scope.dart';

/// How much weight an entry's button carries. The page offers Studio and Platform, and they are not the same
/// offer: Studio is the ordinary way in, Platform is for the admins of a licensed deployment. Two filled buttons
/// said nothing about which one a user wants, so the quiet entry steps back to the outlined treatment.
enum SignInEmphasis {
  /// The page's primary action: the theme's filled button, on `primary`.
  primary,

  /// A secondary way in: the theme's outlined button, which paints no fill.
  secondary,
}

/// One way into the app: a full-width button, an optional helper line, and — while that target's server does not
/// answer and this entry gates itself on it — a notice with a Retry that asks the server again.
///
/// [emphasis] is passed by the caller for the same reason [showsReachability] is: an entry must not read its own
/// weight off how many siblings it happens to have.
///
/// [showsReachability] is passed rather than worked out here. The button used to decide it from
/// `_entries.length > 1`, which made one entry's behaviour depend on how many siblings it happened to have: a build
/// with a single entry leaves the unreachable gate to the status page above, a build with two gates each entry
/// itself. Extracted naively that coupling comes back invisibly, so the caller says which it is (#379).
///
/// A null [helper] draws no helper line at all, and takes the gap under the button with it: the single entry of a
/// build without a Platform target has no helper text, and an empty string would keep that gap and move the golden.
class SignInEntry extends StatelessWidget {
  const SignInEntry({
    super.key,
    required this.target,
    required this.buttonKey,
    required this.label,
    required this.helper,
    required this.showsReachability,
    required this.emphasis,
    required this.onTap,
  });

  final SessionTarget target;
  final Key buttonKey;
  final String label;

  /// How loudly this entry's button is drawn.
  final SignInEmphasis emphasis;

  /// The line under the button, or null for an entry that carries none.
  final String? helper;

  /// Whether this entry gates itself on its own server answering: it disables its own button and reports the
  /// unreachable server itself. An entry that does not leaves both to the surface above it.
  final bool showsReachability;

  final void Function(SessionTarget target) onTap;

  /// Whether the server of [target] answers, from the scope the app provides; without one, as before any check.
  static TargetReachability reachabilityOf(BuildContext context, SessionTarget target) =>
      TargetReachabilityScope.maybeOf(context)?.of(target) ?? TargetReachability.unknown;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reachability = reachabilityOf(context, target);
    final l10n = S.of(context);
    final helper = this.helper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // The entry is as tall as what it draws. The page builds it in a scroll view, where a `max` column collapses
      // to the same height anyway, so this changes no pixel there — it stops the entry from swallowing the slack
      // wherever it is given a bounded height, which is what the single-entry branch's bare SizedBox never did.
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: double.infinity, child: _button(context, reachability)),
        if (helper != null) ...[
          const SizedBox(height: 8),
          Text(helper, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.4)),
        ],
        if (showsReachability && reachability.blocksSignIn)
          Row(
            children: [
              Icon(Icons.cloud_off, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(switch (target) {
                  SessionTarget.studio => l10n.login_unreachable_studio,
                  SessionTarget.platform => l10n.login_unreachable_platform,
                }, style: TextStyle(fontSize: 13, color: cs.error, height: 1.4)),
              ),
              TextButton(
                key: switch (target) {
                  SessionTarget.studio => loginUnreachableRetryStudioKey,
                  SessionTarget.platform => loginUnreachableRetryPlatformKey,
                },
                onPressed: reachability == TargetReachability.checking
                    ? null
                    : () => TargetReachabilityScope.maybeOf(context)?.onRetry(target),
                child: reachability == TargetReachability.checking
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.retry),
              ),
            ],
          ),
      ],
    );
  }

  /// Every button is disabled while a sign-in runs, and only the one of the running sign-in's target shows the
  /// spinner. Where [showsReachability] is set, the button is also disabled while its own server does not answer.
  /// [emphasis] picks which of the theme's buttons draws it; neither names a colour of its own.
  Widget _button(BuildContext context, TargetReachability reachability) {
    final cs = Theme.of(context).colorScheme;
    final unreachable = showsReachability && reachability.blocksSignIn;
    return BlocBuilder<LoginBloc, LoginState>(
      buildWhen: (previous, current) => previous.runtimeType != current.runtimeType,
      builder: (context, state) {
        final isLoading = state is LoginLoadingState;
        final showsSpinner = state is LoginLoadingState && state.target == target;
        final onPressed = isLoading || unreachable ? null : () => onTap(target);
        // The spinner sits on whatever the button paints: the filled one's fill, the outlined one's page.
        final spinnerColor = switch (emphasis) {
          SignInEmphasis.primary => cs.onPrimary,
          SignInEmphasis.secondary => cs.onPrimaryContainer,
        };
        final child = Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: showsSpinner
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor))
              : Text(label),
        );
        return switch (emphasis) {
          SignInEmphasis.primary => FilledButton(key: buttonKey, onPressed: onPressed, child: child),
          SignInEmphasis.secondary => OutlinedButton(key: buttonKey, onPressed: onPressed, child: child),
        };
      },
    );
  }
}
