# The design system, as this app carries it

Every token this app paints with, its value, and the file and line it lives on.

**This page exists to be cited.** M14 (#283) imported the LibreDB design system, and M16's review layer judges the
app's visual consistency against it. A finding that cites nothing is not a finding: it is taste. Cite a row of this
page by its `file:line`, and when this page and the code disagree, **the code is right and this page is the defect**
— say so, because a page that has drifted is worse than no page.

Nothing here is a decision. Each value was either taken from the design system or deviates from it for a measured
reason, and both are stated. Where a row says a token was lifted, the number it was lifted to and the floor it was
lifted for are given, so a reviewer can check the arithmetic rather than take the word.

## Where it comes from

`tool/design-system/tokens/` is a byte-identical copy of `design-system/tokens/` in `libredb/libredb.github.io`,
taken at `857d454`. `tool/design-system/SOURCE.md` records the stamp and how to refresh it. A copy rather than a
reference, because that repository is not checked out on CI and the copy is what makes a drift *detectable*.

`tool/design-system/other-consumer/a11y.css` is the website's own accessibility layer, `src/styles/a11y.css` at
`2e8c39b`. It is **not** part of the design system. It is there so this app can take a contrast lift the other
consumer has already measured instead of computing a second one.

`test/architecture/design_system_import_test.dart` reads both files and fails when the values below stop agreeing
with them.

---

## Colour

### The rule

**An action belongs to the product; the room belongs to the palette.** Three palettes ship, and the brand group is
the same value in all three — `classic`, `nature` and `sunset` differ in their page, their edges, their quiet text
and their own accent. `classic` is the design system itself, token for token.

**`ColorScheme.surface` is `--background`, not `--surface`.** Material 3 has no `background` role: `surface` *is*
the page, and the web's `--surface` is a card, which belongs on `surfaceContainer*`. Read the other way round the
action colour sits at 2.80:1 on the page instead of 3.08:1.

**`--text-inverse` is the ink of `--surface-inverse`, and of nothing else.** A filled brand button's label is white
in both scopes, which is what the website itself paints — `color: #fff` as a literal at all ten of its filled brand
buttons, with no dark override.

### The brand group — the same in all three palettes

`lib/shared/design_system/theme/theme_colors.dart:44-58`

| role | web token | light | dark |
|---|---|---|---|
| `primary`, `surfaceTint` | `--action-primary` | `#4F46E5` | `#4F46E5` |
| `onPrimary` | white, as the website paints it | `#FFFFFF` | `#FFFFFF` |
| `primaryContainer` | `--surface-brand` | `#EEF2FF` | `#252163` |
| `onPrimaryContainer` | `--text-brand` | `#4338CA` | `#C7D2FE` |

`onPrimaryContainer` is also **the colour of brand-coloured text**, because Material has no role for it and the
system does. Every label that used to be `primary` carries it: the SQL keyword in the editor
(`lib/features/sql_editor/presentation/widgets/highlighting_text_controller.dart:48`) and in the source viewer
(`lib/features/object_browser/presentation/widgets/object_source_view.dart:254`), the quiet buttons and the
selected tab (`lib/shared/design_system/theme/app_theme.dart:114-140` — the tab bar, the outlined button and the
text button, in that order), and four labels across the app.

### The status group — also shared, and one rule covers all four

The colour is `--<kind>-text`, what sits on it is the scope's `--text-inverse`, the quiet pair is `--<kind>-bg`
with `--<kind>-text` on it. It has to be the `-text` member of each web triplet because this app paints *text*
with these roles at least as often as it fills with them.

`--action-destructive` is deliberately unmapped. It is the web's destructive *button*, and on the dark page it is
4.01:1, which fails the text this app paints with `ColorScheme.error`.

| role | file | light | dark |
|---|---|---|---|
| `error`, `onErrorContainer` | `lib/shared/design_system/theme/theme_colors.dart:64-65` | `#B91C1C` | `#FCA5A5` |
| `errorContainer` | `lib/shared/design_system/theme/theme_colors.dart:66-67` | `#FEF2F2` | `#3A0F13` |
| `onError` | `lib/shared/design_system/theme/theme_colors.dart:70-71` | `#FFFFFF` | `#0B0D18` |
| `success`, `onSuccessContainer` | `lib/shared/design_system/theme/semantic_colors.dart:50,53` / `:66,69` | `#047857` | `#6EE7B7` |
| `successContainer` | `lib/shared/design_system/theme/semantic_colors.dart:52` / `:68` | `#ECFDF5` | `#052E21` |
| `warning`, `onWarningContainer` | `lib/shared/design_system/theme/semantic_colors.dart:54,57` / `:70,73` | `#B45309` | `#FCD34D` |
| `warningContainer` | `lib/shared/design_system/theme/semantic_colors.dart:56` / `:72` | `#FFFBEB` | `#33220A` |
| `info`, `onInfoContainer` | `lib/shared/design_system/theme/semantic_colors.dart:58,61` / `:74,77` | `#1D4ED8` | `#93C5FD` |
| `infoContainer` | `lib/shared/design_system/theme/semantic_colors.dart:60` / `:76` | `#EFF6FF` | `#0D1F3D` |
| `onSuccess`, `onWarning`, `onInfo` | `lib/shared/design_system/theme/semantic_colors.dart:51,55,59` / `:67,71,75` | `#FFFFFF` | `#0B0D18` |

Where a row cites several lines, the first group is the light scope and the group after the slash is the dark one,
in the same file.

### `classic` — the design system, token for token

`lib/shared/design_system/theme/theme_colors.dart:95-129` (light) and
`lib/shared/design_system/theme/theme_colors.dart:133-166` (dark). The role on each line
appears in the same order in both.

| role | light | dark | web token |
|---|---|---|---|
| `primary` | `#4F46E5` | `#4F46E5` | `--action-primary` |
| `onPrimary` | `#FFFFFF` | `#FFFFFF` | white |
| `primaryContainer` | `#EEF2FF` | `#252163` | `--surface-brand` |
| `onPrimaryContainer` | `#4338CA` | `#C7D2FE` | `--text-brand` |
| `secondary` | `#4A5069` | `#A8B0CC` | `--text-secondary` |
| `onSecondary` | `#FFFFFF` | `#0B0D18` | `--text-inverse` |
| `secondaryContainer` | `#F1F3F9` | `#1B2038` | `--action-tertiary` |
| `onSecondaryContainer` | `#0E1020` | `#F2F4FB` | `--text-primary` |
| `tertiary` | `#6C728A` | `#7F87A7` | `--text-tertiary`, **lifted** |
| `onTertiary` | `#FFFFFF` | `#0B0D18` | `--text-inverse` |
| `tertiaryContainer` | `#F1F3F9` | `#1B2038` | `--action-tertiary` |
| `onTertiaryContainer` | `#0E1020` | `#F2F4FB` | `--text-primary` |
| `error` | `#B91C1C` | `#FCA5A5` | `--error-text` |
| `onError` | `#FFFFFF` | `#0B0D18` | `--text-inverse` |
| `errorContainer` | `#FEF2F2` | `#3A0F13` | `--error-bg` |
| `onErrorContainer` | `#B91C1C` | `#FCA5A5` | `--error-text` |
| `surface` | `#FFFFFF` | `#0B0D18` | `--background` |
| `onSurface` | `#0E1020` | `#F2F4FB` | `--text-primary` |
| `surfaceContainerHighest` | `#F1F3F9` | `#232842` | `--surface-hover` |
| `onSurfaceVariant` | `#4A5069` | `#A8B0CC` | `--text-secondary` |
| `outline` | `#868CA4` | `#6C7289` | `--border-strong`, **lifted** |
| `outlineVariant` | `#B5BBCF` | `#3C4057` | `--border`, **lifted** |
| `inverseSurface` | `#0B0D18` | `#FFFFFF` | `--surface-inverse` |
| `onInverseSurface` | `#FFFFFF` | `#0B0D18` | `--text-inverse` |
| `inversePrimary` | `#C7D2FE` | `#4338CA` | `--text-brand`, opposite scope |
| `surfaceTint` | `#4F46E5` | `#4F46E5` | `--action-primary` |

`shadow` and `scrim` are `#000000` in both, as Material expects.

### `nature` and `sunset` keep their own neutrals

`lib/shared/design_system/theme/theme_colors.dart:175-208` (nature light),
`lib/shared/design_system/theme/theme_colors.dart:212-245` (nature dark),
`lib/shared/design_system/theme/theme_colors.dart:254-287` (sunset light) and
`lib/shared/design_system/theme/theme_colors.dart:291-324` (sunset dark). Each is a scope on its own, cited the
same way `classic` is, because a reviewer reads one scheme at a time and a range that spans two of them points at
neither. They take the brand group and the status group and
nothing else: their page, their edges, their quiet text and their accent — sage green `#5F7A64` / `#8BA68F` and
orange `#C2410C` / `#FB923C` — are what these two palettes *are*. Pinned in both directions by the import guard,
because three palettes that differ only in the name of their action colour are one palette with three names.

In `nature` light the accent and the quiet text used to be the same literal, and they are not any more. `#5F7A64`
read at 4.62:1 on the page and 4.24:1 on a card, so the quiet text moved one step along the sage ramp to `#5B7560`
and the accent stayed where it is (#386). The palette now carries two greens on purpose: the one it is named for,
and the one its secondary text can be read in.

### The five deviations

Each is a web value this app cannot paint where it paints it. The rule applied: **start at the web value, walk the
web's own `--neutral-*` ramp away from the ground the role is painted on, and stop at the first 8-bit point that
clears the floor** — so the value stays inside the system and as close to the web's as the floor allows. For most
roles that ground is the page. For `outline` it is `surfaceContainerHighest`, because the one place a border meets
a filled box is the edge of a container, and the `at` column below still reports the page so the two rows stay
comparable with the rest. `Color.lerp` returns floating-point
channels, and three of these fell back under their floor when written as a literal, so the quantised value is what
is checked.

| role | scope | web token | web | taken | at | why |
|---|---|---|---|---|---|---|
| `tertiary` | light | `--text-tertiary` `#7B8199` | 3.86 | `#6C728A` | 4.76 | the **website's own lift**, not this app's |
| `tertiary` | dark | `--text-tertiary` `#767E9E` | 4.84 | `#7F87A7` | 5.46 | the website's own lift |
| `outline` | light | `--border-strong` `#CDD2E0` | 1.51 | `#868CA4` | 3.33 | along `--neutral-400`→`500` until 3:1 on `surfaceContainerHighest` |
| `outline` | dark | `--border-strong` `#3A416A` | 1.98 | `#6C7289` | 4.06 | along `--neutral-700`→`600` until 3:1 on `surfaceContainerHighest` |
| `outlineVariant` | light | `--border` `#E4E7EF` | 1.24 | `#B5BBCF` | 1.91 | 56% `--neutral-300`→`400` |
| `outlineVariant` | dark | `--border` `#262B45` | 1.40 | `#3C4057` | 1.90 | 69% `--neutral-800`→`700` |

The two `tertiary` rows are **not** this app's deviation. The website met the same collision and recorded its
answer with its own measurement tool, under a method stricter than this app's — "the MINIMUM lift that clears 4.5:1
on the darkest/lightest surface the token is actually painted on". This app takes that value, because two consumers
of one design system showing two different greys for one token is what a shared system exists to prevent.

The `outline` rows **are** this app's own, and have to be: the website's only colour test holds 1.4.3 on three text
tokens and 3:1 on five gradient pairs, and no floor at all on `--border`. There was no value there to take.

### The floors, measured

`test/shared/design_system/theme/palette_contrast_test.dart`. Fifteen pairs, each of the six schemes.

* **4.5:1** — WCAG 2.1 AA for body text (1.4.3), for any colour this app paints text with.
* **3:1** — WCAG 2.1 AA for the boundary of a user interface component (1.4.11).
* **1.9:1** — this repository's own, not WCAG's. `outlineVariant` is Material's *decorative* divider, which 1.4.11
  exempts; a divider at 1.04:1 draws nothing, and a separator that separates nothing is a bug whatever the standard
  says.

| pair | floor | classic dark | classic light | nature dark | nature light | sunset dark | sunset light |
|---|---|---|---|---|---|---|---|
| `outline` on `surface` | 3.0 | 4.06 | 3.33 | 4.32 | 3.28 | 3.94 | 3.16 |
| `outlineVariant` on `surface` | 1.9 | 1.90 | 1.91 | 1.91 | 1.90 | 1.93 | 1.90 |
| `tertiary` on `surface` | 4.5 | 5.46 | 4.76 | 4.52 | 4.54 | 4.50 | 4.53 |
| `onSurfaceVariant` on `surface` | 4.5 | 8.98 | 7.95 | 7.28 | 4.95 | 7.83 | 4.72 |
| `onSurface` on `surface` | 4.5 | 17.61 | 18.86 | 17.99 | 18.87 | 18.92 | 18.92 |
| `onPrimary` on `primary` | 4.5 | 6.29 | 6.29 | 6.29 | 6.29 | 6.29 | 6.29 |
| `onSecondary` on `secondary` | 4.5 | 8.98 | 7.95 | 7.28 | 4.71 | 8.73 | 5.18 |
| `onError` on `error` | 4.5 | 10.20 | 6.47 | 10.20 | 6.47 | 10.20 | 6.47 |
| `onPrimaryContainer` on `primaryContainer` | 4.5 | 9.54 | 7.07 | 9.54 | 7.07 | 9.54 | 7.07 |
| `onSecondaryContainer` on `secondaryContainer` | 4.5 | 14.58 | 17.00 | 12.15 | 14.63 | 11.21 | 8.83 |
| `onTertiaryContainer` on `tertiaryContainer` | 4.5 | 14.58 | 17.00 | 12.15 | 12.15 | 13.90 | 13.90 |
| `onErrorContainer` on `errorContainer` | 4.5 | 8.80 | 5.91 | 8.80 | 5.91 | 8.80 | 5.91 |
| `primary` on `surface` | 3.0 | 3.08 | 6.29 | 3.06 | 6.17 | 3.14 | 6.02 |
| `error` on `surface` | 4.5 | 10.20 | 6.47 | 10.14 | 6.35 | 10.41 | 6.19 |
| `inversePrimary` on `inverseSurface` | 4.5 | 7.90 | 12.98 | 7.39 | 11.40 | 7.57 | 11.72 |

Six more guards measure what this table cannot see, and each exists because something was shipping under a floor
with nothing looking at it:

* `semantic_contrast_test.dart` — `success`, `warning` and `info` live in a `ThemeExtension`, not a `ColorScheme`.
* `material_default_contrast_test.dart` — the labels Flutter's own M3 defaults colour, which this app never sets.
* `architecture/snack_bar_ink_test.dart` — a `SnackBar` that replaces its background must replace its ink.
* `surface_ladder_test.dart` — a container role has to be a colour of its own; one that resolves to the page means
  a widget asking for a fill draws nothing.
* `container_contrast_test.dart` — the table above measures a role against the page, and a role is also painted on
  a card. It measures the pairs the code paints, read from the call sites rather than crossed.
* `architecture/quiet_alpha_test.dart` — a fade is written where the text is, not in the scheme, so a role can clear
  its floor everywhere and the text drawn with 60% of it still be unreadable. It reads the alpha out of the source.

### What a reviewer should know is *not* covered

The three gaps this section used to name were #386, and they are closed: the container roles are colours of their
own, quiet text and card edges clear their floor on a container, and nothing fades a quiet role any more. The last
three guards above are what closed them, and they are what keeps them closed.

What no guard here measures is text on a background that is not a scheme role at all — a widget that hard-codes a
colour and paints on it. `design_token_test.dart` catches the literal under `lib/features/`; nothing measures the
pair. Two places fade a quiet role on purpose and are exempt by name in `quiet_alpha_test.dart`, each with its
reason: the dev console, which no release build carries, and the theme dialog's preview tile, whose bars stand for
text inside a miniature of a theme rather than being text.

---

## Type

`lib/shared/design_system/tokens/app_typography.dart` — the bare line numbers in the last column are that file.
The system has ten heading levels against Material's nine;
`display-xxl` (72 px of marketing headline) is the one left out. Tracking is written in `em` by the system and
multiplied by the size here, because Flutter wants logical pixels.

| Material level | web | size | line | tracking | weight | line |
|---|---|---|---|---|---|---|
| `displayLarge` | `display-xl` | 36 | 1.05 | −0.028em | 700 | `:33` |
| `displayMedium` | `display-l` | 32 | 1.06 | −0.026em | 700 | `:35` |
| `displaySmall` | `display-m` | 30 | 1.08 | −0.024em | 700 | `:37` |
| `headlineLarge` | `h1` | 28 | 1.10 | −0.022em | 600 | `:39` |
| `headlineMedium` | `h2` | 24 | 1.15 | −0.020em | 600 | `:41` |
| `headlineSmall` | `h3` | 21 | 1.20 | −0.016em | 600 | `:43` |
| `titleLarge` | `h4` | 19 | 1.25 | −0.012em | 600 | `:45` |
| `titleMedium` | `h5` | 17 | 1.30 | −0.008em | 600 | `:47` |
| `titleSmall` | `h6` | 16 | 1.40 | — | 600 | `:49` |
| `bodyLarge` | `body-m` | 16 | 1.60 | — | 400 | `:51` |
| `bodyMedium` | `body-s` | 14 | 1.55 | — | 400 | `:53` |
| `bodySmall` | `body-xs` | 12 | 1.50 | — | 400 | `:55` |
| `labelLarge` | `label` | 14 | 1.30 | — | 500 | `:57` |
| `labelMedium` | `caption` | 12 | 1.40 | — | 500 | `:59` |
| `labelSmall` | `overline` | 11 | — | — | 500 | `:64` |

**`labelSmall` takes its size only.** The system tracks `overline` open at 0.1em, but ties that tracking to the
ALL-CAPS eyebrow treatment, and this app's `labelSmall` call sites are ordinary small labels. Taking it anyway
would widen every one of them by 0.6 px a character for a treatment none of them use.

Families: `Plus Jakarta Sans` (`:9`) and `JetBrains Mono` (`:13`). The system's `fonts.css` sets Geist; the website
overrides it with this pair and this app followed in #349, so the app matches what the brand ships rather than what
that file says.

---

## Space, shape and size

| scale | values | file |
|---|---|---|
| spacing | 4, 8, 12, 16, 24, 32, 40, 48, 64 | `lib/shared/design_system/tokens/app_spacing.dart:9-17` |
| form widths | 200, 400, 600, 800 | `lib/shared/design_system/tokens/app_spacing.dart:20-23` |
| radius | 4, 6, 8, 12, pill 999 | `lib/shared/design_system/tokens/app_radius.dart:5-13` |
| button height | 32, 36, 40 | `lib/shared/design_system/tokens/app_sizes.dart:6-8` |
| icon | 16, 18, 20 | `lib/shared/design_system/tokens/app_sizes.dart:11-13` |
| avatar | 32, 40, 56 | `lib/shared/design_system/tokens/app_sizes.dart:16-18` |
| input height | 32, 36, 40 | `lib/shared/design_system/tokens/app_sizes.dart:21-23` |
| breakpoints | 768, 1024, 1280 | `lib/shared/design_system/tokens/app_breakpoints.dart:6-10` |

The app's spacing and radius scales each sit **inside** the web's, so adopting the web scale adds steps and
invalidates no layout. The web also has 2, 20 and the steps above 64, and radii 16 (modal or sheet) and 24
(section media).

**The tap target deviates, deliberately.** `AppSizes.minTapTarget` is 48
(`lib/shared/design_system/tokens/app_sizes.dart:31`) against the web's `--touch-target-min` of 44. The owner ruled the app keeps 48: 44 is the floor Apple asks for, this app ships
on Android, and #373 measured what 48 costs in a dense list and answered it with `minDenseTarget` of 24
(`:38`) rather than by lowering the floor. Pinned in both directions — following the web here would be a
regression, not an import.

---

## Motion

`lib/shared/design_system/tokens/app_durations.dart`

| token | value | line | web |
|---|---|---|---|
| `instant` | 80ms | `:12` | `--duration-instant` |
| `fast` | 150ms | `:15` | `--duration-fast` |
| `normal` | 240ms | `:18` | `--duration-normal` |
| `slow` | 360ms | `:21` | `--duration-slow` |
| `media` | 400ms | `:24` | `--duration-media` |
| `easeOut` | `Cubic(0.22, 1, 0.36, 1)` | `:32` | `--ease-out` |
| `easeIn` | `Cubic(0.55, 0, 1, 0.45)` | `:35` | `--ease-in` |
| `easeInOut` | `Cubic(0.65, 0, 0.35, 1)` | `:38` | `--ease-in-out` |

`--ease-spring` is deliberately absent: it overshoots at 1.56, which `Cubic` can express but nothing in this app
asks for, and an unused curve is a value nobody is holding to anything. It arrives with its first caller.

---

## What is not taken from the design system at all

* **Components.** The website ported none of them — *"The needed set turned out to be empty"* — and neither does
  this app. The 13 Flutter components under `lib/shared/design_system/components/` stay; only values and rules
  cross over.
* **The console ramp and the gradient headline stops** in the other consumer's `a11y.css`. The console ramp belongs
  to the website's terminal mock-up and has no counterpart here; this app paints no gradient text.
* **Elevation.** `tokens/elevation.css` is vendored and unread: this app turns the Material elevation tint off on
  every component theme (`lib/shared/design_system/theme/app_theme.dart`) and draws depth with a border instead.

## Goldens, when a token changes

A token change redraws everything, so the decision is not *whether* the baselines move but *where* they are drawn.

**The decision: every baseline is regenerated, and it is regenerated on CI, never on a maintainer's machine.** A
token change is expected to move all 19 `*_golden_test.dart` files at once; a change that moves none of them is the
signal that the token has no caller, and that is worth reading rather than celebrating. Nothing about a token
change is allowed to weaken, skip or re-scope a golden so the images can stay.

It has to be CI because the images are host-dependent: measured on this repository, the component goldens deviate
by 0.09–0.15% between a maintainer's machine and the runner even with the pinned toolchain, which is why a
maintainer sees golden failures against an untouched `main`. A baseline drawn locally is therefore a baseline that
fails for everyone else. The route is in [`docs/testing-architecture.md`](testing-architecture.md): a temporary workflow job runs
`flutter test --tags golden --update-goldens`, uploads `**/goldens/ci/*.png`, the artifact is downloaded, the
images that differ are committed, and the job is deleted in the same pull request.

That is how #384's and #385's baselines were produced, and it is what the next token change does too.

## The guards, by what they hold

| file | holds |
|---|---|
| `test/architecture/design_system_import_test.dart` | every value on this page against the vendored CSS |
| `test/shared/design_system/theme/palette_contrast_test.dart` | the fifteen pairs of all six schemes |
| `test/shared/design_system/theme/semantic_contrast_test.dart` | the status colours of all six |
| `test/shared/design_system/theme/material_default_contrast_test.dart` | the labels Material colours |
| `test/architecture/snack_bar_ink_test.dart` | a snack bar's background and its ink move together |
| `test/architecture/arb_translations_test.dart` | no palette describes itself by a ramp it no longer uses |
| `test/architecture/design_token_test.dart` | no raw value outside `lib/shared/design_system/` |
| `test/architecture/design_system_doc_test.dart` | this page: its citations, its colours and its numbers |
| the 19 `*_golden_test.dart` files | what all of it draws |
