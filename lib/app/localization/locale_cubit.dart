import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/localization/startup_language.dart';
import 'package:libredb_mobile/core/errors/app_error_code.dart';
import 'package:libredb_mobile/core/logging/app_logger.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';

part 'locale_state.dart';

/// Owns the language the app shows. `App` builds its `MaterialApp` with [LocaleState.locale].
///
/// The language the user picked is stored on the device under [StorageKeys.language], a device preference that is
/// not part of the session: a sign-out keeps it, and the next start shows it. Without a stored language the app
/// follows the phone: the language it starts in is `defaultLocale`, which `AppBootstrapConfig.startupLanguage`
/// resolved from the device, and a later change of the phone's own languages moves it too ([followDevice]).
///
/// A Cubit, not a Bloc: restoring and changing the language are single calls with nothing to debounce, and the
/// language dialog offers no new pick while one is being stored.
class LocaleCubit extends Cubit<LocaleState> {
  LocaleCubit({required this._storage, required Locale defaultLocale, this._followsDevice = true})
    : super(LocaleRestoring(locale: defaultLocale));

  static final _log = AppLogger.getLogger('LocaleCubit');

  final AppLocalStorage _storage;

  /// Whether [defaultLocale] is the phone's own language, so [followDevice] may move the app with the phone. False
  /// when this build pins a language (`AppBootstrapConfig.defaultLanguage`), which the phone never overrides.
  final bool _followsDevice;

  /// Whether a language of the user's own is on the device. Until there is one, the app follows the phone.
  bool _hasPick = false;

  /// Reads the stored language, so the app starts in the language the user picked. The default stays when no language
  /// is stored. It also stays, with an error in the log, when the stored value is not a language the app supports or
  /// cannot be read.
  ///
  /// The default is read as [state] holds it when the read answers, not as it was when the read started: the phone's
  /// language can change while the device is being read, and [followDevice] moves the default in place.
  Future<void> restore() async {
    final Object? stored;
    try {
      stored = await _storage.read(StorageKeys.language.key);
    } catch (error, stackTrace) {
      _log.error('restore: could not read the stored language, showing {}: {}', [state.locale, error]);
      addError(error, stackTrace);
      emit(LocaleReady(locale: state.locale));
      return;
    }
    if (stored == null) {
      _log.debug('restore: no stored language, showing {}', [state.locale]);
      emit(LocaleReady(locale: state.locale));
      return;
    }
    if (stored is! String || !S.delegate.isSupported(Locale(stored))) {
      _log.error('restore: the stored language {} is not supported, showing {}', [stored, state.locale]);
      emit(LocaleReady(locale: state.locale));
      return;
    }
    _log.debug('restore: showing the stored language {}', [stored]);
    _hasPick = true;
    emit(LocaleReady(locale: Locale(stored)));
  }

  /// Stores [locale] and then shows the app in it, so the next start uses it too. When it cannot be stored, the app
  /// keeps its language and [LocaleChangeFailure] says so.
  Future<void> changeLocale(Locale locale) async {
    final shown = state.locale;
    emit(LocaleChanging(locale: shown, requested: locale));
    if (await _store(locale)) {
      _log.info('changeLocale: {} -> {}', [shown, locale]);
      _hasPick = true;
      emit(LocaleReady(locale: locale));
    } else {
      emit(LocaleChangeFailure(locale: shown, requested: locale, errorCode: AppErrorCode.settingsChangeLanguageFailed));
    }
  }

  /// The phone's languages are now [deviceLocales], most preferred first: the app follows them while the user has
  /// picked no language, exactly as it follows the phone at the first launch. `App` reports every change
  /// (`didChangeLocales`), because Android keeps the activity alive through a language change.
  ///
  /// Does nothing once a language is stored on the device, while a pick is being stored, and in a build that pins a
  /// language: each of those wins over the phone. Before [restore] answers the app shows no page yet, so the phone
  /// only moves the language the restore falls back to and the first frame keeps waiting.
  void followDevice(Iterable<Locale> deviceLocales) {
    if (_hasPick || !_followsDevice || state is LocaleChanging) return;
    final locale = Locale(resolveStartupLanguage(deviceLocales, S.delegate.supportedLocales));
    if (locale == state.locale) return;
    _log.info('followDevice: no language of the user\'s own, following the phone: {} -> {}', [state.locale, locale]);
    emit(switch (state) {
      LocaleRestoring() => LocaleRestoring(locale: locale),
      LocaleReady() || LocaleChanging() || LocaleChangeFailure() => LocaleReady(locale: locale),
    });
  }

  /// Whether [locale] was stored. A refused or failed write is logged as an error.
  Future<bool> _store(Locale locale) async {
    try {
      final stored = await _storage.save(StorageKeys.language.key, locale.languageCode);
      if (!stored) _log.error('changeLocale: the device refused to store {}', [locale]);
      return stored;
    } catch (error, stackTrace) {
      _log.error('changeLocale: storing {} failed: {}', [locale, error]);
      addError(error, stackTrace);
      return false;
    }
  }
}
