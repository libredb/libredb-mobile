@Tags(['widget'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libredb_mobile/app/app.dart';
import 'package:libredb_mobile/app/di/mock_sign_in_dependencies.dart';
import 'package:libredb_mobile/app/system_bars.dart';
import 'package:libredb_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:libredb_mobile/shared/design_system/theme/app_theme.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mock_classes.dart';

/// The system bars of a running app, against the theme the app is painted in.
///
/// Holds the Play Console's "Edge-to-edge may not display for all users", raised against the 1.2.0 release.
///
/// The app targets SDK 36, so Android 15 and up draw it edge-to-edge and ignore `systemNavigationBarColor`: the
/// navigation bar is transparent and the app's own pixels sit behind it. `SystemUiOverlayStyle.dark`, the style
/// `MaterialApp` sets under a light theme, asks for `systemNavigationBarIconBrightness: Brightness.light` — white
/// icons, and a white gesture handle, over the white `surface` of the light theme. The status bar of the same
/// style is correct, and these tests hold it that way while the navigation bar is fixed.
void main() {
  /// Opens the app on the login page, with the phone set to [platformBrightness] — the app follows it, since no
  /// brightness is stored and `ThemeBloc` restores `ThemeMode.system` — and answers the style the app then asked
  /// the platform for.
  Future<SystemUiOverlayStyle> styleOnOpen(WidgetTester tester, Brightness platformBrightness) async {
    tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final secureStorage = MockISecureStorage();
    when(() => secureStorage.read(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(App(dependencies: MockSignInDependencies(), language: 'en', secureStorage: secureStorage));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget, reason: 'the app has to be painted before its bars are read');
    expect(
      Theme.of(tester.element(find.byType(LoginScreen))).brightness,
      platformBrightness,
      reason: 'the app has to be on the theme whose bars are being measured',
    );

    final style = SystemChrome.latestStyle;
    expect(style, isNotNull, reason: 'the app never told the platform how to draw its system bars');
    return style!;
  }

  testWidgets('the light theme asks for dark navigation bar icons, over a navigation bar it paints itself', (
    tester,
  ) async {
    final style = await styleOnOpen(tester, Brightness.light);

    expect(
      style.systemNavigationBarIconBrightness,
      Brightness.dark,
      reason: 'white icons on the white surface Android 15 leaves behind the transparent navigation bar',
    );
    expect(style.systemNavigationBarColor, AppTheme.light().colorScheme.surface);
    // Unchanged, and held here: MaterialApp already gets these two right, and the annotation must not blank them.
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.statusBarBrightness, Brightness.light, reason: 'iOS reads the background, not the icons');
  });

  testWidgets('the dark theme asks for light navigation bar icons, over a navigation bar it paints itself', (
    tester,
  ) async {
    final style = await styleOnOpen(tester, Brightness.dark);

    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.systemNavigationBarColor, AppTheme.dark().colorScheme.surface);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
  });

  test('the icons of a scheme contrast with it, and the bar carries its surface', () {
    final light = systemBarsFor(AppTheme.light().colorScheme);
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);
    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.systemNavigationBarColor, AppTheme.light().colorScheme.surface);

    final dark = systemBarsFor(AppTheme.dark().colorScheme);
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.systemNavigationBarColor, AppTheme.dark().colorScheme.surface);
  });
}
