import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libredb_mobile/core/errors/app_error.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_radius.dart';
import 'package:libredb_mobile/shared/design_system/tokens/app_spacing.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';

/// The translated message of a Studio [error], from its code.
///
/// It never shows [AppError.message]: for a database error that is the database's own words, which only a screen made
/// to show them, such as the SQL editor, displays.
String _messageOf(BuildContext context, AppError error) =>
    (AppErrorCode.fromKey(error.code) ?? AppErrorCode.generic).resolve(context);

/// The statement Studio offers to fix a refused database credential, when [error] carries one.
String? _fixStatementOf(AppError error) => switch (error) {
  AuthError(:final fixStatement?) when fixStatement.isNotEmpty => fixStatement,
  _ => null,
};

bool _isGovernanceUnavailable(AppError error) => error.code == AppErrorCode.studioGovernanceUnavailable.key;

/// Copies [statement] to the clipboard and confirms it with [confirmation] through [messenger].
///
/// It takes the messenger and the text instead of a [BuildContext], so that an action that outlives the page that
/// showed it, such as a snack bar's, never looks up a deactivated context.
Future<void> _copyStatement(ScaffoldMessengerState? messenger, String confirmation, String statement) async {
  await Clipboard.setData(ClipboardData(text: statement));
  messenger?.showSnackBar(SnackBar(content: Text(confirmation)));
}

/// The same reaction to LibreDB Studio's cross-cutting errors on every screen.
///
/// - A rate limit counts down from [RateLimitedError.retryAfter]: the retry action stays disabled until zero, and
///   [onRetryAvailable] is called once when it reaches zero. Without a delay the retry action is available at once and
///   [onRetryAvailable] is not called. The banner never retries by itself, so it never runs a statement again.
/// - Governance unavailable says Studio is retrying; the screen that shows the banner does the retrying.
/// - A refused database credential shows its `fixStatement`, when Studio sent one, as copyable monospace text.
/// - Any other error shows the translated message of its code.
///
/// A retry action is shown only when [onRetry] is given. The banner logs nothing.
class StudioErrorBanner extends StatefulWidget {
  const StudioErrorBanner({super.key, required this.error, this.onRetry, this.onRetryAvailable});

  final AppError error;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryAvailable;

  @override
  State<StudioErrorBanner> createState() => _StudioErrorBannerState();
}

class _StudioErrorBannerState extends State<StudioErrorBanner> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(StudioErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.error, widget.error)) _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = null;
    final error = widget.error;
    _secondsLeft = error is RateLimitedError ? (error.retryAfter?.inSeconds ?? 0) : 0;
    if (_secondsLeft <= 0) {
      _secondsLeft = 0;
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft > 0) return;
      timer.cancel();
      _timer = null;
      widget.onRetryAvailable?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final error = widget.error;
    final transient = error is RateLimitedError || _isGovernanceUnavailable(error);
    final background = transient ? colorScheme.secondaryContainer : colorScheme.errorContainer;
    final foreground = transient ? colorScheme.onSecondaryContainer : colorScheme.onErrorContainer;
    final message = _isGovernanceUnavailable(error) ? s.studio_error_governance_retrying : _messageOf(context, error);
    final fixStatement = _fixStatementOf(error);
    final onRetry = widget.onRetry;

    return Semantics(
      container: true,
      liveRegion: true,
      label: s.studio_error_semantics(message),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconOf(error), color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(message, style: textTheme.bodyMedium?.copyWith(color: foreground)),
                  ),
                ],
              ),
            ),
            if (_secondsLeft > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(s.studio_error_retry_in(_secondsLeft), style: textTheme.bodySmall?.copyWith(color: foreground)),
            ],
            if (fixStatement != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(s.studio_error_fix_statement, style: textTheme.bodySmall?.copyWith(color: foreground)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectableText(
                      fixStatement,
                      style: textTheme.bodySmall?.copyWith(color: foreground, fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    tooltip: s.studio_error_copy_statement,
                    icon: Icon(Icons.copy, color: foreground),
                    onPressed: () => _copyStatement(
                      ScaffoldMessenger.maybeOf(context),
                      s.studio_error_statement_copied,
                      fixStatement,
                    ),
                  ),
                ],
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: _secondsLeft > 0 ? null : onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(s.retry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(AppError error) {
    if (error is RateLimitedError) return Icons.hourglass_bottom;
    if (_isGovernanceUnavailable(error)) return Icons.sync_problem;
    return Icons.error_outline;
  }
}

/// Shows a Studio [error] that does not block the screen in a snack bar: the translated message of its code, how long
/// a rate limit asks to wait, and an action that copies the `fixStatement` of a refused database credential.
///
/// Like [StudioErrorBanner] it never shows the error text of a database error and logs nothing.
void showStudioErrorSnackBar(BuildContext context, AppError error) {
  final s = S.of(context);
  final retryAfter = error is RateLimitedError ? error.retryAfter : null;
  final message = _isGovernanceUnavailable(error) ? s.studio_error_governance_retrying : _messageOf(context, error);
  final text = retryAfter != null && retryAfter.inSeconds > 0
      ? '$message ${s.studio_error_retry_in(retryAfter.inSeconds)}'
      : message;
  final fixStatement = _fixStatementOf(error);
  // The snack bar lives on the root messenger and can outlast the page that showed it, so its action uses the messenger
  // and the confirmation read now, never the page's context.
  final messenger = ScaffoldMessenger.of(context);
  final copied = s.studio_error_statement_copied;
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      action: fixStatement == null
          ? null
          : SnackBarAction(
              label: s.studio_error_copy_statement,
              onPressed: () => _copyStatement(messenger, copied, fixStatement),
            ),
    ),
  );
}
