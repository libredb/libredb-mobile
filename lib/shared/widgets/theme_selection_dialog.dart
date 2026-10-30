import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/generated/l10n.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';

/// Lets the user try the palettes and keep one.
///
/// A tapped card applies at once, which is what makes the dialog a preview rather than a form — and which is why
/// every way out but Apply puts back the palette the dialog opened on. Both buttons used to do nothing but pop, so a
/// user who tried one, disliked it and pressed Cancel kept what they had just rejected (#371); the X, the barrier and
/// the back gesture read as the same "nothing committed" gesture and kept it too until [show] started restoring
/// whatever the dialog did not commit (#412).
class ThemeSelectionDialog extends StatelessWidget {
  const ThemeSelectionDialog({super.key, required this.openedOn});

  /// What the app was wearing when the dialog opened, and what every way out but Apply goes back to.
  final AppThemePalette openedOn;

  /// Opens the dialog and puts back [openedOn] unless Apply closed it — the one action that keeps a tried palette.
  static Future<void> show(BuildContext context) async {
    final theme = context.read<ThemeBloc>();
    final openedOn = theme.state.palette;
    final kept = await showDialog<bool>(
      context: context,
      builder: (context) => ThemeSelectionDialog(openedOn: openedOn),
    );
    if (kept == true || theme.state.palette == openedOn) return;
    theme.add(ChangeThemePalette(palette: openedOn));
    // The dialog is gone, so the only thing that moved is the tile behind it. Announce the palette that is back, as
    // the card taps announce the ones the user tried (#375).
    if (context.mounted) _announce(context, openedOn);
  }

  static String _title(S l10n, AppThemePalette palette) => switch (palette) {
    AppThemePalette.classic => l10n.theme_palette_classic,
    AppThemePalette.nature => l10n.theme_palette_nature,
    AppThemePalette.sunset => l10n.theme_palette_sunset,
  };

  static String _description(S l10n, AppThemePalette palette) => switch (palette) {
    AppThemePalette.classic => l10n.theme_palette_classic_description,
    AppThemePalette.nature => l10n.theme_palette_nature_description,
    AppThemePalette.sunset => l10n.theme_palette_sunset_description,
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
                    const Icon(Icons.palette_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.theme_dialog_title, style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.theme_dialog_subtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildThemeCard(
                          context,
                          title: _title(l10n, AppThemePalette.classic),
                          description: _description(l10n, AppThemePalette.classic),
                          icon: AppThemePalette.classic.icon,
                          palette: AppThemePalette.classic,
                          isSelected: state.palette == AppThemePalette.classic,
                        ),
                        const SizedBox(height: 16),
                        _buildThemeCard(
                          context,
                          title: _title(l10n, AppThemePalette.nature),
                          description: _description(l10n, AppThemePalette.nature),
                          icon: AppThemePalette.nature.icon,
                          palette: AppThemePalette.nature,
                          isSelected: state.palette == AppThemePalette.nature,
                        ),
                        const SizedBox(height: 16),
                        _buildThemeCard(
                          context,
                          title: _title(l10n, AppThemePalette.sunset),
                          description: _description(l10n, AppThemePalette.sunset),
                          icon: AppThemePalette.sunset.icon,
                          palette: AppThemePalette.sunset,
                          isSelected: state.palette == AppThemePalette.sunset,
                        ),
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

  Widget _buildThemeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required AppThemePalette palette,
    required bool isSelected,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () {
          _applyTheme(context, palette);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ],
              ),
              const SizedBox(height: 16),
              _buildThemePreview(context, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemePreview(BuildContext context, AppThemePalette palette) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPreviewSide(context, isLight: true, palette: palette)),
          Container(width: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          Expanded(child: _buildPreviewSide(context, isLight: false, palette: palette)),
        ],
      ),
    );
  }

  Widget _buildPreviewSide(BuildContext context, {required bool isLight, required AppThemePalette palette}) {
    final previewTheme = isLight ? AppTheme.light(palette) : AppTheme.dark(palette);

    return Theme(
      data: previewTheme,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: previewTheme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: isLight ? const Radius.circular(8) : Radius.zero,
            bottomLeft: isLight ? const Radius.circular(8) : Radius.zero,
            topRight: !isLight ? const Radius.circular(8) : Radius.zero,
            bottomRight: !isLight ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: previewTheme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 8,
                    width: 30,
                    decoration: BoxDecoration(
                      color: previewTheme.colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 6,
                    width: 20,
                    decoration: BoxDecoration(
                      color: previewTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 6,
                    width: 25,
                    decoration: BoxDecoration(
                      color: previewTheme.colorScheme.onSurface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLight ? Icons.light_mode : Icons.dark_mode,
                  size: 12,
                  color: previewTheme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyTheme(BuildContext context, AppThemePalette palette) {
    context.read<ThemeBloc>().add(ChangeThemePalette(palette: palette));
    _announce(context, palette);
  }

  /// Says which palette is in force now. The dialog stays open on a card tap and only its colours change, which moves
  /// nothing a screen reader reports; without this a blind user taps a card and hears nothing at all (#375).
  static void _announce(BuildContext context, AppThemePalette palette) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      S.of(context).theme_palette_applied(_title(S.of(context), palette)),
      Directionality.of(context),
    );
  }
}
