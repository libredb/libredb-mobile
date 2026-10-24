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
   It stops when the build would carry a define meant for checks only (see below), decodes the upload keystore into the runner's temp directory, builds `flutter build appbundle --release --target lib/main/main_prod.dart` with the deployment's defines and `-PrequireReleaseSigning=true`, and checks that the bundle's signing certificate has the fingerprint in `ANDROID_UPLOAD_CERT_SHA256`.
6. It keeps the bundle and R8's `mapping.txt` for 7 days as the `release-bundle` workflow artifact, and deletes the keystore and the defines file, also when a step failed.
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

Secret of the `play-internal` environment:

| Name | What it holds |
| --- | --- |
| `PLAY_SERVICE_ACCOUNT_JSON` | The JSON key of the Play service account |

Repository secret:

| Name | What it holds |
| --- | --- |
| `SENTRY_DSN` | Optional; the build reports crashes only with it ([crash-reporting.md](crash-reporting.md)) |

Repository variables, the deployment the build signs in to ([studio.md](studio.md), [oidc.md](oidc.md), [security.md](security.md)):

| Name | Required |
| --- | --- |
| `PROD_API_URL` | Yes |
| `OIDC_ISSUER` | Yes |
| `OIDC_CLIENT_ID` | Yes |
| `OIDC_SCOPE`, `OIDC_AUDIENCE`, `OIDC_PROMPT`, `OIDC_AUTO_REDIRECT`, `OIDC_LOGOUT_HINT` | No |
| `STUDIO_CERT_PINS`, `OIDC_CERT_PINS` | No; pinning ships off |
| `SENTRY_ENVIRONMENT`, `SENTRY_DIST` | No; the native Sentry SDK picks them from the build when unset |
| `PLAY_RELEASE_STATUS` | No; `completed` by default, `draft` while Play still treats the app as a draft |

An empty variable is left out of the build, and the build stops when a required one is missing.
`OIDC_REDIRECT_SCHEME` is not read, because an Android build only receives its redirect on the scheme of the manifest placeholder.
`SCREEN_CAPTURE_PROTECTION` is not read either, so the store build keeps screen capture protection on, its default in a prod build ([security.md](security.md)).
`APP_LOCK_REQUIRED` is not read, so the store build leaves the app lock to the user ([security.md](security.md), "App lock").

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
   The reviewer matters because the tag ruleset below lets the GitHub Actions app create `v*` tags, so a workflow on another branch with `contents: write` could create a tag that passes the branch and tag limit; with the reviewer, every build that reaches the upload key waits for your approval.
   `base64 -w0 <path>/upload-keystore.jks` prints the keystore on one line, and `keytool -list -v -keystore <path>/upload-keystore.jks -alias upload` shows the SHA-256 fingerprint.
4. Create the environment `release-dry-run` with the same names for a throwaway keystore made only for dry runs; never put the upload key there.
5. Create the environment `play-internal`, add yourself as its required reviewer, and limit its deployment branches and tags to `main` and `v*.*.*`; GitHub would otherwise create it without protection on the first upload job.
6. Add the deployment's variables to the repository.
7. Add a tag ruleset for `refs/tags/v*` that restricts creating, updating and deleting matching tags to yourself and the GitHub Actions app in its bypass list, so release-please can still tag its releases and no one else can start a signed build with a tag.
8. In the repository settings, under Settings > Actions > General > Workflow permissions, turn on "Allow GitHub Actions to create and approve pull requests".
   Without it release-please pushes its branch but fails with `GitHub Actions is not permitted to create or approve pull requests.` and opens no release pull request.
   It is safe here because a pull request that a workflow opens reaches no key: the signed build still waits for your approval as the required reviewer of `release-signing`, and the upload waits for your approval of `play-internal`.
9. Merge the first release pull request, which releases `1.0.0`: `release-please-config.json` sets `"release-as": "1.0.0"` on the `.` package, because the manifest already names `1.0.0` and release-please would otherwise plan the first release as `1.1.0`.
   Merging it tags `v1.0.0` and starts the release; approve the build job, let it finish, reject the upload job, download the `release-bundle` artifact, and upload its `app-release.aab` to the internal testing track by hand, because Play accepts no upload through its API before the first one.
   Do not push the tag `v1.0.0` by hand as well, since release-please then cannot create its release of `1.0.0`.
10. Once `v1.0.0` is tagged, remove `release-as` from `release-please-config.json` in a follow-up commit, or every later release pull request stays at `1.0.0`.
11. In Google Cloud, create a service account, and in the Play Console invite it with release rights on this app only.
12. Store the service account's JSON key as the `PLAY_SERVICE_ACCOUNT_JSON` secret of the `play-internal` environment.
13. Approve the build job and then the upload job each time a release waits for them.

## Dry run

Start `release.yml` by hand (Actions, Release, Run workflow) on any branch, or run `gh workflow run release.yml --ref <branch>`.
A dry run checks, tests and builds a bundle signed with the throwaway key of the `release-dry-run` environment, keeps it as the `release-bundle` artifact, and never uploads.
It never reaches the upload key, so its bundle cannot go to Play.

## Rolling back

Play never accepts a version code lower than one it has, so a bad build is replaced, not taken back.
In the Play Console, open the internal testing track and halt or pause the release so no further tester receives it.
Then fix the problem on `main` and release again; the next release has a higher build number.
The `release-bundle` artifact of each run keeps the exact bundle and mapping for 7 days; Play keeps every uploaded bundle and its mapping after that.

## Play requirements

Play requires new apps and app updates to target Android 16 (API level 36) from August 31, 2026 ([Play Console Help, target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878)).
The app's `targetSdk` is `flutter.targetSdkVersion`, which is 36 in Flutter 3.47.7, so it meets the requirement; check it again with each Flutter upgrade.

## Actions

Every action in `release.yml` and `release-please.yml` is pinned to a full commit SHA with its version in a comment, and `test/architecture/android_release_setup_test.dart` fails on a tag or branch reference.
The upload uses [r0adkll/upload-google-play](https://github.com/r0adkll/upload-google-play), which talks to the Play Developer API with the service account and uploads the mapping file with the bundle.
