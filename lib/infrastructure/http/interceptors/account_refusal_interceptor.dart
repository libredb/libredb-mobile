import 'package:dio/dio.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';

/// Which error refuses the signed-in account itself rather than one request, and with which code; null for any other.
typedef AccountRefusal = AppErrorCode? Function(DioException error);

/// Told the code of every answer that refuses the signed-in account.
typedef OnAccountRefused = void Function(AppErrorCode code);

/// Reports every answer that refuses the signed-in account to [OnAccountRefused], whichever request met it, and passes
/// the error on to the caller unchanged.
///
/// A backend can refuse an account it no longer accepts, for example one whose role an administrator removed, on every
/// route; one place hears of it, so the app can tell the user once instead of each screen showing its own error.
/// It starts no refresh and ends no session: a new token is refused the same way.
class AccountRefusalInterceptor extends Interceptor {
  AccountRefusalInterceptor({required this._refusalOf, required this._onRefused});

  static final _log = AppLogger.getLogger('AccountRefusalInterceptor');

  final AccountRefusal _refusalOf;
  final OnAccountRefused _onRefused;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final code = _refusalOf(err);
    if (code != null) {
      _log.warn('{} {} refused the account: {}', [err.requestOptions.method, err.requestOptions.path, code.key]);
      _onRefused(code);
    }
    handler.next(err);
  }
}
