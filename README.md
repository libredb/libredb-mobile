# LibreDB Mobile

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-2E7D32)
[![License: Elastic License 2.0](https://img.shields.io/badge/License-Elastic%202.0-005571.svg)](LICENSE)

The mobile client of [LibreDB Studio](https://github.com/libredb/libredb-studio), for Android and iOS.
Sign in with your organization's Keycloak account, see the databases Studio offers you, look inside them, and run SQL from your phone.

Studio stays the only place that holds database credentials and talks to the databases.
The phone holds a Keycloak session and sends Keycloak's access token to Studio; under [LibreDB Platform](https://github.com/libredb/libredb-platform), Studio shows each person exactly the connections an admin granted them.

## Status

Milestones M2 to M5 are done, each checked end to end on the Android emulator against `tool/studio-dev`.
`tool/studio-dev` now runs Studio 1.1.0, the first release with the bearer channel the app needs.
M6, the first store release, is in progress: the app is not in a store yet.
The iOS build is still to be checked on macOS ([#91](https://github.com/libredb/libredb-mobile/issues/91), [#199](https://github.com/libredb/libredb-mobile/issues/199)).

| Feature | Status |
| --- | --- |
| Sign-in through Keycloak (PKCE, refresh, logout) | Done |
| Studio API layer | Done |
| Connection list, with favorites, recent connections and a connection check | Done (M2) |
| Object browser, with search and a Redis key browser | Done (M3) |
| Result grid and data preview, with Studio's masking rules | Done (M4) |
| SQL editor, with a write confirmation, cancel, script runs, drafts and history | Done (M5) |
| App lock, screen capture protection, Remove my data and https only for a prod build | Done (M6) |
| Certificate pinning, off by default | Done (M6) |
| Release signing, obfuscation and a tag-driven pipeline to Play internal testing | Done (M6) |
| Store listing and a walkthrough on a physical phone | In progress (M6) |
| Editor power tools and admin on the go | Planned (M7, M8) |
| Grant a connection as an admin | Planned, needs Platform v1 |

The plan, milestone by milestone, is in [docs/roadmap.md](docs/roadmap.md).

## How it fits together

```text
 Phone (this app)                    Keycloak                     LibreDB Studio
 ───────────────                     ────────                     ──────────────
 1. Sign in (PKCE)  ───────────────▶ realm, client libredb-mobile
                    ◀─────────────── ID token, access token, refresh token
 2. API call        ── Authorization: Bearer <access token> ─────▶ checks issuer, audience, client, role
                    ◀──────────────────────────────────────────── connections, objects, query results
 3. Token expired   ── refresh ────▶ new tokens
```

Studio accepts the token through its bearer channel for native clients (`OIDC_BEARER_AUDIENCE`), which Studio 1.1.0 is the first release to carry: Studio 1.0.0 does not have it.
[docs/architecture.md](docs/architecture.md) describes the layers of the app and the Studio contract they follow.

## Quick start

You need [FVM](https://fvm.app/), Docker with Compose v2.23.1 or newer, and an Android emulator or an iOS simulator.

```shell
fvm install && fvm flutter pub get

# Keycloak and Studio on https://localhost:8443 and https://localhost:9443
docker compose -f tool/studio-dev/docker-compose.yml up -d --wait

# Android emulator: trust the local CA and forward the ports, after every emulator boot
tool/studio-dev/trust-android-emulator.sh

fvm flutter run --target lib/main/main_prod.dart --dart-define-from-file=tool/studio-dev/studio-dev.env
```

Sign in as `admin` / `admin` or `user` / `user`.
[docs/studio.md](docs/studio.md) explains the stack, the iOS simulator and how to point the app at your own Studio and Keycloak.

Without a Studio, the app runs against recorded answers, and "Sign in with SSO" signs in through a debug-only stand-in for Keycloak ([docs/oidc.md](docs/oidc.md#mock-mode-without-keycloak)):

```shell
fvm flutter run --target lib/main/main_local.dart
```

## Development

```shell
scripts/generate_l10n.sh              # regenerate lib/generated after an ARB change
fvm dart format . --line-length=120   # format
fvm flutter analyze                   # lint
fvm flutter test                      # all tests
fvm flutter test --coverage           # with coverage; CI requires 65 percent or more
```

Generated code is never edited by hand: `lib/generated` comes only from `scripts/generate_l10n.sh`, which runs `intl_utils` and formats its output at 120 columns, and CI fails when the committed files differ from what it writes.

The code follows a feature-first clean architecture with BLoC; [CLAUDE.md](CLAUDE.md) holds the conventions for people and coding agents alike, and [docs/testing-architecture.md](docs/testing-architecture.md) the test structure.

## Documentation

| Document | What it covers |
| --- | --- |
| [docs/roadmap.md](docs/roadmap.md) | Milestones and what each one delivers |
| [docs/architecture.md](docs/architecture.md) | App layers, the Studio contract, errors, sessions and security |
| [docs/studio.md](docs/studio.md) | Keycloak and Studio settings, the local stack, device setup |
| [docs/oidc.md](docs/oidc.md) | The OpenID Connect sign-in in depth |
| [docs/http-client.md](docs/http-client.md) | Retries, idempotency keys and the response cache |
| [docs/security.md](docs/security.md) | Token storage, certificate pinning, screen capture protection and the inactivity sign-out |
| [docs/crash-reporting.md](docs/crash-reporting.md) | Sentry and what it masks before an event leaves the device |
| [docs/development.md](docs/development.md) | Toolchain, test slices, the feature generator and CI |
| [docs/release.md](docs/release.md) | Release signing, the changelog, the upload to Play internal testing, and the store listing answers |
| [docs/privacy-policy.md](docs/privacy-policy.md) | The app's privacy policy, also in Turkish ([docs/privacy-policy.tr.md](docs/privacy-policy.tr.md)) |
| [docs/testing-architecture.md](docs/testing-architecture.md) | Test layers, doubles and guard tests |
| [docs/mock-architecture.md](docs/mock-architecture.md) | How recorded answers in `assets/mock/` are served |
| [docs/feature-first-clean-boundaries.md](docs/feature-first-clean-boundaries.md) | Layer boundaries and dependency rules |

## Contributing

Issues are welcome: report a bug or propose a change in [GitHub Issues](https://github.com/libredb/libredb-mobile/issues).
Pull requests from outside the team are not accepted at this time, as [CONTRIBUTING.md](CONTRIBUTING.md) explains, and [SECURITY.md](SECURITY.md) says how to report a vulnerability.
For licensing, write to [info@libredb.org](mailto:info@libredb.org).

## License

LibreDB Mobile is source-available under the [Elastic License 2.0](LICENSE), with SEKOYA GRUP BİLİŞİM VE TEKNOLOJİ LİMİTED ŞİRKETİ as the licensor.
You may use, copy, distribute and modify it.
You may not provide it to third parties as a hosted or managed service, or alter, remove or obscure any licensing, copyright or other notices of the licensor.
This is a summary: the [LICENSE](LICENSE) file holds the full terms.

The app includes code from the [flutter-bloc-advanced](https://github.com/cevheri/flutter-bloc-advanced) template, which is licensed under the MIT License; [NOTICE](NOTICE) reproduces that license.
The app bundles NOTICE and shows it under Settings, Licenses.
