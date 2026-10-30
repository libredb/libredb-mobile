import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';

/// Lets the user say whether the app is light, dark, or whatever the phone is set to.
///
/// The phone's own setting is one of the three choices, not a state the app falls out of: `ToggleBrightness` on the
/// login page only ever stores 'light' or 'dark', so until this dialog existed one tap there left the app unable to
/// follow the phone again (#410).
///
/// A tapped card applies at once, which makes the dialog a preview rather than a form — and which is why every way
/// out but Apply puts back the mode the dialog opened on: a user who tries dark, dislikes it and leaves must not be
/// left in dark. Cancel has done that since #371; the X, the barrier and the back gesture read as the same "nothing
/// committed" gesture and now do the same ([show] restores whatever the dialog did not commit, #412).
class BrightnessSelectionDialog extends StatelessWidget {
  const BrightnessSelectionDialog({super.key, required this.openedOn});

  /// What the app was on when the dialog opened, and what every way out but Apply goes back to.
  final ThemeMode openedOn;

  /// Opens the dialog and puts back [openedOn] unless Apply closed it — the one action that keeps a previewed mode.
  static Future<void> show(BuildContext context) async {
    final theme = context.read<ThemeBloc>();
    final openedOn = theme.state.themeMode;
    final kept = await showDialog<bool>(
      context: context,
      builder: (context) => BrightnessSelectionDialog(openedOn: openedOn),
    );
    if (kept == true || theme.state.themeMode == openedOn) return;
    theme.add(SelectBrightness(themeMode: openedOn));
    // The dialog is gone, so the only thing that moved is the tile behind it. Announce the mode that is back, as the
    // card taps announce the ones the user tried (#375).
    if (context.mounted) _announce(context, openedOn);
  }

  /// The modes in the order they are offered: the phone's setting first, because it is the one a user comes back to.
  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  static String _title(S l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.system => l10n.brightness_system,
    ThemeMode.light => l10n.brightness_light,
    ThemeMode.dark => l10n.brightness_dark,
  };

  static String _description(S l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.system => l10n.brightness_system_description,
    ThemeMode.light => l10n.brightness_light_description,
    ThemeMode.dark => l10n.brightness_dark_description,
  };

  static IconData _icon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, state) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_6_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.brightness_dialog_title, style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.brightness_dialog_subtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final mode in _modes) ...[
                          if (mode != _modes.first) const SizedBox(height: 12),
                          _buildModeCard(context, mode: mode, isSelected: state.themeMode == mode),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                      FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.apply)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeCard(BuildContext context, {required ThemeMode mode, required bool isSelected}) {
    final l10n = S.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final onCard = isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surface,
      child: InkWell(
        onTap: () => _apply(context, mode),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(_icon(mode), color: onCard),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(l10n, mode),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: onCard, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _description(l10n, mode),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  void _apply(BuildContext context, ThemeMode mode) {
    context.read<ThemeBloc>().add(SelectBrightness(themeMode: mode));
    _announce(context, mode);
  }

  /// Says which mode is in force now. The dialog stays open on a card tap and only its colours change, which moves
  /// nothing a screen reader reports; without this a blind user taps a card and hears nothing at all (#375).
  static void _announce(BuildContext context, ThemeMode mode) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      S.of(context).brightness_applied(_title(S.of(context), mode)),
      Directionality.of(context),
    );
  }
}

/// Hands [builder] the name, in the app's language, of the day and night mode in force now — what a settings tile
/// shows so the user sees whether the app follows the phone without opening the dialog.
///
/// It lives here beside the dialog, and not in the feature that shows it, so that a feature does not have to import
/// the app-level [ThemeBloc] to name the mode (`test/architecture/import_guard_test.dart`).
class BrightnessModeInForce extends StatelessWidget {
  const BrightnessModeInForce({super.key, required this.builder});

  final Widget Function(BuildContext context, String name) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      buildWhen: (previous, current) => previous.themeMode != current.themeMode,
      builder: (context, state) => builder(context, BrightnessSelectionDialog._title(S.of(context), state.themeMode)),
    );
  }
}
