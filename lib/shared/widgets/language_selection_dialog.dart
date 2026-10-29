import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/localization/locale_cubit.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/l10n/app_error_code_l10n.dart';
import 'package:libredb_mobile/shared/l10n/locale_l10n.dart';

/// Lets the user pick the language of the app among the languages it supports, each named in its own language. A pick
/// shows the app in that language at once, is stored for the next start, and closes the dialog. When it cannot be
/// stored, the dialog closes, the app keeps its language and a snack bar says so.
class LanguageSelectionDialog extends StatelessWidget {
  const LanguageSelectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(context: context, builder: (_) => const LanguageSelectionDialog());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LocaleCubit, LocaleState>(
      // A pick has settled once the state leaves LocaleChanging.
      listenWhen: (previous, current) => previous is LocaleChanging,
      listener: _onPickSettled,
      // While a pick is being stored neither a tap outside nor back closes the dialog: it closes itself once the pick
      // settles, and says so when the pick fails.
      builder: (context, state) => PopScope(
        canPop: state is! LocaleChanging,
        child: RadioGroup<Locale>(
          groupValue: state.locale,
          // A tap on the language already shown answers null, see [RadioListTile.toggleable]; it is a pick of that
          // same language, so it is stored like any other.
          onChanged: (locale) => context.read<LocaleCubit>().changeLocale(locale ?? state.locale),
          child: SimpleDialog(
            title: Text(S.of(context).language_select),
            children: [
              for (final locale in S.delegate.supportedLocales)
                RadioListTile<Locale>(
                  value: locale,
                  title: Text(locale.endonym),
                  enabled: state is! LocaleChanging,
                  // Without this a tap on the language already shown does nothing at all: the dialog stays open and
                  // nothing is stored, so the phone still moves the app later. That is how a user pins the language
                  // the app opened in — the one case where the pick changes nothing on screen and everything after.
                  toggleable: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPickSettled(BuildContext context, LocaleState state) {
    switch (state) {
      case LocaleReady():
        Navigator.of(context).pop();
      case LocaleChangeFailure(:final errorCode):
        final messenger = ScaffoldMessenger.of(context);
        final message = errorCode.resolve(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(message)));
      case LocaleRestoring() || LocaleChanging():
        break;
    }
  }
}
