# Testing Architecture

This document explains how tests are structured, bootstrapped, and written in this app.
If you are new to the project, read this before adding tests.

For the HTTP **mock data** layer (how `assets/mock/*.json` is served to the app
at dev/test time), see [`mock-architecture.md`](mock-architecture.md). This
document is about the **test suite** itself.

---

## Philosophy

- **Mirror the source tree.** `test/` mirrors `lib/` one-to-one, so the test for
  any file is exactly where you'd expect it.
- **Mock at the boundary, not the wire.** Unit and BLoC tests mock the
  repository/use-case interface with `mocktail`. They do not go through HTTP or
  the mock interceptor.
- **One global bootstrap.** Cross-cutting setup (binding init, logger, fallback
  registration, per-test environment reset) lives in one place, not in every
  file. Test files contain only what is unique to them.
- **Sealed states, exhaustive matching.** BLoC tests assert on sealed state
  variants (see `CLAUDE.md` → State Modeling).
- **Determinism.** Tests must not depend on wall-clock time, ordering, or
  leaked state between tests.

---

## Test stack

| Tool | Purpose |
| --- | --- |
| `flutter_test` | Test runner, `WidgetTester`, matchers |
| `bloc_test` | `blocTest(...)` + `MockBloc` for BLoC/Cubit state assertions |
| `mocktail` | Mocks/fakes without code generation (`Mock`, `Fake`, `when`, `verify`, `any`) |
| `fake_async` | Virtual time for timer/timeout logic |

No `mockito`, no `build_runner` for mocks — `mocktail` is the single mocking
library. The end-to-end smoke is a full-app widget test under `test/integration/`
(see below) — it runs headless under `flutter test`, so the `integration_test`
package is not a dependency.

---

## Directory layout

`test/` mirrors `lib/`:

```
test/
├── flutter_test_config.dart   # GLOBAL bootstrap (auto-discovered by flutter test)
├── support/
│   ├── dart_code.dart         # codeOnly(): Dart source without comments and string text, for guards
│   └── test_env.dart          # TestEnv: reset(), authenticate(), apiClient(), autoReset
├── mocks/
│   ├── mock_classes.dart      # Mock*/Fake* classes + registerAllFallbackValues()
│   └── fake_data.dart         # Shared fixtures (mockUserFullPayload, ...)
├── architecture/              # Meta-tests enforcing rules (see below)
│   ├── android_manifest_test.dart    # Android INTERNET, backup off
│   ├── arb_translations_test.dart    # every English message has a Turkish one with the same placeholders, no ARB key twice
│   ├── credential_to_string_test.dart # a class with a credential field keeps it out of toString
│   ├── cubit_over_bloc_test.dart     # a feature Cubit holding a repository says why it is not a Bloc
│   ├── feature_generator_test.dart   # tool/generate_feature.dart output is clean and passes its tests
│   ├── import_guard_test.dart        # layer dependency rules, url_launcher only in external_link.dart
│   ├── log_lazy_arguments_test.dart  # AppLogger arguments are not turned into text before the level check
│   ├── log_placeholders_test.dart    # every AppLogger call has one {} for each argument
│   ├── log_secrets_test.dart         # no AppLogger call passes a value named for a credential
│   ├── mock_asset_coverage_test.dart # every repository method succeeds on the mock
│   ├── mock_asset_naming_test.dart   # mock asset names use '_', never '-'
│   ├── oidc_platform_setup_test.dart # OIDC scheme placeholder, no client secret
│   ├── sentry_native_scrub_patterns_test.dart # Kotlin scrub patterns equal the Dart ones, Gradle DSN gate
│   ├── test_file_naming_test.dart    # forbids *.test.dart (dot) files
│   └── ui_text_localized_test.dart   # widgets show ARB text through S, not string literals
├── fixtures/                  # inputs and expected outputs shared with the Android JVM tests
├── app/                       # app/ layer tests (app_test.dart, router, shell, theme, di, ...)
├── core/                      # core/ tests (errors, logging, security, result, ...)
├── features/<feature>/        # application/ data/ domain/ navigation/ presentation/
├── infrastructure/            # config, http (+ interceptors), storage, cache, ...
├── integration/               # app_smoke_test.dart, the full-app smoke test
└── shared/                    # design_system, l10n, models, utils, widgets
```

---

## The global bootstrap

`flutter test` automatically discovers `test/flutter_test_config.dart` and wraps
**every** test under `test/` with its `testExecutable`. This is where all
cross-cutting setup lives:

```dart
// test/flutter_test_config.dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // One-time per isolate.
  TestWidgetsFlutterBinding.ensureInitialized();
  AutomatedTestWidgetsFlutterBinding.instance.defaultTestTimeout = const Timeout.factor(1); // see "Timeouts" below
  AppLogger.configure(isProduction: false, logFormat: LogFormat.simple);
  EquatableConfig.stringify = true;
  registerAllFallbackValues();

  // Per-test in every file, opted out or not (see "The asset cache" below).
  setUp(rootBundle.clear);
  tearDown(rootBundle.clear);

  // Per-test, unless a file opts out.
  setUp(() async { if (TestEnv.autoReset) await TestEnv.reset(); });
  tearDown(() async { if (TestEnv.autoReset) await TestEnv.reset(); });

  await testMain();
}
```

**What this means for you:** a normal test file needs **no** manual setup for
storage, router, secure-storage, fallback registration, or logging. Just write
the test. The environment is clean before and after every test.

### `TestEnv` (`test/support/test_env.dart`)

A static helper — the single test-support entry point:

| Member | Use |
| --- | --- |
| `TestEnv.reset()` | Re-installs the secure-storage mock and clears all storage. No language is stored, so an `App` starts in the language passed to it, as on a first launch. Called automatically by the bootstrap. |
| `TestEnv.authenticate({SessionTarget target})` | Seeds a mock JWT and the session target, Studio unless `target` says otherwise, as a sign-in of this build stores them. Call in `setUp` or a test body, **never** in `setUpAll`. |
| `TestEnv.apiClient({Dio? dio})` | Builds a mock-backed `ApiClient` (test `AppConfig`, shared secure adapter). Pass a stub `dio` to control responses. |
| `TestEnv.platformApiClient({Dio? dio})` | Builds the mock-backed LibreDB Platform client, `PlatformApiClient`, the same way. |
| `TestEnv.autoReset` | Set `false` in a file's `setUpAll` to opt that file out of the global reset. |

> **Key facts that make this safe**
> - `flutter test` runs each file in its **own isolate**, so `TestEnv.autoReset`
>   is isolated per file — opting out in one file cannot affect another.
> - A file's `setUpAll` runs *after* the bootstrap body (which registers the
>   global `setUp`) but *before* the first test's `setUp`, so flipping
>   `autoReset` in `setUpAll` is observed by the global reset at runtime.
> - The global `setUp` clears the secure store before every test — that's why
>   `authenticate()` must run in `setUp`/test body, not `setUpAll`.

### Opting out (self-mocking files)

A file that installs its own `MethodChannel` or `SharedPreferences` mock should
opt out so the global reset doesn't trample it:

```dart
void main() {
  setUpAll(() => TestEnv.autoReset = false); // first thing in main()
  // ... file manages its own setUp/tearDown ...
}
```

Real example: `test/infrastructure/storage/local_storage_test.dart` installs a
`MockSharedPreferences` per group, so it opts out and resets explicitly.

A mock on a channel the reset never touches needs no opt-out.
`test/support/url_launcher_stub.dart` installs one for url_launcher in the test body and removes it when the test ends, so its tests keep the reset and `TestEnv.authenticate()`.

### The asset cache

`rootBundle` caches the `Future` of every string asset it loads, including the `assets/mock/*.json` files behind `MockInterceptor`.
Code that awaits a cached `Future` is resumed by a microtask of the zone that created it.
Each `testWidgets` body runs in its own `FakeAsync` zone, and nothing runs that zone's microtasks once the test ends.
So once a `testWidgets` had loaded an asset, every later `testWidgets` in the same file that needed it waited forever: only the first test of a file got its mock responses, and the others hung until they timed out.
The bootstrap therefore empties the cache with `rootBundle.clear()` before and after every test, in every file, including files that opt out of `TestEnv.reset()`, so no test's cached `Future` outlives it, not even into a later group's `setUpAll`.
`test/support/test_env_test.dart` and `test/flutter_test_config_test.dart` guard this.

### Timeouts

Every test, `testWidgets` included, times out after the 30 seconds set in `dart_test.yaml`, or twice that in a file tagged `@Tags(['integration'])`.
On its own, `testWidgets` passes the binding's `defaultTestTimeout` of 10 minutes to `test()`, and a test's own duration replaces the configured timeout, so a hung widget test held CI for 10 minutes.
The bootstrap sets `defaultTestTimeout` to `Timeout.factor(1)`, which keeps the configured timeout as a plain `test()` does, and `test/flutter_test_config_test.dart` guards it.
A test that needs longer gets its own timeout and a comment that says why, as `test/architecture/feature_generator_test.dart` has `@Timeout(Duration(minutes: 5))` for its nested `flutter test` run, instead of a higher timeout for everyone in `dart_test.yaml`.

---

## Writing each kind of test

### Use case tests — mock the repository interface

No HTTP, no bootstrap concerns. Pure `mocktail`:

```dart
import 'package:mocktail/mocktail.dart';
import '../../../../mocks/mock_classes.dart';

void main() {
  late MockIConnectionRepository mockRepo;
  late ListManagedConnectionsUseCase useCase;

  setUp(() {
    mockRepo = MockIConnectionRepository();
    useCase = ListManagedConnectionsUseCase(mockRepo);
  });

  test('returns the managed connections of the repository', () async {
    when(() => mockRepo.listManaged()).thenAnswer((_) async => const Success(connections));

    final result = await useCase.call();

    expect(result, isA<Success<List<StudioConnection>>>());
    verify(() => mockRepo.listManaged()).called(1);
  });
}
```

### BLoC / Cubit tests — `blocTest` + sealed states

Mock the use case (or repository), assert exact state transitions:

```dart
blocTest<ConnectionListBloc, ConnectionListState>(
  'emits [loading, loaded] when the list loads',
  setUp: () => when(() => repository.listManaged()).thenAnswer((_) async => const Success(connections)),
  build: () => ConnectionListBloc(listManagedConnectionsUseCase: ListManagedConnectionsUseCase(repository)),
  act: (bloc) => bloc.add(const ConnectionListRequested()),
  expect: () => const [ConnectionListLoading(), ConnectionListLoaded(connections: connections)],
);
```

- Assert on sealed variants (`isA<ConnectionListLoaded>()` or matching variant fields),
  not on a status enum.
- `MockBloc` (from `bloc_test`, declared in `mock_classes.dart`) is used by
  **widget** tests that need to feed a BLoC a scripted state stream.

### Repository tests

Repositories talk to `ApiClient`. In tests, build the client via
`TestEnv.apiClient()` (mock-backed by `assets/mock/*.json`) or inject a stub Dio
for failure paths.

### Widget tests — `MockBloc` + `TestEnv.authenticate`

```dart
testWidgets('renders the shell when authenticated', (tester) async {
  TestEnv.authenticate();                 // in the test body, AFTER global reset
  await tester.pumpWidget(const App(language: 'en'));
  await tester.pumpAndSettle();
  expect(find.byType(ResponsiveScaffold), findsOneWidget);
});
```

Provide BLoC state with a `MockBloc` so the UI renders deterministically without
real business logic.

**Verifying actions — by event type, not `any()`.** Assert the dispatched event
with a type matcher and an explicit count:

```dart
verify(() => bloc.add(any(that: isA<SsoSignInRequested>()))).called(1);   // action fired
verifyNever(() => bloc.add(any(that: isA<SsoSignInRequested>())));        // must NOT fire (e.g. a misconfigured build)
```

Do **not** use `verify(() => bloc.add(any())).called(...)` or `.called(greaterThan(0))`:
screens add an init event on mount (a load/`Reset`), so a loose verify is satisfied
even if the action under test never fired — a false-confidence test. (A real case:
a "submit valid form" test passed under `add(any())` while the form was actually
invalid — a required field unfilled — so no submit ever dispatched. Tightening to
`isA<…Submit>()` exposed it; the fix was to make the test fill a genuinely valid form.)

**Other screen-test rules:** don't keep a repository mock that isn't injected (the
screen is driven through its mock BLoC); prefer `whenListen` + a seeded state over
re-implementing the bloc's state machine inside an `add` stub; use unique fixture
values so `findsOneWidget` is unambiguous (avoid common tokens like `'User'`); size
the test surface with `tester.view.physicalSize` + `addTearDown(tester.view.reset)`
(one consistent API — not `binding.setSurfaceSize`); and assert navigation by what
the destination renders, not just that the source screen disappeared.

### Widget tests that send a request

A `testWidgets` body runs in fake time, and `tester.pump()` without a duration does not move it: it runs microtasks and draws a scheduled frame, but it fires no timer, not even one of zero length.
Dio runs each interceptor step in a `Future`, which starts on a zero-length `Timer`, so a request through `ApiClient`, whether the test sends it through `TestEnv.apiClient()` or the pumped app sends it, stays where it is however often the test calls `pump()`.
A test that ends there fails with `A Timer is still pending even after the widget tree was disposed` and a stack through `DioMixin.fetch`.
Awaiting the request in the test body is worse: nothing pumps while the body waits, so the test hangs until it times out.

Start the request without awaiting it, pump with a duration, then check or await the result:

```dart
TestEnv.authenticate(); // the secure store is empty at the start of every test, and /auth/me needs a token
Response<String>? response;
unawaited(TestEnv.apiClient().get('/auth/me').then((value) => response = value));
await tester.pump(Duration.zero); // any duration fires the timers that are due, Duration.zero included

expect(response, isNotNull, reason: 'the mock request never completed');
```

`pumpAndSettle()` completes such a request as well, because its first pump advances 100 ms, but it stops as soon as no frame is scheduled.
So it does not wait out the 500 ms that `MockInterceptor` adds under `AppConfig.mock()`, which `App` uses unless the test passes other dependencies: pump at least that long before settling, as `pumpAppOnSettings` in `test/features/settings/presentation/pages/settings_screen_test.dart` does.
Every test that pumps `App` sends at least one request: the Studio status check reads `GET /health` when the app starts, unless the test replaces the Studio status repository.
Do not use `tester.runAsync` to let a mock request finish: it runs the request in real time, and it is meant for real I/O.
`test/support/test_env_test.dart` shows the pattern.

### ApiClient tests — stub Dio at the wire

Inject a custom interceptor through the `dio` parameter to simulate transport
errors:

```dart
late _StubInterceptor stub;
late ApiClient client;

setUp(() {
  stub = _StubInterceptor();
  final testDio = Dio(BaseOptions(baseUrl: 'https://test.api', responseType: ResponseType.plain));
  testDio.interceptors.add(stub);
  client = ApiClient(appConfig: const AppConfig.prod(), dio: testDio);
});

test('maps 401 to UnauthorizedException', () async {
  stub.stubDioError(DioExceptionType.badResponse, statusCode: 401);
  expect(() => client.get('/endpoint'), throwsA(isA<UnauthorizedException>()));
});
```

`ApiClient` is constructed via dependency injection — there is no global
singleton or `setTestInstance`.

### End-to-end smoke

`test/integration/app_smoke_test.dart` boots the **whole app** in mock mode
(`MockSignInDependencies()`, as `main_mock.dart` passes it: `AppConfig.mock()`, which serves
`assets/mock/*.json`, and the mock sign-in in place of Keycloak) and drives cold-start → single sign-on → connection list, exercising
routing + DI + BLoCs + the mock HTTP layer together. It is a full-app widget test
(`TestWidgetsFlutterBinding`), so it runs headless under the normal
`flutter test` — no device, no `integration_test` package, no CI changes. The
global bootstrap supplies the secure-storage mock + a clean storage reset, so the
app starts unauthenticated and lands on login. Scope is one happy-path smoke — not
multi-flow e2e. (For real on-device e2e later, add `integration_test` back and a
device-targeted CI job.)

---

## Mocks and fakes

All shared doubles live in `test/mocks/`:

- **`mock_classes.dart`**
  - `Mock*` classes — repositories (concrete + interface), `MockBloc<E,S>` for
    each BLoC, `MockSharedPreferences`.
  - `Fake*` classes — fallback values for non-nullable `any()` arguments.
  - `registerAllFallbackValues()` — registers every fallback once; **called
    globally by the bootstrap**, so you do not call it per file.
- **`fake_data.dart`**: shared fixtures (`mockUserFullPayload`, `kTestInstant`,
  ...). Prefer these over building entities inline.

### Choosing a test double

Three categories — **reach for a mocktail mock first**; drop to a hand-fake only
for genuine stateful behavior; Dio handlers are always hand-written:

1. **mocktail mock (default)** — the `Mock*` classes in `mock_classes.dart`. Use
   for interface doubles where the test only configures return values
   (`when(...).thenReturn` / `thenAnswer`) and verifies calls (`verify`). This is
   the default for repository / use-case / BLoC doubles.
2. **hand-written fake** — a private `_Fake*` / `_Memory*` class next to the test,
   when the double needs real stateful or behavioral logic that mocktail makes
   awkward: in-memory stores, throw-on-Nth-call, selective/sequenced failures,
   return-driven branching (e.g. `_FakeAuthRepository` in `login_bloc_test.dart`,
   `_MemorySecureStorage`). These are **purpose-built per test** — two same-named
   fakes in different files implement different surfaces and are *not* duplication;
   do not consolidate them into a shared "god" fake.
3. **Dio handler / interceptor stub** — a private `_Test*Handler` / `_StubInterceptor`
   extending Dio's `Interceptor` / `RequestInterceptorHandler` /
   `ResponseInterceptorHandler` / `ErrorInterceptorHandler`. Used to test
   interceptors at the Dio layer; they can't be mocked cleanly, and each records
   the signals its test asserts on.

---

## Architecture / guard tests

`test/architecture/` holds meta-tests that fail the build on rule violations:

- **`import_guard_test.dart`** enforces layer dependency rules
  (`core → nothing`, `shared → core`, `features → shared/infra/core`, no
  cross-feature internals). Known exceptions are listed explicitly and should
  shrink over time, not grow.
  It also fails if a file other than `lib/shared/utils/external_link.dart` imports `url_launcher`.
  Links go through `openExternalLink`, which tells the user when a link does not open and never asks `canLaunchUrl`, so the Android manifest needs no `<queries>` intent for them.
  The cross-feature and `features → app` checks are the pure functions `crossFeatureViolations` and
  `featureAppViolations`, each with unit tests of its own in the same file, because the directory check passes on a
  clean tree whether or not it can see the import it is meant to catch. The first used to skip any import whose path
  held a `/shared/` segment, meant for `lib/shared/` — a path no `/features/` import can reach — so what it exempted
  was another feature's own `shared` folder; the second matched the waived module as a substring, so every path it is
  a prefix of came in with it. Both are closed, and both holes are now a named failing case.
- **`cubit_over_bloc_test.dart`** fails if a `Cubit` under `lib/features/` holds an `I…Repository`/`Client`/`Gateway`/
  `Api` field and is not one of the five the guard names, or if one of those five does not carry a
  `A Cubit, not a Bloc:` line in its class doc. CLAUDE.md defaults a feature touching network requests to `Bloc`, for
  the `EventTransformer` that a `Cubit` otherwise writes by hand; three of these do write one by hand, so the guard
  makes each say what makes it the exception instead of leaving a reader to guess whether it is a decision or a drift.
- **`test_file_naming_test.dart`** fails if any file is named `*.test.dart`
  (a dot instead of `_test.dart`) — such files compile and pass `analyze` but
  are silently never executed by `flutter test`.
- **`android_manifest_test.dart`** fails if `AndroidManifest.xml` drops the `INTERNET` permission, `android:allowBackup="false"`, or the references to the two backup rule files, or if either rule file stops excluding shared preferences.
  Release builds need the permission to reach the API, and a restored backup or device transfer brings back session tokens that no longer decrypt.
  CI builds the release APK, but that build succeeds without any of these.
- **`mock_asset_naming_test.dart`** fails if a file under `assets/mock/` has a `-` in its name.
  `MockInterceptor` maps `-` in request paths to `_`, so such a file is never served and the request fails with 501.
- **`mock_asset_coverage_test.dart`** drives every method of every repository that uses `ApiClient` through `TestEnv.apiClient()`; it fails when one of them does not succeed.
  Platform repositories, which use `PlatformApiClient`, have their own table in the same file, driven through `TestEnv.platformApiClient()`, and the last test compares the methods it finds with both tables.
  `MockInterceptor` fails a GET, POST, PUT or PATCH whose mock file is missing with 501, so a missing file fails the test and the failure names it.
  A last test reads the repository interfaces under `lib/` and fails when a method is not driven, so a new repository method needs an entry in the test, and its mock file, before the build passes.
- **`feature_generator_test.dart`** runs `tool/generate_feature.dart` in a temporary copy of the project and fails if the generated feature is not formatted, does not analyze cleanly or fails its own tests.
  Nothing else compiles the generator's templates, so they drift silently when an API they call changes.
  The generated repository and route tests go through the real `ApiClient` and `MockInterceptor`, so a mock file named differently from the request it should answer fails the guard too.
  It is the slowest guard, mostly because of the nested `flutter test` run.
- **`log_placeholders_test.dart`** fails if the message of an `AppLogger` call in `lib/` has a different number of `{}` than the call has arguments.
  `AppLogger` never prints an argument with no `{}` left and prints a `{}` with no argument as it is, so such a call leaves a value out of the line or shows a bare `{}`, and neither fails at runtime or in `flutter analyze`.
  It reads the calls whose message is a string literal and whose arguments are a list literal.
- **`log_secrets_test.dart`** fails if an argument of an `AppLogger` call in `lib/`, or an interpolation in its message, names a credential: an identifier that contains one of `sensitiveBodyKeySubstrings` except `privacyOnlyBodyKeySubstrings`, such as `passwordChangeDTO` or `event.otpCode`.
  The words of `privacyOnlyBodyKeySubstrings`, today `reason`, mask a value for what it can carry, not because they name a credential, so an identifier that holds one is an ordinary name; every exit still masks the value of such a key in the line it prints.
  The console of every build that prints the level keeps the line, so log that the action happened instead.
  A token may still be logged through `maskToken`, which keeps four characters at each end.
- **`credential_to_string_test.dart`** fails if a class in `lib/` has a `String` field whose name contains one of `sensitiveBodyKeySubstrings` except `privacyOnlyBodyKeySubstrings`, such as `password`, `otpCode` or `refreshToken`, and its `toString` is not overridden, prints such a field, or prints the props.
  A log line, the dev console and a Sentry event print an object through `toString`, and an Equatable prints its props there whenever `stringify` is on, the default of every debug build.
  A token may be printed through `maskToken`; a password or an OTP is printed as `secretMask`.
- **`oidc_platform_setup_test.dart`** guards the platform setup of the single sign-on ([`docs/oidc.md`](oidc.md)).
  It fails if `defaultConfig` in `android/app/build.gradle.kts` does not set `manifestPlaceholders["oidcRedirectScheme"]` to `OidcSettings.defaultRedirectScheme`: the `oidc_android` manifest merge needs the placeholder in every build, and the redirect never reaches the app when it differs from the scheme the Dart side sends.
  It fails if a line in `lib/` names a client secret in any spelling (`client_secret`, `OIDC_CLIENT_SECRET`, `clientSecret`, `clientSecretPost`), except the scrubber's doc comment, or if any `OidcClientAuthentication` in `lib/` is other than `.none`, since the app is a public PKCE client.
  It fails if any `android/app/src/*/AndroidManifest.xml` mentions the redirect scheme or the `oidcRedirectScheme` placeholder: an intent filter there would let Android offer `MainActivity` for the callback instead of the package's redirect activity.
- **`sentry_native_scrub_patterns_test.dart`** guards the Kotlin copy of the scrub policy that the Android host masks native Sentry events and breadcrumbs with (`NativeScrubPatterns.kt`, `NativeSentryScrubber.kt` under `android/app/src/main/kotlin`).
  It fails if a Kotlin pattern, set or mask differs from the Dart one in `lib/core/security/sensitive_data_scrubber.dart` or `lib/infrastructure/analytics/sentry_scrub.dart`, if a shared pattern uses `\w`, `\d`, `\b`, `\s`, a bare `.` or a case-insensitive flag, which ICU, OpenJDK and Dart read differently, or if the Kotlin scrubber compiles a pattern with an option.
  It fails if `android/app/build.gradle.kts` passes `SENTRY_DSN` to the native SDK other than through the check on the target file name, or if that file is not the only entry point that selects the prod environment, and if `MainActivity.kt` stops answering the channel `nativeSdkReady` asks.
  The logic of the two copies is held equal by `test/fixtures/native_scrub_cases.json` and `test/fixtures/native_scrub_map_cases.json`, which the Dart tests and the Android JVM tests (`android/app/src/test/kotlin`) both run; see "Running tests" for the JVM command.

The guards below hold the build, the release, the documentation and the repository rather than a line of app code.
They are named here because a contributor who has not read them cannot tell a fixture gap from a real regression when
one fails — `user_data_registry_test.dart` in particular fails any pull request that files a new storage key in the
wrong scope.

- **`user_data_registry_test.dart`** fails if a `StorageKeys` value is neither registered in `createUserDataRegistry`
  nor classified as a device preference, or if a repository that writes one is not listed. Exactly one of the two,
  never both: "remove my data" must clear what belongs to the account and keep what belongs to the device.
- **`design_token_test.dart`** fails on an off-token colour, radius or spacing literal under `lib/features/`, against
  a per-file budget measured when the guard landed. It is a ratchet: a new offence fails, and so does a budget that
  outlives the debt it was written for.
- **`line_length_test.dart`** fails on a Dart line over 120 columns in `lib/`, `test/` or `tool/`. The formatter never
  rewraps a comment and cannot split a string literal, and no analyzer lint takes a width.
- **`agent_scratch_test.dart`** fails if a coding agent's working directory holds a tracked file, or is not
  git-ignored. Ignore rules do not apply to a path git already follows, so both halves are checked.
- **`first_run_writes_nothing_test.dart`** guards what a launch stores against what the introduction reads.
  `OnboardingSeenPreferences` treats a stored preference as proof this device has used the app before, which is what
  spares a user who upgrades while signed out an introduction to software they know; every key a launch writes has to
  be left out of that, because a brand-new device holds it too. One half reads `app_bootstrap.dart` and fails on a
  launch-time write the store does not know about; the other pumps `App` and fails if anything above the bootstrap
  stores a key. The first version of the rule read every key and the bootstrap writes the default palette, so no new
  user would have seen the introduction — with the suite green, because every other test starts on a device that has
  already seen it.
- **`touch_feedback_test.dart`** guards that a control answers a finger. Every other guard reads the code or one
  resting frame, so an app whose whole interaction state came from `MouseRegion` — a callback that never fires on a
  phone — stayed green while a card used on eight screens was inert under a finger. One half fails on a widget that
  writes state from a hover without offering ink; the other fails when a shared widget declares an `onTap` and no test
  has ever held a finger on it, which is the only way to find a control whose ripple is drawn correctly and then
  covered by its own opaque background. The press itself is measured by `test/support/pressed_frame.dart`, which
  compares the pixels a widget draws at rest and while held — two frames of the same widget in one test, never a
  stored image, so it says the same thing here as on CI. Only the held frame counts: letting the released one count
  turned a real failure green, because the warnings chip's own `onTap` collapses the list inside the measured area.
  And the bar is a share of the control's own area rather than a single byte, because the chip's defect leaked 50
  corner pixels while the ripple that mattered stayed hidden.
- **`tap_splash_test.dart`** is the other half of that rule: the splash — the circle that grows out of the touch point
  and over whatever is behind the control — is off in every theme the app can be shown in, and the flat press
  highlight is not. It fails when a theme loses `splashFactory: NoSplash.splashFactory`, when a theme has no press
  highlight left either (which would reach "no splash" by making every control silent, the defect of #367), when a
  control built under the app theme hands its own ink a splash factory past the theme — every `ButtonStyleButton`
  resolves one through `ButtonStyle`, so the lever reaching them is measured here rather than assumed — and when any
  file in `lib/` names a splash factory that is not `NoSplash`. Removing the splash took the only answer two result
  rows had: their cells hold the gesture arena open with a long press, so the ink under them draws nothing while held
  and the splash confirming on release was the whole of it. They now paint `ThemeData.highlightColor` themselves
  (`PressHighlight`), and `result_row_touch_test.dart` measures the held frame rather than the released one.
- **`post_frame_context_test.dart`** fails when an `addPostFrameCallback` in `lib/` reaches a `BuildContext` without
  checking `mounted` first, following one level of indirection so `(_) => _method()` is read together with the body of
  `_method`. The callback runs at the end of a frame its widget may already have left, and a read from a `State` that
  is gone throws. Eight of the nine call sites were already right; the ninth was the login page's automatic redirect,
  whose guard was left behind when #379 moved its conditions into `autoRedirectTarget`. The whole suite stayed green
  and no widget test could have caught it: `setState` defers an unmount to the next frame, so a test cannot take a
  page out of the tree inside the frame its own callback runs in. This is the shape of loss only the source shows.
- **`design_system_import_test.dart`** holds the app's tokens against the design system they came from.
  `tool/design-system/tokens/` is a verbatim copy of `design-system/tokens/` in `libredb/libredb.github.io`, taken at
  `857d454`, with `tool/design-system/SOURCE.md` recording the stamp and how to refresh it — a copy rather than a
  reference because that repository is not checked out on CI, and the copy is what makes a later drift detectable
  instead of merely lookupable. The file asserts what was measured at the import, not a wish: the app's spacing and
  radius scales each sit *inside* the web's, so adopting the web scale adds steps and invalidates no layout, and the
  tap target is pinned at 48 in both directions because the owner ruled against the web's 44 (#283, #373).
  It reads the colour the same way, out of the half of `theme.css` that applies — by the `[data-theme="dark"]`
  selector where it starts a line, not its first mention, because the file's own header comment names it and
  splitting there leaves the light half empty. Four relationships are pinned: the brand group is the same web
  token in all three palettes, `classic` is the system token for token, the four status colours follow one rule
  (`--<kind>-text` with the scope's `--text-inverse` on it), and `nature` and `sunset` keep their own neutrals,
  pinned in both directions because three palettes that differ only in the name of their action colour are one
  palette with three names. Five values deviate, and each deviation asserts *both* halves — that the web value
  really does fail its floor, and that the value taken instead clears it — so a system that later lifts one of
  them fails the first half and the deviation is reconsidered rather than kept.
- **`design_system_doc_test.dart`** holds `docs/design-system.md` to the code it describes. That page exists to be
  cited — M16's review layer judges the app's visual consistency against the design system, and a finding that
  cites nothing is taste rather than a finding — so a page of values that has quietly drifted is worse than no page
  at all: it makes a wrong citation look like a right one. Three things are checked, and they are the three a
  reader relies on: every `file:line` the page cites exists, every colour it prints for `classic` is the colour the
  app ships (all 26 roles, both scopes), and every number it prints is the number the token holds. It caught nine
  citations that resolved to nothing and three curves written in the wrong form on its first run.
- **`usability_doc_test.dart`** holds `docs/usability-findings.md`, the record format of M16's usage layer (#285), to
  the tree it points at. All three of that page's load-bearing claims point outside itself — the guards whose classes
  make an observation a test gap instead of a usability finding, the rows of `docs/design-system.md` a visual finding
  has to cite, and how many guards this directory holds — and each fails quietly: a discard rule naming a guard that
  no longer exists discards nothing, a citation that has slid two lines down sends a reviewer to the wrong sentence
  while still looking right, and a count read from the issue rather than the tree is already wrong, since #285 says
  24 guards. So every `test/` path the page names has to exist, every `docs/design-system.md:NNN` citation has to
  resolve to a paragraph that still carries the sentence it is quoted for — the paragraph, not the line, because that
  page wraps at 120 columns — and the guard count the page states has to be the number of `*_test.dart` files here.
- **`usability_jobs_doc_test.dart`** holds `docs/usability-jobs.md`, the jobs the five personas of M16's usage layer
  are run against (#285), to the tree and to the finding format beside it. That page is the whole brief of a run that
  has nobody to ask: a job naming a screen that was renamed, a build file that moved or an environment the app does
  not have stops the run where it stands. It is also the other half of `docs/usability-findings.md`, which reads
  `persona`, `job`, `step` and `severity` off it — so a job with no numbered steps makes `step` unwritable, a persona
  the roster does not hold makes `persona` unwritable, and a severity invented on one page makes two personas
  incomparable. The guard reads the roster table against the job ids (two or three per persona, numbered from 1
  without a gap), every block against its keys and their order, every `start:` and `done:` against
  `ApplicationRoutesConstants`, every `target:` against `lib/main/`, every `environment:` and `session:` against the
  enums the app ships, every backticked path against the tree, and every severity against the table that defines it.
  What it does not read is whether a job is a good job; it reads the things that fail quietly.
- **`android_resource_xml_test.dart`** fails when a comment in an Android resource file holds a double hyphen.
  AAPT parses those files strictly and refuses the whole file over it, and writing `--background` in one — the
  name of a design token, which this repository writes that way everywhere else — took the Android build down
  with a stack trace about `ErrorHandlerWrapper`. That build is the only other thing that catches it and the
  slowest check in CI: it fails after seven minutes, in a job a Dart author has no reason to read. This reads the
  files in milliseconds and names the rule as well as the line (#390).
- **`app_icon_test.dart`** fails while either platform ships the framework's own logo as the app icon, and while
  Android has no adaptive icon. `flutter create` writes a blue chevron into both sets and nothing had replaced it:
  the Play listing icon of #197 is a different asset, uploaded to the console, so the store page showed LibreDB's
  mark while the installed app showed Flutter's. iOS review rejects such a build; Android does not, which is worse,
  because it ships. The guard states what the icons must **not** be rather than keeping a second copy of what they
  are — a hash of the shipped art would need updating every time the mark is redrawn and would say nothing about
  the next platform the project adds, while the framework's defaults never change. It identifies them by weight:
  the default is flat three-colour art that compresses under 40 bytes per thousand pixels, and a gradient mark is
  far above that at every size. `tool/generate_app_icons.dart` writes the real ones, driving Flutter's own
  rasteriser from `flutter test` because the project has no other (#390).
- **`quiet_alpha_test.dart`** fails when text painted with a quiet role faded by an alpha drops under 4.5:1 on the
  page or on either container it can sit on. It reads the alpha out of the source rather than holding a list, so a
  fade written tomorrow is measured the moment it is written, and the only way out is the exemption list, whose two
  entries each carry their reason — a debug overlay no release build carries, and the bars that stand for text in
  the theme dialog's miniature. Four sites failed it: the hint of every text field at 2.82:1 on a card, the build
  number with it, the community subtitle at 3.49:1 and the result header's type at 4.38:1. No alpha fixes them —
  in `nature` light and `sunset` light no value in 0-255 clears the floor on a container — so the fades were
  removed, which is also where Material 3's own `InputDecoration` hint already sits (#386).
- **`snack_bar_ink_test.dart`** fails when a `SnackBar` in `lib/` gives itself a background without giving itself
  the ink to go on it. A snack bar's text colour comes from `snackBarTheme.contentTextStyle`, which is set to
  `onInverseSurface` — the ink for the background the theme also supplies. Replace the background and the ink stays
  behind, still coloured for a surface that is no longer there. It went unnoticed because it used to be true by
  accident: the login page paints its sign-in confirmation with `primary`, and while `primary` was a near-black in
  light and a near-white in dark it was always the opposite of the page, which is what `onInverseSurface` is the
  ink for. #283 made `primary` the indigo in both scopes, the coincidence ended, and the dark scope's ink landed on
  indigo at 3.08:1. A source guard rather than a widget test, because the rule is about what a call site must
  supply and the next call site does not exist yet.
- **`bouncing_scroll_physics_test.dart`** fails when a file in `lib/` names `BouncingScrollPhysics`. `AppScrollBehavior`
  on `MaterialApp.scrollBehavior` answers clamping physics for every scrollable, so the app says, app-wide, that a pull
  past an end does not stretch; a scrollable handed bouncing physics of its own overrides that for its own screen and
  nothing else, and the claim stops being true on one screen. Neither a golden nor a release build reports it, because
  only a finger on a device sees it. A source guard rather than a widget test, because the offending screen does not
  exist yet (#418).
- **`test_file_naming_test.dart`**, **`mock_asset_naming_test.dart`** and **`feature_generator_test.dart`** guard the
  shapes the tree is generated and navigated by.
- **`android_release_setup_test.dart`**, **`sentry_release_symbols_test.dart`**,
  **`play_listing_metadata_test.dart`**, **`play_screenshot_drafts_test.dart`**,
  **`app_store_listing_metadata_test.dart`**, **`privacy_policy_platforms_test.dart`**, **`release_docs_test.dart`** and
  **`release_tag_creation_test.dart`** and **`release_tracks_test.dart`** guard the release: the signing config, the
  obfuscation and symbol upload, the Play listing texts, the phone screenshots of the listing drafts, the App Store
  listing texts, the labels
  `docs/release.md` quotes and the approval step it may no longer promise, since the required reviewers are gone and a
  page that still names one sends the owner after an Approve button that does not exist, the owner token release-please
  tags with, without which the `refs/tags/v*` creation rule
  refuses every release, and the two Play tracks a release is uploaded to, since dropping either upload is silent. The screenshot guard reads each PNG's IHDR header, so an
  alpha channel or a ratio above 2 fails here rather than silently in the Play Console days later. The App Store guard
  holds Connect's own limits and locales, which are not Play's: a name and a subtitle of 30 characters, keywords of
  100, a promotional text of 170, and `tr` where Play says `tr-TR`. The privacy guard pairs phrases rather than
  counting mentions: saying "Android Keystore" obliges the page to say "Keychain" as well, in both languages, because
  one policy URL serves both stores and a reader on either platform has to find their own device described there.
- **`store_listing_claims_test.dart`** guards three listing claims against what the code measures, across all six
  listing texts at once: the live Play listing, every Play draft and the App Store listing, in both languages. Cancel
  belongs to the engine (`ProviderMeta.supportsQueryCancel`); without it Stop waiting drops only the app's own request
  while the statement runs on, which the app's own `sql_editor_stopped_waiting` says. The write confirmation is a
  keyword scan that does not see what a function an allowed statement calls does (`docs/security.md`). The mask hides
  more than Studio's grid for a token or key, an email with an empty part and a date that is not a bare calendar date
  (`docs/security.md`), although the columns it masks are still Studio's. A phrase guard rather than a prose review,
  because six copies of one sentence drift apart one file at a time, and an audit is the only thing that notices.
- **`app_lock_platform_setup_test.dart`** and **`orientation_platform_setup_test.dart`** guard the Android and iOS
  settings the lock and the orientation policy need.
- **`session_target_test.dart`** guards that a stored session carries the target it belongs to.
- **`installer_lab_config_test.dart`** guards the Platform installer environment used for the full-system check.
- **`platform_image_pin_test.dart`** guards that the `platform` profile of `tool/studio-dev` names one Platform release
  everywhere it is named: both `PLATFORM_IMAGE` defaults, the comment that introduces the profile, and the
  `## Platform` section of `docs/studio.md`. Every answer under `test/fixtures/platform/` was recorded from that one
  release, so a bump that reaches the image but not the prose leaves the doc describing a Platform that no longer
  serves the fixtures, and a bump that reaches one service but not the other migrates with one release and serves with
  another.

The colour has two guards next to the code they guard, and the second exists because the first could not see
what it was missing:

- `test/shared/design_system/theme/palette_contrast_test.dart` measures fifteen pairs of every one of the six
  `ColorScheme`s — twelve, then three. Twelve date from #369; #283 added `primary` on `surface` at 3:1, because a filled button's own
  fill is the boundary 1.4.11 asks to be identifiable, and `error` on `surface` at 4.5:1, because this app paints
  *text* with that role at twenty call sites and not only fills. Both were added for a failure the move onto the
  design system would otherwise have shipped: reading `surface` as the web's `--surface` rather than
  `--background` puts the action colour at 2.80:1 on the page, and the web's `--action-destructive` is 4.01:1 on
  the dark page. The fifteenth is `inversePrimary` on `inverseSurface`, a snack bar's action: `inversePrimary` has
  no call site in `lib/` at all, and is painted anyway by `_SnackbarDefaultsM3`, which supplies it because
  `snackBarTheme` sets no `actionTextColor`. It was 4.41:1 in nature dark, unmeasured for as long as the palette
  had existed — a role with no call site is not a role nobody sees.
- `test/shared/design_system/theme/semantic_contrast_test.dart` measures the same way for `success`, `warning` and
  `info`. For as long as both files have existed nothing measured those three, because the guard above reads a
  `ColorScheme` and these live in a `ThemeExtension` — and two of them were under the floor the whole time.
  `success` was Green 600, which put its white label at 3.30:1, and `warning` was Yellow 500, which as text on
  the page is **1.92:1**. The design system's own values are 5.48:1 and 5.02:1.

- `test/shared/design_system/theme/surface_ladder_test.dart` fails when a container role this app paints with is
  the page colour. `theme_colors.dart` defined one of them and left the rest to Material, which resolves them to
  the page, so `app_card.dart`'s fill, the editor's accessory bar and the result table's header row were painting
  the page onto the page, and what made a card visible was only its border. It is not a contrast rule — one
  surface owes another nothing, and the design system genuinely puts a white card on a white page and separates
  them with a border — it asks only that the role **differ**, because a fill that is exactly the page is not a
  quiet fill, it is no fill, and the widget asking for one is lying about what it draws (#386).
- `test/shared/design_system/theme/material_default_contrast_test.dart` measures the text this app never colours.
  `TextButton`, `OutlinedButton` and `TabBar` are given a size, a shape and a text style in `app_theme.dart` and
  no foreground colour, so Flutter's own M3 defaults supply one — `colorScheme.primary`. That was harmless while
  `primary` was a near-white or a near-black, and stopped being harmless when #283 pointed it at the product's
  indigo: 6.29:1 on a light page and **3.08:1** on a dark one, so every quiet button in the app and the selected
  tab of the object detail page went under the floor at once. The three guards above could not see it, because
  the colour comes from neither a role this app sets nor a line this app writes. **The emulator saw it** — a
  screenshot of the welcome screen showed an indigo "Skip" on a near-black page — which is why the walkthrough is
  a merge gate and not a courtesy. This guard pumps the real widgets under the real theme, because what it holds
  is precisely the value the theme does not carry.

The single sign-on has more guards next to the code they guard:

- `test/app/di/app_scope_test.dart` fails if a misconfigured build creates or provides an OIDC client.
- `test/architecture/mock_sign_in_test.dart` fails if `main_prod.dart` or `main_local.dart` imports the debug-only mock sign-in of `main_mock.dart`, directly or not.
- `test/architecture/main_entry_points_test.dart` pins what each entry point defaults to, and that `main_prod.dart` gives `PLATFORM_API_URL` no default.
- `test/features/auth/data/repositories/auth_session_repository_impl_test.dart` fails if the session clear leaves the OIDC ID token or the access token expiry behind, since the clear deletes keys one by one and is not exhaustive.
- `test/app/router/app_router_test.dart` fails if a callback URL such as `/oauth2redirect?code=...&state=...` becomes a router location or a `returnUrl`, since the router logs locations.
- `test/features/auth/sso_log_hygiene_test.dart` drives a full sign-in, refresh, logout and pushed callback route against the fake provider of `test/infrastructure/auth/oidc/support/fake_provider.dart`, and fails if AppLogger, `printedLines` or a `package:logging` record shows a token, the code, the verifier, `state` or the nonce.

---

## Determinism & known gaps

- **Time:** use `fakeAsync` for time-based logic (timers, debounce, timeouts).
  `event_transformers_test.dart` is the reference — it drives the bloc inside
  `fakeAsync` and advances virtual time with `async.elapse(...)`, with no
  wall-clock dependency. `idle_timeout_observer_test.dart` uses the same approach.
- **Mocked async:** do not use real-time `blocTest(wait:)` to "let a mock settle"
  — `blocTest` already awaits the bloc's state stream. Sequence dependent events
  with `await bloc.stream.firstWhere((s) => s is <State>)`, not a millisecond delay.
- **Fixtures:** use the fixed `kTestInstant` (`test/mocks/fake_data.dart`) for any
  fixture timestamp whose exact value no assertion depends on — never `DateTime.now()`.
- **Goldens:** golden / visual-regression tests use `alchemist`. Each golden test
  lives **next to the code it covers** (feature-first, mirroring `lib/` — same as
  every other test), with its images in a sibling `goldens/ci/` dir; e.g.
  `test/shared/design_system/components/app_button_golden_test.dart`,
  `test/features/auth/presentation/pages/login_screen_golden_test.dart`. The
  bootstrap sets a default `AlchemistConfig` (light theme) and **disables platform
  goldens**, so only the CI (Ahem-rendered) variant runs, which removes font flake.
  It does **not** make the rasterisation the same everywhere: measured on this
  repository, the component goldens deviate by 0.09–0.15% (23–39 pixels) between a
  maintainer's macOS machine and the Linux CI runner, symmetrically and
  independently of the fonts, so eleven component golden files fail locally and
  pass on CI. **Produce a baseline on the runner that verifies it** — push a
  temporary job that runs `flutter test --tags golden --update-goldens` and uploads
  `**/goldens/ci/*.png`, download the artifact, commit the images that differ, and
  delete the job in the same pull request. Regenerating locally is what sent #349
  through two red CI rounds. Golden files set `setUpAll(() => TestEnv.autoReset
  = false)` and use `pumpBeforeTest: pumpOnce` for animated widgets. Coverage: all
  design-system components, shared widgets, and key screens (rendered with mocked
  BLoCs via the `test/support/golden_app.dart` `goldenScreen` helper):
  **52 golden images** across **46 scenarios** in 19 files, counted by
  `test/architecture/testing_doc_test.dart`, which fails when this paragraph and the
  tree disagree. The login screen also has images for a misconfigured build and for a
  Studio that does not answer, which are the two states a user meets that are not the
  working one. The login, settings and onboarding screens have a dark variant today.
  The introduction's file draws the real `OnboardingPage` with `onboardingStepHero`, once per screen and
  brightness (twelve images): alchemist renders a frame, not a session, so `whilePerforming` swipes the page to the
  step, lets the hero's animation finish, and asserts the counter so a swipe that lands elsewhere fails instead of
  blessing a wrong image. The brand mark has a
  file of its own, because every other test of it measures geometry — that the paths
  parse, that the data rows are where the design system puts them — and none of those
  can tell a correct hexagon from one assembled wrong.
  The responsive **shell / home screen is intentionally not goldened** (it boots
  via real DI in
  `App()` rather than mockable to a single deterministic frame; its
  sub-widgets are already covered by the component/widget goldens).
- **Tags:** `dart_test.yaml` declares `widget` (applied to all `testWidgets`
  files via `@Tags(['widget'])`) and `golden` (auto-applied by alchemist). An
  `integration` tag is declared but reserved for a possible future on-device
  (`flutter drive`) suite — the current e2e smoke is a `test/integration/` widget
  test (tagged `widget`). Slice the suite with `flutter test --tags widget` /
  `--exclude-tags widget`.
  The per-test timeout (30s) lives in `dart_test.yaml` and applies to `testWidgets` too (see "Timeouts" above).
- **Pumping:** use `pumpAndSettle()` only when all animations are expected to **finish** (route/page transitions, one-shot reveals).
  Its `Duration` argument is the **per-pump interval, not a timeout** (the timeout is a separate, later parameter), so prefer the bare form.
  For **continuous / indeterminate animations** (spinner, shimmer, looping) never `pumpAndSettle`: it pumps until its own timeout of 10 minutes of fake time, 6000 frames at the default interval, and then throws `pumpAndSettle timed out`, usually within seconds, unless slow frames reach the 30 second test timeout first.
  Assert the spinner with `pump()` and use `pump(const Duration(...))` for a fixed frame; in goldens use `pumpBeforeTest: pumpOnce`.
- **Frames:** a test that has to say what is on screen *during* an animation pumps it 16 ms at a time and reads the pixels back, because nothing else here can see a frame that is neither the first nor the last — a golden renders one resting frame and a `pumpAndSettle` skips straight to the end.
  `test/support/route_change_frames.dart` captures the surface inside a `RepaintBoundary` and counts the pixels two frames differ by, on the machinery `test/support/pressed_frame.dart` already uses for a press.
  `app_page_transition_overlap_test.dart` pushes a blue page over a red one and counts the pixels that hold both, which is how a transition that drew 100% of the screen twice for 14 consecutive frames was measured and is now pinned; `app_skeleton_route_change_test.dart` reads the same surface to fail if the shimmer still sweeps on a page that is being left (#421).

These are documented so newcomers know what is intentional vs. not-yet-done.

---

## Coverage

CI computes line coverage with generated/bootstrap code excluded, via
`scripts/check_coverage.sh` (excludes `lib/generated/**`, `*.g.dart`,
`*.freezed.dart`, `lib/main/main_*.dart`, `*.config.dart`). The current floor is
65%. Run locally:

```shell
fvm flutter test --coverage
scripts/check_coverage.sh coverage/lcov.info 65
```

---

## Running tests

```shell
fvm flutter test                                   # whole suite
fvm flutter test test/features/connections         # a subtree
fvm flutter test test/path/to/specific_test.dart   # one file
fvm flutter test --coverage                         # with coverage
fvm flutter test --concurrency=1 --test-randomize-ordering-seed=random  # flush order/leak bugs
```

The Android JVM unit tests (`android/app/src/test/kotlin`) cover the Kotlin scrubber of native Sentry events and run in the Build Android job of CI.
They need JDK 17 and the Gradle wrapper, which is not committed: any Flutter Android build writes it, for example `fvm flutter build apk --config-only --target lib/main/main_prod.dart`.

```shell
cd android && ./gradlew :app:testDebugUnitTest -Ptarget=lib/main/main_prod.dart
```

---

## Adding tests for a new feature

1. Create `test/features/<feature>/` mirroring the feature's `lib/` structure.
2. **Use case tests** (`application/usecases/`): mock the repository interface
   (`MockI<Feature>Repository`) with `mocktail`.
3. **BLoC/Cubit tests** (`application/`): `blocTest`, assert sealed state
   variants; mock the use case or repository.
4. **Repository tests** (`data/repositories/`): `TestEnv.apiClient()` or a stub
   Dio.
   Add each repository method that sends requests through `ApiClient` to the table in `test/architecture/mock_asset_coverage_test.dart`, or, for `PlatformApiClient`, to its Platform table.
5. **Widget tests** (`presentation/`): `MockBloc` for state; `TestEnv.authenticate()`
   in `setUp`/body for auth-gated screens.
6. Add any new mocks/fakes to `test/mocks/mock_classes.dart` (and register
   fallbacks in `registerAllFallbackValues()` if you use `any()` with a new
   non-nullable type).
7. Do **not** add per-file binding/logger/storage setup — the bootstrap handles
   it. Only opt out (`TestEnv.autoReset = false`) if your file installs its own
   channel/prefs mock.

---

## File reference

| Purpose | Path |
| --- | --- |
| Global bootstrap | `test/flutter_test_config.dart` |
| Test-support harness | `test/support/test_env.dart` |
| Shared mocks/fakes | `test/mocks/mock_classes.dart`, `test/mocks/fake_data.dart` |
| Layer dependency guard | `test/architecture/import_guard_test.dart` |
| Test-file naming guard | `test/architecture/test_file_naming_test.dart` |
| Android manifest guard | `test/architecture/android_manifest_test.dart` |
| Mock asset naming guard | `test/architecture/mock_asset_naming_test.dart` |
| Mock asset coverage guard | `test/architecture/mock_asset_coverage_test.dart` |
| Feature generator guard | `test/architecture/feature_generator_test.dart` |
| Log placeholder guard | `test/architecture/log_placeholders_test.dart` |
| Log secrets guard | `test/architecture/log_secrets_test.dart` |
| Credential text guard | `test/architecture/credential_to_string_test.dart` |
| OIDC platform setup guard | `test/architecture/oidc_platform_setup_test.dart` |
| Native Sentry scrub guard | `test/architecture/sentry_native_scrub_patterns_test.dart` |
| Fixtures shared with the Android JVM tests | `test/fixtures/` |
| OIDC log hygiene | `test/features/auth/sso_log_hygiene_test.dart` |
| Fake OpenID provider | `test/infrastructure/auth/oidc/support/fake_provider.dart` |
| Coverage gate | `scripts/check_coverage.sh` |
| Mock data layer | [`docs/mock-architecture.md`](mock-architecture.md) |
| Conventions | `CLAUDE.md` → Testing |
