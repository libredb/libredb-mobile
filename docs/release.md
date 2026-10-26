# Releasing the Android app

A release is a signed Android App Bundle built for one deployment and uploaded to the Play internal testing track.
Studio's URL and the Keycloak settings are compiled into the build, so one Play listing serves one deployment; the store build targets the deployment the maintainer runs.
No key, password or token is ever in the repository: they live in GitHub secrets, and both the signed build and the upload wait for the maintainer's approval.
iOS is released separately on macOS (#199).

## How a release flows

1. [release-please](https://github.com/googleapis/release-please) (`.github/workflows/release-please.yml`) keeps a release pull request open on `main`.
   It reads the Conventional Commits merged since the last release, picks the next version, raises the build number in `pubspec.yaml` by one, and writes `CHANGELOG.md`.
   Never edit `CHANGELOG.md` or the version in `pubspec.yaml` by hand; `.release-please-manifest.json` holds the last released version and must equal the version name in `pubspec.yaml`.
2. Merging the release pull request tags the release (`v1.2.3`) and creates the GitHub release.
3. The same workflow then calls `.github/workflows/release.yml`, because a tag that a workflow pushes with `GITHUB_TOKEN` starts no other workflow.
4. `release.yml` checks that the tagged commit is on `main` and that the tag equals the version name in `pubspec.yaml`, runs the localization, format and analyze checks, the full test suite with the coverage gate, and the Android JVM tests.
5. The build job waits for the maintainer's approval of the `release-signing` environment, then checks out the commit the checks ran on.
   It stops when the build would carry a define meant for checks only (see below), or when a release has no `SENTRY_AUTH_TOKEN` (see "Crash symbols").
   It decodes the upload keystore into the runner's temp directory, builds `flutter build appbundle --release --target lib/main/main_prod.dart --obfuscate --split-debug-info=build/debug-info` with the deployment's defines and `-PrequireReleaseSigning=true`, and checks that the bundle's signing certificate has the fingerprint in `ANDROID_UPLOAD_CERT_SHA256`.
   It then uploads the Dart symbols, the obfuscation map and R8's `mapping.txt` to Sentry; a failed upload stops the release.
6. It keeps the bundle and R8's `mapping.txt` for 7 days as the `release-bundle` workflow artifact, and deletes the keystore and the defines file, also when a step failed.
   The artifact holds exactly those two files: the Dart symbols and the obfuscation map in `build/debug-info` go only to Sentry.
   The bundle holds the deployment's URLs and the Sentry DSN compiled in, so anyone who can read the workflow artifacts can read them.
7. The upload job waits for the approval of the `play-internal` environment, then uploads the bundle and the mapping to the internal testing track.

A version tag pushed by hand (`git tag v1.2.3 && git push origin v1.2.3`) runs `release.yml` the same way; use it only on a commit of `main` whose `pubspec.yaml` already names that version.
The build number grows with every release because release-please raises it, and Play refuses a bundle whose version code it already has.

Release pull requests that release-please opens with `GITHUB_TOKEN` start no CI run of their own.
Their checks run again in `release.yml` before anything is built, and closing and reopening the pull request starts the usual CI run when a branch rule asks for it.

## Release signing

`android/app/build.gradle.kts` reads the upload key from four values, each from its environment variable, else from `android/key.properties`:

| Environment variable | `key.properties` key |
| --- | --- |
| `ANDROID_UPLOAD_STORE_FILE` | `storeFile` |
| `ANDROID_UPLOAD_STORE_PASSWORD` | `storePassword` |
| `ANDROID_UPLOAD_KEY_ALIAS` | `keyAlias` |
| `ANDROID_UPLOAD_KEY_PASSWORD` | `keyPassword` |

A relative store file resolves against `android/`.
`key.properties`, `*.jks` and `*.keystore` are git-ignored, and `test/architecture/android_release_setup_test.dart` fails when one is tracked.
With all four values a release build signs with the upload key; with none it signs with the debug key, so a pull request build needs no secret.
Some of the values but not all fail the build, and `-PrequireReleaseSigning=true` fails it when any is missing.
`-PrequireReleaseSigning=true` also fails a build given a define from `tool/release/check_only_defines.txt`, so a signed build made by hand refuses them as the workflow does.
The build log names the key: `Release build signed with the upload key in <file name>.` or `Release build signed with the debug key.`

A local signed build, with the four values in `android/key.properties` or the environment:

```bash
fvm flutter build appbundle --release --target lib/main/main_prod.dart \
  --dart-define-from-file=<your deployment's defines file> -PrequireReleaseSigning=true
```

## Secrets and variables

The build job signs in one of two GitHub environments, which hold the same names:

- `release-signing`, for a tag or a release-please release, with the real upload key; only `main` and `v*.*.*` tags may deploy to it, and the maintainer approves each build.
- `release-dry-run`, for a manual run, with a throwaway key made only for dry runs.

Secrets and variable of each signing environment:

| Name | Kind | What it holds |
| --- | --- | --- |
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | Secret | The keystore file, base64 encoded on one line |
| `ANDROID_UPLOAD_STORE_PASSWORD` | Secret | The keystore password |
| `ANDROID_UPLOAD_KEY_ALIAS` | Secret | The key's alias |
| `ANDROID_UPLOAD_KEY_PASSWORD` | Secret | The key's password |
| `ANDROID_UPLOAD_CERT_SHA256` | Variable | The SHA-256 fingerprint of the key's certificate, which the build compares with the bundle's |
| `SENTRY_AUTH_TOKEN` | Secret | `release-signing` only: the Sentry organization token the symbol upload uses (see "Crash symbols"); never add it to `release-dry-run` |

Secret of the `play-internal` environment:

| Name | What it holds |
| --- | --- |
| `PLAY_SERVICE_ACCOUNT_JSON` | The JSON key of the Play service account |

Repository secret:

| Name | What it holds |
| --- | --- |
| `SENTRY_DSN` | Optional; the build reports crashes only with it ([crash-reporting.md](crash-reporting.md)) |

Variables of the repository, or of the build job's environment, which override the repository's, name the deployment the build signs in to ([studio.md](studio.md), [oidc.md](oidc.md), [security.md](security.md)):

| Name | Required |
| --- | --- |
| `PROD_API_URL` | Yes |
| `OIDC_ISSUER` | Yes |
| `OIDC_CLIENT_ID` | Yes |
| `OIDC_SCOPE`, `OIDC_AUDIENCE`, `OIDC_PROMPT`, `OIDC_AUTO_REDIRECT`, `OIDC_LOGOUT_HINT` | No |
| `STUDIO_CERT_PINS`, `OIDC_CERT_PINS` | No; pinning ships off |
| `PLATFORM_API_URL`, `PLATFORM_CERT_PINS` | No; Platform mode only, set by the owner after approval (#302's checklist) |
| `SENTRY_ENVIRONMENT`, `SENTRY_DIST` | No; the native Sentry SDK picks them from the build when unset |
| `PLAY_RELEASE_STATUS` | No; `completed` by default; set it to `draft` until the app's first publication on Play, then remove it |

A variable set only on the `release-dry-run` environment reaches dry runs only.
An empty variable is left out of the build, and the build stops when a required one is missing.
The release workflow passes the Platform defines `PLATFORM_API_URL` and `PLATFORM_CERT_PINS` ([platform.md](platform.md)) when they are set.
While `PLATFORM_API_URL` is unset, the store build stays Studio-only.
The app stops at start when `PROD_API_URL`, `OIDC_ISSUER`, `SENTRY_DSN` or `PLATFORM_API_URL` is set but is not an https URL, so the store build only talks to them over https ([security.md](security.md), "Encryption in transit").
Before the build, `tool/release/check_defines.sh` stops the release on the same rule, naming the variable and never its value, so nothing is signed or uploaded with an http value.
It also stops the release on a pin define that breaks a rule of a prod start, or a `PLATFORM_CERT_PINS` without `PLATFORM_API_URL`, naming the define and never a pin ([security.md](security.md), "Certificate pinning").
`OIDC_REDIRECT_SCHEME` is not read, because an Android build only receives its redirect on the scheme of the manifest placeholder.
`SCREEN_CAPTURE_PROTECTION` is not read either, so the store build keeps screen capture protection on, its default in a prod build ([security.md](security.md)).
`APP_LOCK_REQUIRED` is not read, so the store build leaves the app lock to the user ([security.md](security.md), "App lock").

## Crash symbols

A release build is obfuscated: `--obfuscate --split-debug-info=build/debug-info` renames the Dart symbols and moves their debug information out of the bundle, and R8 shrinks and renames the Java and Kotlin classes.
A crash from such a build is readable only in Sentry, which needs three files from the same build:

- the Dart debug symbols (`build/debug-info/app.android-*.symbols`), which turn the Dart stack's addresses into functions, files and lines;
- the obfuscation map (`build/debug-info/obfuscation.map.json`, from `--extra-gen-snapshot-options=--save-obfuscation-map=`), which turns obfuscated Dart type names in issue titles back into the real ones;
- R8's `mapping.txt`, which turns the Java and Kotlin frames of a native event back into the real class and method names.

After the build, the job deletes the upload keystore, so no Sentry step runs while it is on disk.
It then downloads sentry-cli 2.58.6, the version sentry_dart_plugin 3.4.0 pins, and stops unless its SHA-256 equals the hash written in `release.yml`; the plugin itself only logs a binary whose checksum does not match, so the job never lets the plugin download one.
With that binary, [sentry_dart_plugin](https://pub.dev/packages/sentry_dart_plugin) (a dev dependency, run with `dart run sentry_dart_plugin --sentry-define=bin_path=...`) creates the release in Sentry and uploads the Dart symbols.
The plugin would only log a failed upload of the obfuscation map, so `tool/release/upload_dart_symbol_map.sh` uploads it instead, once for each `app.android-*.symbols` file, and fails on any error or when there is no symbols file.
The plugin does not upload an R8 mapping at all, so the same step runs `sentry-cli upload-proguard` with the same binary.
The workflow gives the mapping a new UUID before each build: Gradle writes it into `BuildConfig.SENTRY_PROGUARD_UUID` from `-PsentryProguardUuid`, `NativeSentry.kt` sets it as the native SDK's `proguardUuid`, and `upload-proguard --uuid` uploads the mapping under it, so Sentry matches each event to its mapping.
The release in Sentry is the `version` of `pubspec.yaml`, such as `1.0.0+1`, the release the app reports on both SDKs.
The bundle also carries the native debug symbols that the Android Gradle plugin puts into its `BUNDLE-METADATA` for Play's own crash reports; Play never delivers them to a device, and the installed `libapp.so` holds no debug information.

The plugin's settings come only from the workflow's environment: the organization `libredb-org`, the project `libredb-mobile`, and the token from the `SENTRY_AUTH_TOKEN` secret of the `release-signing` environment.
The repository holds no `sentry.properties` and no `sentry` section in `pubspec.yaml`; `sentry.properties` is git-ignored, and `test/architecture/sentry_release_symbols_test.dart` fails when one is tracked or when a tracked file holds what looks like a Sentry auth token.
The Sentry wizard writes such a file with a token in it, so do not run it in this repository.

Before the build, `tool/release/check_sentry_upload.sh` decides; it is told only whether the secret is set, never its value:

- a release (a tag or a release-please release) without the secret fails with `The secret SENTRY_AUTH_TOKEN of the release-signing environment is not set`, before anything is built or signed;
- a dry run never uploads, with or without the secret, and says `Dry run: the Dart symbols and the R8 mapping are not uploaded to Sentry` in the log.

To read a crash from a build whose symbols never reached Sentry, such as a dry run's bundle, keep its `build/debug-info` and run `flutter symbolize -i <stack trace file> -d build/debug-info/app.android-arm64.symbols`.

## Check-only defines

Some defines exist only for a check, such as `SENTRY_DEVICE_CHECK`, which crashes the app on purpose to prove the Sentry scrubber on a device.
`tool/release/check_only_defines.txt` lists them, and a store build must never carry one.
Before the build, `tool/release/check_defines.sh` stops the release when one of them is in the build's defines file, or is set as a variable of the repository or of the build job's GitHub environment.
`test/architecture/android_release_setup_test.dart` fails when the app reads a define that is neither in the release's list nor in `check_only_defines.txt`, so a new check-only define has to be listed there.

## One-time steps in outside accounts

Only the maintainer does these, and no value from them is ever written into an issue, a pull request, a commit or a log.

1. Create the upload key on your own machine, for example with `keytool -genkeypair -v -keystore <path>/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`, and keep a backup of the keystore and its passwords outside the repository.
2. In the Play Console, create the app with the package name `org.libredb.mobile` and enroll it in Play App Signing, so Google holds the app signing key and the upload key can be reset if it is lost.
3. In the repository settings, create the environment `release-signing`, add yourself as its required reviewer, limit its deployment branches and tags to `main` and `v*.*.*`, and add the four signing secrets and `ANDROID_UPLOAD_CERT_SHA256` of the upload key.
   The reviewer is the control on the upload key: the tag ruleset below does not restrict creating `v*` tags, so a workflow on another branch with `contents: write` could create a tag that passes the branch and tag limit; with the reviewer, every build that reaches the upload key waits for your approval.
   `base64 -w0 <path>/upload-keystore.jks` prints the keystore on one line, and `keytool -list -v -keystore <path>/upload-keystore.jks -alias upload` shows the SHA-256 fingerprint.
4. Create the environment `release-dry-run` with the same names for a throwaway keystore made only for dry runs; never put the upload key there.
5. Create the environment `play-internal`, add yourself as its required reviewer, and limit its deployment branches and tags to `main` and `v*.*.*`; GitHub would otherwise create it without protection on the first upload job.
6. Add the deployment's variables to the repository.
   Set `PLAY_RELEASE_STATUS` to `draft` until the app's first publication on Play, and remove it after.
7. Add a tag ruleset for `refs/tags/v*` that blocks updating and deleting matching tags, with the organization's admins in its bypass list, so only an admin can move or remove a released tag.
   It does not restrict creating tags: release-please creates `v*` tags with `GITHUB_TOKEN`, and GitHub does not accept the GitHub Actions app as a bypass actor of this ruleset, so a creation rule would block every release.
   The required reviewer of `release-signing` from step 3 is therefore the control on who can start a signed build, together with that environment's limit to `main` and `v*.*.*` and write access to the repository only for the organization's admins.
8. In Sentry, open the organization `libredb-org`, go to Settings > Developer Settings > Organization Tokens, and create a token named for this workflow, such as `libredb-mobile release`.
   An organization token can create releases and upload debug files and mappings for the organization's projects, and nothing else.
   Copy it once into the secret `SENTRY_AUTH_TOKEN` of the `release-signing` environment, and never into `release-dry-run`, a file, an issue or a log.
   Without it every release stops before the build; to replace it, create a new token, update the secret, and revoke the old token in Sentry.
9. In the repository settings, under Settings > Actions > General > Workflow permissions, turn on "Allow GitHub Actions to create and approve pull requests".
   Without it release-please pushes its branch but fails with `GitHub Actions is not permitted to create or approve pull requests.` and opens no release pull request.
   It is safe here because a pull request that a workflow opens reaches no key: the signed build still waits for your approval as the required reviewer of `release-signing`, and the upload waits for your approval of `play-internal`.
10. Merge the first release pull request, which releases `1.0.0`: `release-please-config.json` sets `"release-as": "1.0.0"` on the `.` package, because the manifest already names `1.0.0` and release-please would otherwise plan the first release as `1.1.0`.
   Merging it tags `v1.0.0` and starts the release; approve the build job, let it finish, reject the upload job, download the `release-bundle` artifact, and upload its `app-release.aab` to the internal testing track by hand, because Play accepts no upload through its API before the first one.
   Do not push the tag `v1.0.0` by hand as well, since release-please then cannot create its release of `1.0.0`.
11. Once `v1.0.0` is tagged, remove `release-as` from `release-please-config.json` in a follow-up commit, or every later release pull request stays at `1.0.0`.
12. In Google Cloud, create a service account, and in the Play Console invite it with release rights on this app only.
13. Store the service account's JSON key as the `PLAY_SERVICE_ACCOUNT_JSON` secret of the `play-internal` environment.
14. Approve the build job and then the upload job each time a release waits for them.

## Dry run

Start `release.yml` by hand (Actions, Release, Run workflow) on any branch, or run `gh workflow run release.yml --ref <branch>`.
A dry run checks, tests and builds an obfuscated bundle signed with the throwaway key of the `release-dry-run` environment, keeps it as the `release-bundle` artifact, and never uploads, neither to Play nor to Sentry.
It never reaches the upload key, so its bundle cannot go to Play.

## Platform mode

This is the ordered checklist that takes the store build from Studio-only to Platform mode (epic #298).
Every step says who does it, the owner or an agent, and the gate that has to pass before it.
An agent never sets a variable, starts a workflow, approves an environment, signs, tags, merges a release pull request, uploads, installs from Play or fills a store form; those steps are the owner's.

### What the store build needs

It needs Platform 1.3.0 or later, the first release with `PATCH /api/v1/connections/{id}`, which enabling and disabling a connection uses.
It belongs to the same deployment as `PROD_API_URL` and `OIDC_ISSUER`, because one access token of the client `libredb-mobile` carries both audiences, Studio's and Platform's (libredb-platform `docs/api/v1.md`, "One token serves Studio and Platform").
It is a deployment that serves Platform mode: a Docker or VM installer install with `mobile.enabled: true`, which creates that client with its audience mappers (libredb-platform `installer/README.md`, "Mobile app"), a Helm install of chart 1.3.1 or later with `mobile.enabled: true`, or Railway platform-dev ([platform.md](platform.md#where-platform-mode-works), "Where Platform mode works").
`PLATFORM_API_URL` is that Platform's origin plus `/api` ([platform.md](platform.md#the-defines)), and the release workflow passes it, with `PLATFORM_CERT_PINS`, only when the owner sets it as a variable ([Secrets and variables](#secrets-and-variables)).

### Gates

They pass in this order, and each one holds before the steps that name it:

1. Gate 1: 1.0.0 is released Studio-only through release pull request #212, and `release-as` is gone from `release-please-config.json` ([One-time steps in outside accounts](#one-time-steps-in-outside-accounts), steps 10 and 11).
2. Gate 2: the M10-P and M11-P walkthroughs passed (#251 and #271).
3. Gate 3: the full-system check inside a Platform installer environment passed (#304).
4. Gate 4: the dry run of a Platform-mode bundle passed (#305), steps 1 and 2 below.
5. Gate 5: the owner's approval to ship Platform mode is recorded in `.team/decisions.md`.

### Steps

1. Owner, after gates 1 to 3: set `PLATFORM_API_URL` as a variable of the `release-dry-run` environment only, and start a dry run ([Dry run](#dry-run)).
   A variable of that environment reaches dry runs only, and a dry run signs with the throwaway key and never uploads.
2. Agent, after the owner's dry run of step 1 has finished: read its run log and check the `release-bundle` artifact on the test phone, as #305 describes; this passes gate 4.
3. Agent, after gates 4 and 5: open the turn-on pull request (#306), which moves the Platform-mode listing drafts into the live listing and makes the Platform-mode Data safety and App access answers the current ones.
4. Owner, after step 3's checks are green: review the turn-on pull request and merge it.
5. Owner, after step 4: move `PLATFORM_API_URL` from `release-dry-run` to the `release-signing` environment or to the repository.
   Leave `PLATFORM_CERT_PINS` unset, as the owner ruled on 2026-10-26, so a certificate renewal cannot break the app; a pin of a default Caddy site breaks at its next renewal ([security.md](security.md#keys-that-outlive-renewals), "Keys that outlive renewals").
6. Owner, after step 4: publish the privacy policy again ([Privacy policy](#privacy-policy)), fill the Data safety form and the App access entry from this page ([Data safety](#data-safety), [App access](#app-access)), enter the demo Platform admin account in the Play Console only, and paste the listing texts from `android/fastlane/metadata/android/`.
7. Owner, after steps 5 and 6: merge the release pull request that release-please opens, then approve the build job and, once it has passed, the upload job.
8. Owner, after step 7's upload job has finished: install the build from internal testing on the test phone, because that install uses the phone's Google account, which agents never touch.
9. Agent, after step 8: run the short smoke check of #306 on the test phone, the Studio entry and the Platform entry each signing in to their shell.

### Rolling back Platform mode

1. Owner: halt the release in the Play Console, as [Rolling back](#rolling-back) says.
2. Owner: remove `PLATFORM_API_URL`, and `PLATFORM_CERT_PINS` if it was ever set, from every place it was set: the repository, `release-signing` and `release-dry-run`.
3. Agent, after step 1: open the rollback pull request, which restores the Studio-only listing texts in `android/fastlane/metadata/android/` from the parent of the turn-on pull request's commit, removes the Platform-mode screenshots from `images/phoneScreenshots/` and keeps the Studio ones, and makes the answers for a build without `PLATFORM_API_URL` the current Data safety and App access answers again.
   Its squash commit is a Conventional Commit that release-please lists, such as `fix(release): ship the store build without Platform mode`, so release-please has a commit to release from in step 6.
4. Owner, after step 3's checks are green: review the rollback pull request and merge it.
5. Owner, after step 4: fill the Data safety form and the App access entry with the answers for a build without Platform mode, paste the listing texts from `android/fastlane/metadata/android/` and replace the Play screenshots with the Studio-only ones from its `images/phoneScreenshots/`.
6. Owner, after steps 2 and 5: merge the release pull request that release-please opens, then approve the build job and, once it has passed, the upload job; the release has a higher build number and is Studio-only.

On a device that updates to that build, a stored Platform session is cleared, and the login page shows only the Studio entry with the `platform.not_configured` message (`lib/app/session/session_cubit.dart`; [platform.md](platform.md), M10-P walkthrough step 10).
A stored Studio session is kept.

## Rolling back

Play never accepts a version code lower than one it has, so a bad build is replaced, not taken back.
In the Play Console, open the internal testing track and halt or pause the release so no further tester receives it.
Then fix the problem on `main` and release again; the next release has a higher build number.
The `release-bundle` artifact of each run keeps the exact bundle and mapping for 7 days; Play keeps every uploaded bundle and its mapping after that, and Sentry keeps the release's symbols and mapping.

## Play requirements

Play requires new apps and app updates to target Android 16 (API level 36) from August 31, 2026 ([Play Console Help, target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)).
The app's `targetSdk` is `flutter.targetSdkVersion`, which is 36 in Flutter 3.47.7, so it meets the requirement; check it again with each Flutter upgrade.

## Store listing

The texts the Play Console asks for live in the repository, in English and Turkish, so the maintainer copies them instead of writing them.
The App Store listing reuses them (#199).

### Listing texts

`android/fastlane/metadata/android/en-US/` and `tr-TR/` hold `title.txt`, `short_description.txt` and `full_description.txt` in the fastlane metadata layout, so a later pipeline step can upload them.
`test/architecture/play_listing_metadata_test.dart` fails when a text is missing, empty or longer than Play allows (30, 80 and 4000 characters), or when the two locales do not hold the same files.
The texts say only what the app does today, and that it signs in to the deployment it was built for; change them in the same pull request as a feature they name.

The listing for an upcoming feature is drafted under `android/fastlane/drafts/<feature>/`, in the same layout, and passes the same test, which also requires both locales to hold the same files as the live `en-US`.
`android/fastlane/drafts/platform-mode/` holds the listing for the release that turns Platform mode on.
#306 moves it into `android/fastlane/metadata/android/` in that pull request and deletes the draft directory.
A file the feature does not change is a copy of the live one, so the move replaces whole locale directories.

The release notes of each version come from the generated `CHANGELOG.md` and are never written by hand.
The screenshots, the 512 px icon and the 1024 by 500 feature graphic are added during the phone walkthrough (#196), from the tool/studio-dev sample data only.

### Privacy policy

[privacy-policy.md](privacy-policy.md) and [privacy-policy.tr.md](privacy-policy.tr.md) are the policy; the maintainer publishes them at a URL of their choice and enters that URL in the Play Console.
Each sentence states something the app does, with its source in [security.md](security.md), [crash-reporting.md](crash-reporting.md), [architecture.md](architecture.md), `lib/features/object_browser/data/repositories/cached_object_browser_repository.dart`, `NativeSentry.kt` with the sentry-android defaults it keeps, or `android/app/src/main/AndroidManifest.xml` and its backup rules.
Update both files and their date in the pull request that changes what the app keeps or sends, and publish them again before that version ships, for example:

- when #202 removes the temporary file of a shared source, drop the sentence that says it can stay;
- when the iOS build ships (#199), the policy has to cover iOS, whose backups and crash reports differ.

### Data safety

The answers below are for a store build with `SENTRY_DSN` set; without it, every row marked "Sentry" is answered No.
The store build signs in to the deployment the maintainer runs, so what the app sends to that Keycloak and Studio counts as collected by the developer.
Sentry processes crash reports on the developer's behalf, which Play does not count as sharing.

Overview:

| Question | Answer | Why |
| --- | --- | --- |
| Does the app collect or share any of the required user data types? | Yes | The access token, the statements sent to Studio, and the Sentry reports |
| Is all user data encrypted in transit? | Yes | A prod build stops at start when `PROD_API_URL`, `OIDC_ISSUER` or `SENTRY_DSN` is not https, refuses a Keycloak discovery document that names an endpoint that is not https, and follows no redirect from Studio ([security.md](security.md), "Encryption in transit") |
| Account creation | The app does not allow users to create an account | Accounts are made in the deployment's Keycloak by the organisation; the app only signs in |
| Can users request that their data is deleted? | Yes | Remove my data in Settings, uninstalling, and info@libredb.org for crash reports |

Data types (none is shared, none is processed ephemerally, and none is optional):

| Category | Data type | Collected | Purposes | Source |
| --- | --- | --- | --- | --- |
| Personal info | Name | Yes | App functionality, Account management | The access token Studio receives carries what the `profile` scope gives, `OIDC_SCOPE` defaulting to `openid profile email` |
| Personal info | Email address | Yes | App functionality, Account management | The same token; Studio names the user by `email` or `preferred_username` ([architecture.md](architecture.md)) |
| Personal info | User IDs | Yes | App functionality, Account management | The same token's subject and username |
| App activity | Other user-generated content | Yes | App functionality | The statements sent to Studio, which Studio may record in its audit and query logs |
| App activity | App interactions | Yes (Sentry) | Analytics | The navigation breadcrumbs of a crash report ([crash-reporting.md](crash-reporting.md)), and the session record sent for each use, since sentry-android 8.61.0 keeps `enableAutoSessionTracking` on and `NativeSentry.kt` does not change it |
| App info and performance | Crash logs | Yes (Sentry) | Analytics | The crash reports |
| App info and performance | Diagnostics | Yes (Sentry) | Analytics | The device context of a report, the session records (start, end, duration, crashed or not) and the traces of `tracesSampleRate = 0.2` (`lib/app/bootstrap/sentry_start.dart`) |
| Device or other IDs | Device or other IDs | Yes (Sentry) | Analytics | sentry-android 8.61.0 sets the user id of every event to a random installation id when the app sets none (`DefaultAndroidEventProcessor.mergeUser`), and the app sets none |
| Location | Approximate location | Yes (Sentry), until the setting below is on | Analytics | Sentry derives a place from the client IP at ingestion ([crash-reporting.md](crash-reporting.md)) |

Approximate location becomes No once 'Prevent Storing of IP Addresses' is on in the Sentry project ([crash-reporting.md](crash-reporting.md), the user's steps).
Every other data type is No: precise location, financial info, health and fitness, messages, photos and videos, audio, files and docs, calendar, contacts, web browsing, and the other app activity and performance types.
The app keeps its drafts and history on the device, which Play does not count as collection.
Object search terms go only to the deployment's Studio, as part of the request, and the app keeps no search history.

#### A build with Platform mode

The answers below are for a store build with `PLATFORM_API_URL` set as well as `SENTRY_DSN`; they replace the answers above only for such a build, and the owner decides whether the store build carries Platform mode (`lib/main/main_prod.dart`).
LibreDB Platform runs in the same deployment the maintainer operates, beside its Keycloak and Studio ([privacy-policy.md](privacy-policy.md)), so the data this page declares as collected in Platform mode counts as collected by the developer and not as shared, for the same reason as Studio above.
What Platform mode adds is the access token sent to Platform, which carries the admin's name, e-mail address, subject and username; the statements sent to Studio and the Sentry rows stay Yes, as in the answers above.
The search text, the grants, changes and removals of access and the enabling or disabling of a connection are sent to the admin's own Platform to carry out the admin's request and are recorded there; by the owner's ruling of 2026-10-26 they are not collected by the publisher, so they are not declared.
Each Why cell reads the Play Console Help definitions of collection (data transmitted off the user's device) and of the data type in that row ([Data safety help](https://support.google.com/googleplay/android-developer/answer/10787469), "Data types").
What Platform mode sends and shows is listed in [privacy-policy.md](privacy-policy.md); nothing of a Platform session is stored on the device ([security.md](security.md), "Removing the app's data").

Overview, Platform mode:

| Question | Answer | Why |
| --- | --- | --- |
| Does the app collect or share any of the required user data types? | Yes | As above, plus the access token sent to Platform, which carries the name, e-mail address and user ids declared below ([privacy-policy.md](privacy-policy.md)) |
| Is all user data encrypted in transit? | Yes | As above, and a prod build also stops at start when a set `PLATFORM_API_URL` is not https (`lib/infrastructure/config/environment.dart`, [security.md](security.md), "Encryption in transit"), which `tool/release/check_defines.sh` checks before the build |
| Account creation | The app does not allow users to create an account | Unchanged: Platform's first answer to an account creates its Platform user record from the existing Keycloak account and takes an admin seat (libredb-platform `docs/api/v1.md`), so the user creates no account in the app |
| Can users request that their data is deleted? | Yes | A Studio session as above; a Platform session keeps nothing on the device, so Settings shows no Remove my data there, and signing out or uninstalling removes the session ([security.md](security.md), "Removing the app's data"); crash reports through info@libredb.org |

Data types, Platform mode (none is shared, none is processed ephemerally, and none is optional):

| Category | Data type | Collected | Purposes | Why and source |
| --- | --- | --- | --- | --- |
| Personal info | Name | Yes | App functionality, Account management | Unchanged from the Studio answer, which the same access token already gives; Platform's identity answer returns the admin's own name (`GET /api/v1/me`). The names of other users that the grant list and the directory search show are received from Platform, not sent from the device. |
| Personal info | Email address | Yes | App functionality, Account management | Unchanged: the access token carries the admin's e-mail address. The app never sends another user's e-mail address; a grant names its user by Keycloak id (libredb-platform `docs/api/v1.md`, `PUT /api/v1/connections/{id}/grants/{subject}`). |
| Personal info | User IDs | Yes | App functionality, Account management | Unchanged: the access token carries the admin's own subject and username. A grant names the user it gives access to by Keycloak id inside the grant request (libredb-platform `docs/api/v1.md`, `PUT /api/v1/connections/{id}/grants/{subject}`), which by the same ruling as Other actions below goes to the admin's own Platform and is not collected by the publisher. |
| App activity | In-app search history | No | | Owner's ruling of 2026-10-26: the directory search text and the audit statement search text are a query sent to the admin's own Platform to answer that search, not collected by the publisher, and the app keeps no search history ([privacy-policy.md](privacy-policy.md)) |
| App activity | Other user-generated content | Yes | App functionality | Unchanged: the statements sent to Studio. Platform mode adds none: a grant holds a user, a level and an expiry chosen from lists, with no free text. |
| App activity | Other actions | No | | Owner's ruling of 2026-10-26: the grants, changes and removals of access and the enabling or disabling of a connection are sent to the admin's own Platform and recorded there (libredb-platform `src/features/connections/lib/grant.repository.ts`, `database-connection.repository.ts`), not collected by the publisher |
| App activity | App interactions | Yes (Sentry) | Analytics | Unchanged: Sentry's breadcrumbs and session records, the same in either mode ([crash-reporting.md](crash-reporting.md)) |
| App info and performance | Crash logs | Yes (Sentry) | Analytics | Unchanged |
| App info and performance | Diagnostics | Yes (Sentry) | Analytics | Unchanged |
| Device or other IDs | Device or other IDs | Yes (Sentry) | Analytics | Unchanged |
| Location | Approximate location | Yes (Sentry), until the setting above is on | Analytics | Unchanged |

Every other data type is No in Platform mode as well: the audit log, the grant list and the directory results are received from Platform and held in memory only ([security.md](security.md)), which is not collection from the device.
Whether the store build carries Platform mode at all stays the owner's decision, made before the owner fills the form in step 6 of [Platform mode](#platform-mode).

### Content rating

The questionnaire's answers, for the category of utility and productivity apps:

- No violence, fear, sexual content, crude humour, profanity, drugs, alcohol, tobacco or gambling.
- Users cannot talk to each other or exchange content through the app, and the app shares no user's location with other users.
- In a build with Platform mode, an admin who gives another user access to a connection, changes it or removes it is not users talking to each other or exchanging content: the grant carries only a user, a level and an expiry, sends the other user no message, and the content of the databases stays in Studio.
- No digital purchases and no unrestricted web browsing.
- The app shows the content of the organisation's own databases; it supplies no content of its own, and the review deployment holds sample data only.

Other declarations: the app contains no ads, its target audience is 18 and over, it is not a news or government app, and it has no financial or health features.

### App access

Every screen needs a sign-in, so the app access entry is "All or some functionality is restricted".
The maintainer creates the demo account in the review deployment's Keycloak, with a Studio role that reaches the sample connections only, and enters its username and password in that entry of the Play Console; neither is ever written into the repository, an issue or a pull request.
The instructions for the entry, which name no host and no password:

```text
LibreDB Mobile is a client of LibreDB Studio, so every screen needs a sign-in.
This build signs in to the publisher's own LibreDB deployment, which holds sample databases only; no VPN, code or other setup is needed.
1. Open the app and tap "Sign in with SSO".
2. On the sign-in page that opens in the browser, enter the username and password given in this entry.
3. The Connections tab lists the sample connections; tap one to open it.
4. The Browse tab shows its objects; open a table and tap "View rows" to see its rows. Columns with sensitive names, such as email, are masked.
5. The SQL tab runs statements on a SQL connection, for example SELECT 1. A statement that may change data asks for confirmation before it runs.
```

In a build with `PLATFORM_API_URL` set, the login page has two entries instead of the single SSO button, so the entry gets the instructions below in place of the block above; they name no host, no username and no password.

The maintainer creates a second demo account in the review deployment's Keycloak with Platform's admin role, and enters both accounts in the App access entry of the Play Console.
The admin account takes one admin seat of that deployment's license on its first Platform sign-in, so the license needs a free one.
A Platform admin sees and can change every connection of the install, so the review deployment must hold sample connections only.
The Studio demo account and its grants stay as they are.

```text
LibreDB Mobile is a client of LibreDB Studio and LibreDB Platform, so every screen needs a sign-in.
This build signs in to the publisher's own LibreDB deployment, which holds sample databases only; no VPN, code or other setup is needed.
This entry gives two accounts: a Studio account and a Platform admin account.
Studio:
1. Open the app and tap "Sign in to Studio".
2. On the sign-in page that opens in the browser, enter the Studio account's username and password.
3. The Connections tab lists the sample connections; tap one to open it.
4. The Browse tab shows its objects; open a table and tap "View rows" to see its rows. Columns with sensitive names, such as email, are masked.
5. The SQL tab runs statements on a SQL connection, for example SELECT 1. A statement that may change data asks for confirmation before it runs.
6. Tap the avatar at the top right, tap "Logout" and confirm.
Platform:
7. Tap "Sign in to Platform" and enter the Platform admin account's username and password on the sign-in page.
8. The "Home" tab shows the organization and the signed-in admin.
9. The "Connections" tab lists every connection of the deployment; tap one to see who holds access to it.
10. The "Audit" tab lists the queries Studio ran on these connections; "Filters" narrows the list.
Please do not tap "Add access", "Change access", "Remove access" or "Disable connection": other testers use the same sample connections.
```

`test/architecture/release_docs_test.dart` fails when a double-quoted string inside a `text` block of this section is not a label of `lib/l10n/intl_en.arb`, so a pull request that renames such a label updates these instructions in the same change.

## Actions

Every action in every workflow under `.github/workflows/` is pinned to a full commit SHA with its version in a comment, and `test/architecture/android_release_setup_test.dart` fails on a tag or branch reference or a missing version comment.
To update an action, resolve the new tag to its commit with `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` (an annotated tag needs one more lookup of its object) and change the SHA and the comment together.
The upload uses [r0adkll/upload-google-play](https://github.com/r0adkll/upload-google-play), which talks to the Play Developer API with the service account and uploads the mapping file with the bundle.
