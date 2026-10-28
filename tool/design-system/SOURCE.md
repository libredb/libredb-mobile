# Where these files come from

`tokens/` is a **verbatim copy** of the LibreDB design system's token files. Nothing in this directory is edited
here, ever. It is reference material: the app's Dart tokens are checked against it, and a value that needs to differ
is a recorded deviation, not an edit.

| | |
|---|---|
| Repository | `libredb/libredb.github.io` |
| Path there | `design-system/tokens/` |
| Taken at | `857d454` — the last commit that touched `design-system/`, 2026-09-27 |
| Taken on | 2026-10-28, for #283 |
| Files | `base`, `colors`, `elevation`, `fonts`, `layout`, `motion`, `shape`, `spacing`, `theme`, `typography` |

The system's own README records where *it* came from: *"No codebase, Figma file or existing production site was
provided. Everything below is derived from the marks, the checklist, and decisions confirmed with the user."*

## `other-consumer/a11y.css` — not part of the system

`other-consumer/a11y.css` is a verbatim copy of `src/styles/a11y.css` in the same repository, taken at `2e8c39b`
(2026-10-27). It is **not** a token file and nothing in the design system declares it. It is the *website's*
record of where the system and WCAG 1.4.3 collide, and its own header states the method: each value is "the
MINIMUM lift that clears 4.5:1 on the darkest/lightest surface the token is actually painted on", computed with
that repository's `scripts/contrast.mjs` and locked by its `tests/contrast.test.ts`.

It is here so this app can take a lift the other consumer has already measured instead of computing a second
one. Two consumers of one design system showing two different greys for the same token is the thing a shared
design system exists to prevent. `design_system_import_test.dart` reads it for `--text-tertiary` and fails if
this app and the website stop agreeing — including if the website re-lifts the token, in which case this app
follows rather than drifting.

Refresh it with the token files, from `origin/main`:

```sh
git show origin/main:src/styles/a11y.css > <libredb-mobile>/tool/design-system/other-consumer/a11y.css
```

The lifts it carries that this app does **not** take: `--console-text-tertiary`, which belongs to the website's
console ramp and has no counterpart here, and the gradient headline stops, which this app has no gradient text
to paint. The lifts this app computes **itself** are `outline` and `outlineVariant`: 1.4.3 is about text, the
website never applied 1.4.11 to its borders, and so there is no value there to take.

## Why a copy and not a reference

The site's repository is not checked out on CI, and a token file read across a folder boundary would make this
repository's tests depend on a path that may not exist. A copy here, with the commit it was taken at written above,
is what lets a later drift be *detected*: `test/architecture/design_system_import_test.dart` reads these files and
fails when the app's Dart tokens stop agreeing with them.

This is the same shape the website uses — `src/styles/ds/` is a byte-identical vendored copy there, held by
`tests/ds-integrity.test.ts` — so both consumers of this design system treat it the same way.

## Refreshing it

Only when the upstream design system actually changes. From a checkout of the site's repository:

```sh
cd <libredb.github.io>
git fetch origin
git log -1 --format='%h %ad' --date=short origin/main -- design-system/   # the new stamp
for f in base colors elevation fonts layout motion shape spacing theme typography; do
  git show "origin/main:design-system/tokens/$f.css" > <libredb-mobile>/tool/design-system/tokens/$f.css
done
```

Read from `origin/main`, never from the working tree: a local checkout of that repository was 18 commits stale the
day this was imported, and the staleness was invisible until it was measured.

Then update the stamp above, run the suite, and resolve whatever the import test reports — each value that moves is
either followed in Dart or recorded as a deviation with its reason.

## What is *not* taken from here

- **Fonts.** `tokens/fonts.css` sets Geist. The website is the one token file it does not import, overriding it with
  Plus Jakarta Sans + JetBrains Mono, self-hosted (`docs/DECISIONS.md § Fonts` there). This app took that same pair
  in #349, so it matches what the brand actually ships rather than what this file says.
- **Components.** The site ported none of them — *"The needed set turned out to be empty"* — and neither does this
  app. The 13 Flutter components stay; only values and rules cross over.
