# Adoption figures from the server

2026-10-30, work table row 55 (`#284` child 3, "benimseme sayıları çalışma anında — 2. sürüm").
Every claim below was read at `1ea45674` (`origin/main`) unless a commit is named.
This note proposes; it changes no code.

## Intent

The owner decided on 2026-10-30 that the adoption figures the introduction shows **should come from a
server, in the second release**. The known complication is that `libredb/libredb-adoption` is private
(`gh repo view libredb/libredb-adoption` → `visibility: PRIVATE`, `updatedAt 2026-10-30T06:09:28Z`), so a
shipped app cannot read it and a credential must never be in the binary — the reasoning the owner's
earlier reversal already recorded in `#284`.

This note says what is true today, prices the realistic ways to serve the figures against this
repository's own rules, and recommends one.

## What is true today

**The three numbers.** How many database engines LibreDB ships support for, how many channels it is
published on, and how many official vendor and project sites list it
(`lib/shared/adoption/adoption_figures.dart:5-13`, fields at `:65-72`).

**Where they come from.** The committed asset `assets/adoption.json` — `42` engines, `48` channels, `31`
listings, `measuredOn 2026-10-25` (`assets/adoption.json:1-6`), declared at `pubspec.yaml:98` and read
from the bundle by `AdoptionFiguresAsset` (`lib/features/onboarding/data/repositories/adoption_figures_asset.dart:11,19-28`)
behind `IAdoptionFiguresSource` (`lib/features/onboarding/domain/repositories/adoption_figures_source.dart:8-13`).
Anything unreadable, missing, non-integer or zero collapses into the same figures written as a constant in
the source (`adoption_figures.dart:27-33,39-51,56-63,84`). No network call is involved anywhere in that path.

**How the asset is produced.** `scripts/generate_adoption.sh:25-36` downloads `data/engines.jsonl`,
`data/channels.jsonl` and `data/listings.jsonl` from the private repository with an authenticated `gh`
(`:19-20`) and runs `tool/adoption/generate.dart`, whose reader takes the newest value of a metric by
`date` then `measured_at` and counts distinct `listings.*` names
(`tool/adoption/adoption_series.dart:21-30,37-44,51-59`). Nothing in `lib/` runs it; its output is committed.

**No screen shows the figures any more.** The six-screen deck replaced the four panels that carried them:
`OnboardingPage` no longer reads the source at all
(`test/features/onboarding/presentation/pages/onboarding_page_test.dart:28-31`), and the last widget that
rendered them, `OnboardingPanel`, was deleted in `2550f454` ("drop the dead OnboardingPanel", PR #452).
None of the six screens states a number about the product (`lib/l10n/intl_en.arb:1688-1777`, the `ob1_*`
… `ob6_*` block; the only numerals are the step counter `ob_step`, `:1684`).

**So the earlier note is right: `IAdoptionFiguresSource` has no consumer.** Measured exactly — across all
of `lib/` and `test/` the interface appears five times: its own declaration
(`adoption_figures_source.dart:8`), its one implementation (`adoption_figures_asset.dart:6-7`), the
factory `app_dependencies.dart:273`, the provider `app_scope.dart:132`, and the comment in
`onboarding_page_test.dart:31` explaining its absence. Nothing calls `read()` outside
`test/features/onboarding/data/repositories/adoption_figures_asset_test.dart`. The two l10n keys that
formatted the figures survive unused: `onboarding_studio_figures` (`lib/l10n/intl_en.arb:114`) and
`onboarding_listings_body` (`:131`) are referenced only from `lib/generated/l10n.dart:482` and the two
`messages_*.dart` tables, never from hand-written Dart.

**How stale they can get: without bound.** The asset has been committed once, in `b8248757` (2026-10-25,
"bake the adoption figures into the app"). No job refreshes it: the workflows are `build_and_test.yml`,
`release-please.yml`, `release.yml` and `sonar_scanner.yml`, none mentions adoption, and the only secrets
they use are the Android signing four, `PLAY_SERVICE_ACCOUNT_JSON`, `SENTRY_AUTH_TOKEN`, `SENTRY_DSN` and
`SONAR_TOKEN` — so CI holds no credential for the private series. Measured today by running
`tool/adoption/generate.dart` against the live series: **43 engines, 48 channels, 31 listings, measured
2026-10-30** — the committed asset is already one engine behind after five days, and a store build freezes
its figures for as long as a user keeps that version.

**One document is already stale.** `docs/studio.md:329` still says "the onboarding flow's four panels
render with the adoption figures from `assets/adoption.json`".

## The rules an option has to pass

- The app talks to Studio and Platform and to nothing else: `app_dependencies.dart:270-272`,
  `lib/infrastructure/http/api_target.dart:5-17`, and the guard
  `test/architecture/import_guard_test.dart:204` ("Studio and Platform code stay apart").
- `docs/privacy-policy.md:26-28` and `docs/privacy-policy.tr.md:26-28` state "four kinds of servers, and
  to no others on its own". A third host means editing both policies.
- `docs/security.md:95-103` holds a closed table of three pin defines, one per host.
- The introduction runs before sign-in (`lib/features/onboarding/navigation/onboarding_routes.dart:15-19`),
  so anything fetched must be fetchable without a token. Studio and Platform serve exactly three
  endpoints that way (`lib/infrastructure/http/public_endpoint.dart:19-23`).
- The screen must never show a zero and never show an error
  (`adoption_figures_source.dart:9-13`, `adoption_figures.dart:35-38`).
- A Studio answer is per deployment: the base URL is `PROD_API_URL`
  (`docs/architecture.md:183`, `lib/main/main_prod.dart:27`), and the stated direction is that installs
  point the app at their own Platform and Studio
  (`docs/superpowers/specs/2026-10-25-main-entrypoints-design.md`, "Long-term direction").
- A new `ApiClient` method needs a recorded mock answer and a row in the coverage table
  (`test/architecture/mock_asset_coverage_test.dart:28-42`).

## The options

| Option | What must exist that does not today | Owner | Cost | Offline / first run with no network |
| --- | --- | --- | --- | --- |
| **A. Studio endpoint** (public `GET /api/adoption`) | Studio must both *ingest* the private series and serve it on a tokenless path (`src/shared/lib/public-paths.ts`); a Studio release; app-side 404 tolerance for older Studios; a mock asset plus a coverage row | `libredb-studio` | High, and it lands on another repo's release train. Worse: every self-hosted Studio would have to serve product-wide numbers it has no source for — the figures are about LibreDB, not about a tenant's install | Committed asset fallback, so unchanged |
| **B. Platform endpoint** (public `GET /api/v1/adoption`) | Everything in A, in `libredb-platform` | `libredb-platform` | Highest. Platform is optional: a build without a Platform target sends it nothing at all (`docs/architecture.md:105`, `docs/platform.md:15,26`), and the app reaches Platform only after the Platform entry is chosen — so the default build, the one most users get, would have no figures | Committed asset fallback, so unchanged |
| **C. Public static file on libredb.org** | `public/adoption.json` in `libredb/libredb.github.io` (that `public/` is served as-is; production is GitHub Pages at libredb.org, test is Netlify — `netlify.toml:1-11`), plus a scheduled workflow there holding a read token for the private repo (the site has only `ci.yml`, `deploy.yml`, `deploy-test.yml` and no adoption reference). In the app: a third host, so `privacy-policy.md` + `.tr.md`, the pin table in `security.md`, "The three parties" in `architecture.md:8-36` and the import guard | Mobile + site, both ours | Moderate, split across two repos we own; no other team's release train, no credential in the app | Committed asset fallback — identical to today's behaviour, and the fetch can be dropped entirely on a slow network |
| **D. Build-time fetch in CI** | A read credential for the private repo in this repo's CI (a PAT or GitHub App; `GITHUB_TOKEN` cannot read another private repo), and a step calling `scripts/generate_adoption.sh`, which already accepts `DART=dart` for CI (`:11-14`) | Mobile only | Lowest: no app change, no privacy-policy change, no pin decision, no new guard | Perfect — nothing is fetched at run time |

D is the honest floor, but it is not "from a server": its freshness is the release cadence, which is the
thing the owner decided against.

## Recommendation

**C** — publish `adoption.json` on libredb.org from the private series on a schedule and have the app read
it at run time with the committed asset as its fallback: it is the only option that is genuinely "from a
server" without putting a credential in the binary, without asking Studio or Platform for product-wide
data that a tenant's install does not own, and it degrades to exactly today's behaviour offline and on a
first run.

It is gated on one product decision that comes first: **today no screen shows a figure**, so until the
deck regains a number-bearing screen, serving the figures would be building a pipe with nothing at its end.

## What the second release would have to build

1. **Decide the screen.** Which of the six screens carries which numbers, in both languages. Without this,
   items 2–7 have no consumer.
2. **Site repo.** `public/adoption.json` in `libredb/libredb.github.io`, written by a scheduled workflow
   (daily is enough — the measured drift is one engine in five days) that reads the three private series
   with an org token and applies the same reading rules as `tool/adoption/adoption_series.dart:21-59`:
   newest by `date` then `measured_at`, distinct `listings.*` count. It must emit the shape the app already
   parses, `{engines, channels, listings, measuredOn}` (`adoption_figures.dart:39-51`), and must refuse to
   write a zero exactly as `adoption_series.dart:51-58` does.
3. **A run-time source in the app.** A second `IAdoptionFiguresSource` that fetches and falls back to
   `AdoptionFiguresAsset`. Not through `ApiClient`: that client carries Studio's error envelope, the auth,
   refresh, retry and circuit-breaker chain and Studio's pins (`api_target.dart:5-17`,
   `docs/http-client.md:3`). A small dedicated client with a short timeout, one read per app run, and no
   ability to hold the first frame of onboarding.
4. **Guards.** The new host and client in `test/architecture/import_guard_test.dart` (its
   `studioPlatformViolations` set at `:232-240` assumes two servers), and mock mode must answer the read
   from `assets/mock/` or not send it at all (`test/architecture/mock_asset_coverage_test.dart:28-42`).
5. **Docs.** `docs/privacy-policy.md:26-28` and `docs/privacy-policy.tr.md:26-28` (the "four kinds of
   servers" sentence and both date lines), the pin-define table decision in `docs/security.md:95-103`,
   "The three parties" in `docs/architecture.md:8-36`, and the stale `docs/studio.md:329`.
6. **Keep the floor.** The committed asset and the fallback constant stay, and get refreshed at release
   time; option D is what makes a failed fetch invisible rather than embarrassing.
7. **The invariant stays.** Never a zero, never an error, never a spinner that holds the introduction —
   the rule `adoption_figures_source.dart:9-13` already states.

## What this note could not determine

- Whether the owner wants the numbers back on a screen at all. Nothing shows them today, and that decision
  is upstream of every option here.
- Whether the site repository may hold a read token for the private adoption repository. It holds none
  today, and that is an org decision rather than a code one.
- Whether Cloudflare sits in front of libredb.org in a way that changes caching. What the repository states
  is GitHub Pages for production (`netlify.toml:1-11`) with a `CNAME` in `public/`; the edge was not
  measured from here.
