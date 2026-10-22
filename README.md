# LibreDB Mobile

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)
![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-2E7D32)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

The mobile client of [LibreDB Studio](https://github.com/libredb/libredb-studio), for Android and iOS.
Sign in with your organization's Keycloak account, see the databases Studio offers you, look inside them, and run SQL from your phone.

Studio stays the only place that holds database credentials and talks to the databases.
The phone holds a Keycloak session and sends Keycloak's access token to Studio; under [LibreDB Platform](https://github.com/libredb/libredb-platform), Studio shows each person exactly the connections an admin granted them.

## Status

The project is at its start.

| Feature | Status |
| --- | --- |
| Sign-in through Keycloak (PKCE, refresh, logout) | Done |
| Connection list | First version |
| Studio API layer | Done |
| Object browser | Planned |
| SQL editor | Planned |
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

Studio accepts the token through its bearer channel for native clients (`OIDC_BEARER_AUDIENCE`), which is on Studio's main branch and in no release yet: Studio 1.0.0 does not have it.
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

Without a Studio, the app runs against recorded answers:

```shell
fvm flutter run --target lib/main/main_local.dart
```

## Development

```shell
fvm dart format . --line-length=120   # format
fvm flutter analyze                   # lint
fvm flutter test                      # all tests
fvm flutter test --coverage           # with coverage; CI requires 65 percent or more
```

The code follows a feature-first clean architecture with BLoC; [CLAUDE.md](CLAUDE.md) holds the conventions for people and coding agents alike, and [docs/testing-architecture.md](docs/testing-architecture.md) the test structure.

## Documentation

| Document | What it covers |
| --- | --- |
| [docs/roadmap.md](docs/roadmap.md) | Milestones and what each one delivers |
| [docs/architecture.md](docs/architecture.md) | App layers, the Studio contract, errors, sessions and security |
| [docs/studio.md](docs/studio.md) | Keycloak and Studio settings, the local stack, device setup |
| [docs/oidc.md](docs/oidc.md) | The OpenID Connect sign-in in depth |
| [docs/testing-architecture.md](docs/testing-architecture.md) | Test layers, doubles and guard tests |
| [docs/template.md](docs/template.md) | The Flutter template this app grew from: Sentry, certificate pinning, caching and other building blocks |

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE).
