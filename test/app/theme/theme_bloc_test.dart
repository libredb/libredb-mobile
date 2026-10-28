import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:libredb_mobile/app/theme/theme_bloc.dart';
import 'package:libredb_mobile/infrastructure/storage/local_storage.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme_palette.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [SharedPreferences] whose writes complete out of order: write number n waits [delays] at index n before it
/// lands, so a later write can reach the store ahead of an earlier one. A platform channel is free to behave this
/// way; the in-memory double every other test runs on never does, which is why the race this fake exposes cannot be
/// seen without it. Only the members [AppLocalStorage] calls are implemented, so an unimplemented one throws rather
/// than passing quietly.
class _OutOfOrderPrefs extends Fake implements SharedPreferences {
  _OutOfOrderPrefs(this.delays);

  /// How long write number n takes to land, by index; the last entry covers every write after it.
  final List<Duration> delays;

  /// The values that reached the store, in the order they landed — not the order they were asked for.
  final List<Object?> landed = [];

  final Map<String, Object> _store = {};
  int _started = 0;

  @override
  Future<bool> setString(String key, String value) async {
    final delay = delays[_started < delays.length ? _started : delays.length - 1];
    _started++;
    await Future<void>.delayed(delay);
    _store[key] = value;
    landed.add(value);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    return true;
  }

  @override
  Object? get(String key) => _store[key];

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }
}

void main() {
  group('ThemeState', () {
    test('default state has classic palette and system theme mode', () {
      const state = ThemeState();
      expect(state.palette, AppThemePalette.classic);
      expect(state.themeMode, ThemeMode.system);
    });

    test('copyWith updates palette', () {
      const state = ThemeState();
      final updated = state.copyWith(palette: AppThemePalette.nature);
      expect(updated.palette, AppThemePalette.nature);
      expect(updated.themeMode, ThemeMode.system);
    });

    test('copyWith updates themeMode', () {
      const state = ThemeState();
      final updated = state.copyWith(themeMode: ThemeMode.dark);
      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.palette, AppThemePalette.classic);
    });

    test('copyWith with no args preserves all values', () {
      const state = ThemeState(palette: AppThemePalette.sunset, themeMode: ThemeMode.dark);
      final updated = state.copyWith();
      expect(updated.palette, AppThemePalette.sunset);
      expect(updated.themeMode, ThemeMode.dark);
    });
  });

  group('ThemeEvent', () {
    test('LoadTheme can be instantiated', () {
      const event = LoadTheme();
      expect(event, isA<ThemeEvent>());
    });

    test('ChangeThemePalette holds palette', () {
      const event = ChangeThemePalette(palette: AppThemePalette.nature);
      expect(event.palette, AppThemePalette.nature);
    });

    test('ToggleBrightness can be instantiated', () {
      const event = ToggleBrightness();
      expect(event, isA<ThemeEvent>());
    });

    test('SelectBrightness holds the mode it selects', () {
      const event = SelectBrightness(themeMode: ThemeMode.system);
      expect(event.themeMode, ThemeMode.system);
    });
  });

  group('ThemeBloc', () {
    test('initial state has classic palette and system theme mode', () {
      final bloc = ThemeBloc();
      expect(bloc.state.palette, AppThemePalette.classic);
      expect(bloc.state.themeMode, ThemeMode.system);
      bloc.close();
    });

    group('LoadTheme', () {
      blocTest<ThemeBloc, ThemeState>(
        'emits classic palette and system mode when no preferences stored',
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [
          isA<ThemeState>()
              .having((s) => s.palette, 'palette', AppThemePalette.classic)
              .having((s) => s.themeMode, 'themeMode', ThemeMode.system),
        ],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits dark mode when brightness preference is dark',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.brightness.key, 'dark');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [
          isA<ThemeState>()
              .having((s) => s.themeMode, 'themeMode', ThemeMode.dark)
              .having((s) => s.palette, 'palette', AppThemePalette.classic),
        ],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits light mode when brightness preference is light',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.brightness.key, 'light');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.themeMode, 'themeMode', ThemeMode.light)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits system mode when brightness preference is system',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.brightness.key, 'system');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.themeMode, 'themeMode', ThemeMode.system)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'falls back to system mode for an unknown brightness preference',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.brightness.key, 'twilight');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.themeMode, 'themeMode', ThemeMode.system)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'falls back to system mode when the stored brightness is not even a string',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.brightness.key, 3);
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.themeMode, 'themeMode', ThemeMode.system)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits nature palette when theme preference is nature',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.theme.key, 'nature');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.palette, 'palette', AppThemePalette.nature)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits sunset palette when theme preference is sunset',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.theme.key, 'sunset');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.palette, 'palette', AppThemePalette.sunset)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'defaults to classic palette for unknown theme preference',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.theme.key, 'unknown_palette');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [isA<ThemeState>().having((s) => s.palette, 'palette', AppThemePalette.classic)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'loads both dark mode and sunset palette together',
        setUp: () async {
          await AppLocalStorage().save(StorageKeys.brightness.key, 'dark');
          await AppLocalStorage().save(StorageKeys.theme.key, 'sunset');
        },
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const LoadTheme()),
        expect: () => [
          isA<ThemeState>()
              .having((s) => s.themeMode, 'themeMode', ThemeMode.dark)
              .having((s) => s.palette, 'palette', AppThemePalette.sunset),
        ],
      );
    });

    group('ChangeThemePalette', () {
      blocTest<ThemeBloc, ThemeState>(
        'emits state with nature palette',
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ChangeThemePalette(palette: AppThemePalette.nature)),
        expect: () => [isA<ThemeState>().having((s) => s.palette, 'palette', AppThemePalette.nature)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits state with sunset palette',
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ChangeThemePalette(palette: AppThemePalette.sunset)),
        expect: () => [isA<ThemeState>().having((s) => s.palette, 'palette', AppThemePalette.sunset)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'emits state with classic palette',
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ChangeThemePalette(palette: AppThemePalette.classic)),
        expect: () => [isA<ThemeState>().having((s) => s.palette, 'palette', AppThemePalette.classic)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'persists palette to storage',
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ChangeThemePalette(palette: AppThemePalette.nature)),
        verify: (_) async {
          final stored = await AppLocalStorage().read(StorageKeys.theme.key);
          expect(stored, 'nature');
        },
      );

      blocTest<ThemeBloc, ThemeState>(
        'persists sunset palette to storage',
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ChangeThemePalette(palette: AppThemePalette.sunset)),
        verify: (_) async {
          final stored = await AppLocalStorage().read(StorageKeys.theme.key);
          expect(stored, 'sunset');
        },
      );
    });

    group('ToggleBrightness', () {
      blocTest<ThemeBloc, ThemeState>(
        'toggles from dark to light',
        seed: () => const ThemeState(themeMode: ThemeMode.dark),
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ToggleBrightness()),
        expect: () => [isA<ThemeState>().having((s) => s.themeMode, 'themeMode', ThemeMode.light)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'toggles from light to dark',
        seed: () => const ThemeState(themeMode: ThemeMode.light),
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ToggleBrightness()),
        expect: () => [isA<ThemeState>().having((s) => s.themeMode, 'themeMode', ThemeMode.dark)],
      );

      blocTest<ThemeBloc, ThemeState>(
        'persists brightness to storage when toggled to dark',
        seed: () => const ThemeState(themeMode: ThemeMode.light),
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ToggleBrightness()),
        verify: (_) async {
          final stored = await AppLocalStorage().read(StorageKeys.brightness.key);
          expect(stored, 'dark');
        },
      );

      blocTest<ThemeBloc, ThemeState>(
        'persists brightness to storage when toggled to light',
        seed: () => const ThemeState(themeMode: ThemeMode.dark),
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ToggleBrightness()),
        verify: (_) async {
          final stored = await AppLocalStorage().read(StorageKeys.brightness.key);
          expect(stored, 'light');
        },
      );

      blocTest<ThemeBloc, ThemeState>(
        'preserves palette when toggling brightness',
        seed: () => const ThemeState(palette: AppThemePalette.sunset, themeMode: ThemeMode.dark),
        build: () => ThemeBloc(),
        act: (bloc) => bloc.add(const ToggleBrightness()),
        expect: () => [
          isA<ThemeState>()
              .having((s) => s.themeMode, 'themeMode', ThemeMode.light)
              .having((s) => s.palette, 'palette', AppThemePalette.sunset),
        ],
      );
    });

    // ToggleBrightness only ever writes 'light' or 'dark', so one tap on the login toggle stranded the app off the
    // phone's setting for good: no event could write 'system' back (#410).
    group('SelectBrightness', () {
      // `wasStored` is the name of another mode, the one storage already holds when the restart test selects
      // `mode`. A fresh ThemeBloc starts on ThemeMode.system and an unreadable value reads back as system too, so a
      // restart test that began on empty storage proved nothing for the system row: it stayed green with the save
      // deleted from the handler. Opening on another mode's name is what makes every row of the table fail when the
      // selection does not reach storage.
      for (final (mode, stored, wasStored) in [
        (ThemeMode.system, 'system', 'dark'),
        (ThemeMode.light, 'light', 'dark'),
        (ThemeMode.dark, 'dark', 'light'),
      ]) {
        blocTest<ThemeBloc, ThemeState>(
          'selecting $mode emits it and keeps the palette',
          seed: () => const ThemeState(palette: AppThemePalette.sunset, themeMode: ThemeMode.dark),
          build: () => ThemeBloc(),
          act: (bloc) => bloc.add(SelectBrightness(themeMode: mode)),
          expect: () => [
            isA<ThemeState>()
                .having((s) => s.themeMode, 'themeMode', mode)
                .having((s) => s.palette, 'palette', AppThemePalette.sunset),
          ],
        );

        blocTest<ThemeBloc, ThemeState>(
          'selecting $mode stores \'$stored\'',
          build: () => ThemeBloc(),
          act: (bloc) => bloc.add(SelectBrightness(themeMode: mode)),
          verify: (_) async {
            expect(await AppLocalStorage().read(StorageKeys.brightness.key), stored);
          },
        );

        blocTest<ThemeBloc, ThemeState>(
          "a restart after selecting $mode comes back to $mode, over a device that held '$wasStored'",
          setUp: () async {
            await AppLocalStorage().save(StorageKeys.brightness.key, wasStored);
          },
          build: () => ThemeBloc(),
          act: (bloc) async {
            bloc.add(SelectBrightness(themeMode: mode));
            await Future<void>.delayed(Duration.zero);
          },
          verify: (_) async {
            final restarted = ThemeBloc()..add(const LoadTheme());
            await expectLater(restarted.stream, emits(isA<ThemeState>().having((s) => s.themeMode, 'themeMode', mode)));
            await restarted.close();
          },
        );
      }

      // Tap Dark, then tap Cancel, which puts the mode the dialog opened on back: two SelectBrightness events on a
      // routine two-tap path. The handler emits synchronously and then awaits the write, so under bloc's default
      // concurrent transformer the second write starts while the first is still in flight. A platform that then
      // completes them out of order leaves storage on 'dark' while the UI says the phone decides, and the next
      // launch opens dark — #371 moved into persistence. EventTransformers.queue() is what keeps the writes in
      // event order, and this fake is the out-of-order platform that shows it.
      test('the mode the user ended on is the one stored, even when the first write lands last', () async {
        final prefs = _OutOfOrderPrefs(const [Duration(milliseconds: 80), Duration(milliseconds: 1)]);
        AppLocalStorage().setPreferencesInstance(prefs);
        // Nothing else puts the real SharedPreferences back on the AppLocalStorage singleton, and the global reset
        // clears storage through whatever is installed, so this test returns it before the next one runs.
        addTearDown(() async => AppLocalStorage().setPreferencesInstance(await SharedPreferences.getInstance()));

        final bloc = ThemeBloc()
          ..add(const SelectBrightness(themeMode: ThemeMode.dark))
          ..add(const SelectBrightness(themeMode: ThemeMode.system));
        addTearDown(bloc.close);

        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(bloc.state.themeMode, ThemeMode.system);
        expect(prefs.landed, ['dark', 'system'], reason: 'the writes must land in the order the user tapped');
        expect(prefs.get(StorageKeys.brightness.key), 'system');
      });
    });
  });
}
