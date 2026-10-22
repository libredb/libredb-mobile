# Development

This page collects what a contributor needs beyond the quick start in the [README](../README.md): the toolchain, the ways to slice the test suite, the feature generator and the CI checks.
The code conventions are in [CLAUDE.md](../CLAUDE.md), and the test structure in [testing-architecture.md](testing-architecture.md).

## Toolchain

- Flutter 3.47.7 and Dart 3.13.5, through [FVM](https://fvm.app/) (`fvm install` reads the version from `.fvmrc`).
- The Android SDK for Android builds, and Xcode on macOS for iOS builds.
- The app runs on Android 8.0 (API 26) and newer, and on iOS 15 and newer.

| Android component | Version |
| --- | --- |
| Gradle | 9.3.1 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin | 2.4.0 (built-in Kotlin, `android.builtInKotlin=true`) |
| Java compatibility | 17 |
| NDK | `flutter.ndkVersion` |
| Min SDK | 26, which `sentry_flutter` 10 requires |
| Build scripts | Kotlin DSL (`.gradle.kts`) |

## Tests

```shell
fvm flutter test                                                        # everything
fvm flutter test --exclude-tags widget                                  # the fast unit loop
fvm flutter test --tags widget                                          # widget tests only
fvm flutter test --tags golden                                          # golden tests only
fvm flutter test --tags golden --update-goldens                         # after an intentional UI change
fvm flutter test --concurrency=1 --test-randomize-ordering-seed=random  # to find order-dependent tests
```

The tags are declared in `dart_test.yaml`.
The smoke test `test/integration/app_smoke_test.dart` boots the whole app in mock mode and drives it from sign-in to the dashboard; it runs headless as part of `flutter test`.

## Git hooks

`bash scripts/setup_hooks.sh` installs a pre-commit hook that checks formatting and runs the analyzer, and a pre-push hook that runs the tests.

## A new feature

`fvm dart run tool/generate_feature.dart <feature>` writes a CRUD feature under `lib/features/<feature>/` with its tests and mock data.
It then prints the steps left to do by hand: registering the repository, the routes, the menu entry and the translations, and adding the repository methods to `test/architecture/mock_asset_coverage_test.dart`.
The full list of steps for a feature is under "Adding a New Feature" in [CLAUDE.md](../CLAUDE.md).
`test/architecture/feature_generator_test.dart` runs it on every test run, so its output stays formatted, analyzed and green.

## CI

Two GitHub Actions workflows run on pushes and pull requests:

- `build_and_test.yml` checks formatting, analyzes, runs the tests with coverage and fails below 65 percent (`scripts/check_coverage.sh`), builds the release APK and app bundle, and runs the Android JVM unit tests.
- `sonar_scanner.yml` sends the analysis and the coverage to SonarCloud; it needs the `SONAR_TOKEN` secret on the repository or the organization.
