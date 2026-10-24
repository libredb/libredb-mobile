import 'dart:math';

import 'package:libredb_mobile/core/analytics/analytics_service.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';

/// Default analytics implementation that logs events via [AppLogger].
///
/// Requires no external SDK — works out of the box for development and
/// as a reference for production providers.
class LogAnalyticsService implements IAnalyticsService {
  static final _log = AppLogger.getLogger('Analytics');

  @override
  void logScreenView({required String screenName, String? screenClass}) {
    _log.info('screen_view: {} (class: {})', [screenName, screenClass ?? '-']);
  }

  @override
  void logEvent({required String name, Map<String, dynamic>? parameters}) {
    _log.info('event: {} params: {}', [name, parameters ?? {}]);
  }

  @override
  void logUserAction({required String action, String? target, Map<String, dynamic>? parameters}) {
    _log.info('user_action: {} target: {} params: {}', [action, target ?? '-', parameters ?? {}]);
  }

  @override
  void setUserId(String? userId) {
    _log.info('set_user_id: {}', [userId ?? 'null']);
  }

  @override
  void setUserProperty({required String name, required String? value}) {
    _log.info('set_user_property: {} = {}', [name, value ?? 'null']);
  }

  @override
  void logError({required Object error, StackTrace? stackTrace, String? reason}) {
    _log.error('non_fatal_error: {} reason: {}', [error, reason ?? '-']);
    if (stackTrace != null) {
      _log.error('stack_trace: {}', [() => _keptStackLines(stackTrace)]);
    }
  }

  // The most frames of a stack trace that the local log keeps.
  static const _keptFrameCount = 10;

  // The most lines kept before the first frame. An obfuscated build prints a header of about six lines there (the
  // asterisks, pid, os, build_id and the instruction addresses) that is needed to symbolize the frames after it.
  static const _keptHeaderLineCount = 10;

  static final _frameLine = RegExp(r'^\s*#\d+\s');

  // The lines of the stack trace that the local log keeps: the header before the first frame, which an obfuscated build
  // prints, and the first ten frames after it.
  static String _keptStackLines(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    final firstFrame = lines.indexWhere(_frameLine.hasMatch);
    final headerLength = firstFrame < 0 ? lines.length : firstFrame;
    return [
      ...lines.take(min(headerLength, _keptHeaderLineCount)),
      ...lines.skip(headerLength).take(_keptFrameCount),
    ].join('\n');
  }
}
