import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';

part 'theme_event.dart';
part 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState()) {
    on<LoadTheme>(_onLoadTheme);
    on<ChangeThemePalette>(_onChangeThemePalette);
    on<ToggleBrightness>(_onToggleBrightness);
    on<SelectBrightness>(_onSelectBrightness);
  }

  /// The stored name of each mode, and the mode of each stored name. Anything else — an old name, a value of another
  /// type, nothing at all — reads back as [ThemeMode.system], so the app follows the phone until the user says
  /// otherwise.
  static const _storedBrightness = {ThemeMode.system: 'system', ThemeMode.light: 'light', ThemeMode.dark: 'dark'};

  static ThemeMode _brightnessOf(Object? stored) =>
      _storedBrightness.keys.firstWhere((mode) => _storedBrightness[mode] == stored, orElse: () => ThemeMode.system);

  Future<void> _onLoadTheme(LoadTheme event, Emitter<ThemeState> emit) async {
    try {
      final themeMode = _brightnessOf(await AppLocalStorage().read(StorageKeys.brightness.key));

      final palettePref = await AppLocalStorage().read(StorageKeys.theme.key);
      AppThemePalette palette = AppThemePalette.classic;

      if (palettePref != null) {
        switch (palettePref) {
          case 'classic':
            palette = AppThemePalette.classic;
            break;
          case 'nature':
            palette = AppThemePalette.nature;
            break;
          case 'sunset':
            palette = AppThemePalette.sunset;
            break;
          default:
            palette = AppThemePalette.classic;
        }
      }

      emit(state.copyWith(palette: palette, themeMode: themeMode));
    } catch (_) {
      emit(state.copyWith(palette: AppThemePalette.classic, themeMode: ThemeMode.system));
    }
  }

  Future<void> _onChangeThemePalette(ChangeThemePalette event, Emitter<ThemeState> emit) async {
    emit(state.copyWith(palette: event.palette));
    try {
      String paletteName;
      switch (event.palette) {
        case AppThemePalette.classic:
          paletteName = 'classic';
          break;
        case AppThemePalette.nature:
          paletteName = 'nature';
          break;
        case AppThemePalette.sunset:
          paletteName = 'sunset';
          break;
      }
      await AppLocalStorage().save(StorageKeys.theme.key, paletteName);
    } catch (_) {}
  }

  Future<void> _onToggleBrightness(ToggleBrightness event, Emitter<ThemeState> emit) async {
    final ThemeMode newMode;
    if (state.themeMode == ThemeMode.system) {
      final systemIsDark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      newMode = systemIsDark ? ThemeMode.light : ThemeMode.dark;
    } else {
      newMode = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    }
    emit(state.copyWith(themeMode: newMode));
    try {
      await AppLocalStorage().save(StorageKeys.brightness.key, newMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Puts the app on the mode the user picked and stores it, [ThemeMode.system] included. [ToggleBrightness] only ever
  /// stores 'light' or 'dark', so before this event one tap on the login toggle left the app unable to follow the
  /// phone's setting again (#410).
  Future<void> _onSelectBrightness(SelectBrightness event, Emitter<ThemeState> emit) async {
    emit(state.copyWith(themeMode: event.themeMode));
    try {
      await AppLocalStorage().save(StorageKeys.brightness.key, _storedBrightness[event.themeMode]);
    } catch (_) {}
  }
}
