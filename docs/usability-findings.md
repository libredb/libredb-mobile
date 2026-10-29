# A usability finding, and what counts as one

The record format of M16's usage layer (#285). The personas of its roster — five, or six once the epic's "Q&A"
ambiguity is answered — use this app against their jobs to be done and record what they hit; this page is the only
shape they may record it in, and a report that does not fit it is not consolidated.

**Fixed keys, because the consolidation is a comparison.** The review layer merges duplicates, drops what no persona
hit, and traces every proposed change back to the findings that produced it. Free prose makes each of those three a
judgement call: two personas describing the same wall in different words look like two findings, and one persona's
aside looks like a second opinion. A block with the same keys in the same order makes the duplicate visible without
reading for intent.

**This page does not say what is wrong with the app.** It says what a finding is allowed to be. Nothing here ranks a
screen, and nothing here is a decision: the accept, reject or defer belongs to the product owner agent, further down
the epic.

---

## The block

One finding is one block. Every key is required, in this order, and no key is added:

```text
persona:       dba-on-call
job:           dba-on-call/2
step:          4
step_action:   Opened the locked table from the connection the alert named.
screen:        ApplicationRoutesConstants.browseRows
target:        lib/main/main_local.dart
environment:   local
session:       studio
palette:       classic
brightness:    dark
locale:        tr
device:        Android emulator, API 34, 1080x2340, textScaleFactor 1.0
commit:        0916ef5
kind:          flow
expected:      The rows of the table, or a line saying why they cannot be read.
happened:      A spinner for 12 s, then the empty state, with nothing saying the read had failed.
severity:      S3
evidence:      run-2026-10-28/dba-on-call-2-04-browse-rows.png
```

| key | what it holds | read from |
|---|---|---|
| `persona` | the persona's id, one of the roster the epic fixes | `docs/usability-jobs.md` |
| `job` | the job's id, `<persona>/<n>`, never a prose retelling | `docs/usability-jobs.md` |
| `step` | the ordinal of the step inside that job, from 1 | the job's own steps |
| `step_action` | one line, what the persona did at that step — an action, not a feeling | the run |
| `screen` | a constant of `ApplicationRoutesConstants`, by name | `lib/app/router/app_routes_constants.dart` |
| `target` | the entry point the build was made from | `lib/main/` |
| `environment` | `mock`, `local` or `prod` | `Environment` in `lib/infrastructure/config/environment.dart` |
| `session` | `studio` or `platform` | `SessionTarget` in `lib/shared/models/session_target.dart` |
| `palette` | `classic`, `nature` or `sunset` | `AppThemePalette` in `lib/shared/design_system/theme/app_theme_palette.dart` |
| `brightness` | `light` or `dark` | the device setting at the step |
| `locale` | `en` or `tr` | `lib/l10n/intl_en.arb`, `lib/l10n/intl_tr.arb` |
| `device` | the device or emulator, its API level, its resolution and its text scale | the run |
| `kind` | `flow` or `visual` | the finding |
| `expected` | what the step was supposed to produce, in the job's terms | the job |
| `happened` | what it produced instead, with the numbers the run measured | the run |
| `severity` | `S1`, `S2`, `S3` or `S4`, read off the job below | this page |
| `evidence` | the screenshot of the step, as a path in the run's directory | the run |

A `visual` finding carries two keys more, and only a `visual` finding may:

```text
kind:          visual
token:         AppSizes.minTapTarget
cites:         `docs/design-system.md:277` — "The tap target deviates, deliberately."
```

### Why the screen is a route constant and not a screen name

A finding has to name a screen the implementer can open. A prose name cannot be opened: "the table page" is
`browseObjects`, `browseRows` and `browseDetail`, three different pages. A location cannot be pasted either, because
every page under Browse is a relative fragment of its parent — `browseRows` is `:connectionId/rows/:kind`, which
names nothing on its own (`lib/app/router/app_routes_constants.dart`). The constant's name is unambiguous and
greppable, so `screen` carries that and nothing else.

Two shapes are not routes and are written as the route they sit over plus the widget's class: a sheet or a dialog
(`RowDetailSheet`, `ConnectionSwitcherSheet`, `ThemeSelectionDialog`), and a banner or a gate drawn above the shell.
A finding on a sheet whose route is wrong sends the implementer to the page behind it.

### Why the build is eight keys

Each of the eight changes what the persona saw, and each is a value the run already knows:

* **`target` and `environment`** decide where the data came from. In `mock` the answers are the recorded fixtures of
  `assets/mock/`, so a finding about *what* the data says is a finding about a fixture, not about the app; in `local`
  and `prod` it came from a server.
* **`session`** decides which shell was on screen: the two targets have different tabs, and only a Platform session
  sees the Platform ones. It also decides whether the finding was reachable at all — a `local` or `prod` build needs
  `PLATFORM_API_URL` set to show Platform mode, while the mock build answers Platform from `assets/mock/GET_v1_*`.
  A Studio finding naming a Platform screen is therefore mislabelled, not a finding.
* **`palette` and `brightness`** are six colour schemes, not two. Three palettes ship and the brand group is the same
  value in all three — `docs/design-system.md:33` — "An action belongs to the product; the room belongs to the
  palette." A visual finding that does not say which of the six it saw cannot be reproduced: #386's faded text was
  unfixable at any alpha in two of the six, `nature` light and `sunset` light, and tunable in the other four
  (`test/architecture/quiet_alpha_test.dart`).
* **`locale`** decides whether the finding is about the English or the Turkish text. Both ship.
* **`device`** carries the text scale, because the layout defect that only appears at a large scale is a different
  finding from the one at 1.0.
* **`commit`** is what makes two runs comparable. The epic expects a run before M15 (#284) merges and possibly
  another after; without the commit the two runs are one undated pile.

---

## Severity is read off the job, not off feeling

| level | the job | what it means |
|---|---|---|
| **S1** | did not finish | the persona stopped, or finished by leaving the app for something outside it |
| **S2** | finished, and the takeaway was wrong | the app's own presentation made the person believe something untrue |
| **S3** | finished, by a route the persona did not intend | it took steps the job did not ask for, or a detour they found by luck |
| **S4** | finished, by the intended route, and a step cost a re-read | the step worked once it was understood, after being read twice |

The scale is ordered by **how much of the job survived**, not by how bad the consequence would be, because the
consequence depends on what the person does next and no run can see that. S1 keeps nothing; S2 keeps the outcome and
corrupts it; S3 keeps the outcome and loses the route; S4 keeps both and costs attention.

Reading it off the job is what makes two personas' severities comparable. The level is decided by the job's own
"what would count as having done it", which `docs/usability-jobs.md` writes down per job as its `done:` and its
`takeaway:` — not by how the step felt.
A persona may not raise a level because something annoyed it, and may not lower one because it recovered.

**S2 is about the app's presentation, not the database's answer.** A masked column read as the value, a truncated
result read as the whole table, a stale list read as current: those are S2. A value Studio returned wrong is a
backend defect and leaves this format — the app showed what it was given.

### Why there is nothing above S1

An S0 would have to mean worse than the job failing, and every candidate for it belongs to another page: a crash or
an unhandled error to `docs/crash-reporting.md`, a leak or a capture of data to `docs/security.md`. Ranking those
here would make them compete with usability findings for the review layer's attention, and a run that can report a
crash will report crashes — which is what the epic puts out of scope. The top of this scale is therefore the worst
thing that is still a usability outcome.

### Why there is nothing below S4

An S5 would be a finding whose step cost nothing, which is a preference. The format cannot hold one: `step_action`
and `evidence` are required, and "it would look better with more space" has neither. Keeping a level for it would
also defeat the consolidation, since a preference recorded once per persona reads as five personas agreeing.

---

## Evidence

`evidence` is a screenshot of the step, in the run's own directory, named
`<run>/<persona>-<job>-<step>-<screen>.png`. It stays out of the repository: an agent's working directories are
git-ignored and `test/architecture/agent_scratch_test.dart` fails a tracked file in one, and the walkthroughs of
`docs/studio.md` and `docs/platform.md` already keep the measurement and delete the images. What reaches the
repository is the finding; the image is what the consolidation reads while it still has the run.

**A prod build cannot screenshot the screens that matter most.** Screen capture protection is on by default in a
prod build, and on Android `FLAG_SECURE` makes the screenshot black — on exactly the screens that show data: a
result, a row's detail, a script's answer, a key's value, an object's source and the Platform audit log
(`docs/security.md`, "Screen capture protection"). A run that needs evidence of those builds with
`--dart-define=SCREEN_CAPTURE_PROTECTION=false`, as the M12-P full-system check did for all three of its builds
(`docs/platform.md`, "Full-system check"). A finding whose `evidence` is a black image is a finding with no
evidence, and the rule below discards it.

---

## What is discarded, and where it goes instead

### A class a guard already measures is a test gap, not a usability finding

`test/architecture/` holds 43 guards, and some of them measure, repository-wide, exactly what a persona would
otherwise report as a finding. When a guard measures the class and is green, the finding is about the guard's reach —
file it against the guard, not as a usability finding.

| what the persona saw | the guard that measures it | what the finding is instead |
|---|---|---|
| English text in a Turkish run | `test/architecture/ui_text_localized_test.dart` | a gap in that guard's shapes, which it names |
| a control that does not answer a finger | `test/architecture/touch_feedback_test.dart` | a widget outside its reach, or a missing press test |
| an off-token colour, radius or spacing | `test/architecture/design_token_test.dart` | a budget entry that outlived its debt |
| unreadable text faded by an alpha | `test/architecture/quiet_alpha_test.dart` | a new fade, or an exemption to re-argue |
| a snack bar whose text is unreadable | `test/architecture/snack_bar_ink_test.dart` | a background set without its ink |
| a role under its contrast floor | `test/shared/design_system/theme/palette_contrast_test.dart` | a pair the fifteen do not cover |
| a status colour under its floor | `test/shared/design_system/theme/semantic_contrast_test.dart` | a pair it does not cross |
| a role unreadable on a card | `test/shared/design_system/theme/container_contrast_test.dart` | a call site it does not read |
| text Flutter's own defaults colour | `test/shared/design_system/theme/material_default_contrast_test.dart` | a widget it does not pump |
| a card whose fill is the page | `test/shared/design_system/theme/surface_ladder_test.dart` | a role it does not list |

**Three classes are measured per screen, not repository-wide, so the same observation on another screen is a real
finding.** The tap target is measured on the login page
(`test/features/auth/presentation/pages/login_tap_target_test.dart`), and a screen-reader label on the login page, the
introduction and a result row (`test/features/auth/presentation/pages/login_screen_a11y_test.dart`,
`test/features/onboarding/presentation/pages/onboarding_page_a11y_test.dart`,
`test/shared/widgets/result_view/result_row_a11y_test.dart`). Text scale is pumped in fourteen test files and in no
guard. On a screen with no such test, the finding stands — and it asks for a test as well as a fix.

### A complaint that the token itself is wrong goes to #283

The epic evaluates the app against the design system and asks for screen changes, not token changes. A finding that
the spacing scale is too coarse, that the indigo is too dark or that the tap target should be 44 is a conflict for
M14 (#283), recorded there, and it does not travel forward as an implementation. The tap target in particular is
pinned in both directions and against the web — `docs/design-system.md:277` — "The tap target deviates,
deliberately." — so a finding that asks for the web's 44 is answered, not open.

### A finding with no step or no evidence is not a finding

`step` and `step_action` tie the finding to a job, which is what makes severity readable and the duplicate visible.
`evidence` is what makes it checkable by someone who was not there. A block missing either is dropped before
consolidation, whatever it says: without them it is an opinion about the app, and the epic's whole point is that an
opinion is not a finding. The same goes for a `visual` finding with no `cites`, which the design system page says in
its own words — `docs/design-system.md:6` — "A finding that cites nothing is not a finding: it is taste."

### A finding authored by a review-layer agent is discarded

The epic's binding ruling: the usage layer and the review layer are two layers, and the evaluating roles — UX,
Designer, product owner, Flutter developer — never open the app as users. A finding carrying one of their names is
discarded without being read, because their opinion is already due to arrive as a review conclusion, and arriving
twice makes the repetition look like corroboration from an independent source. The discard is not a judgement about
the content; it is what keeps the consolidation's input one layer deep.

---

## Out of scope, and where each goes

| subject | where it goes |
|---|---|
| a crash, a hang, an unhandled error | `docs/crash-reporting.md` |
| anything about secrets, tokens, pinning, screen capture or the idle timeout | `docs/security.md` |
| changing a token, a colour or the design system | M14 (#283), as a conflict |
| relaxing or deleting a guard to let a change through | the owner, who decides; never the pull request |
| a wrong value or a wrong error from Studio or Platform | the backend's own contract (`docs/architecture.md`, `docs/platform.md`) |
| performance | **no document owns it** — see below |

**Performance has no owner, and this page says so rather than pretending otherwise.** No page in `docs/` states a
frame, latency or memory budget. The only performance number the repository holds is the Sentry trace sample rate of
`0.2` (`lib/app/bootstrap/sentry_start.dart`), declared to Play as diagnostics in `docs/release.md` — a sampling
rate, not a budget. So a persona who finds a screen slow has nowhere to file it today. It is recorded as a note on
the run and named to the owner, and it is not written as a finding, because a severity read off the job would make
"slow" compete with "could not finish" on a scale that was never measured for it.

---

## The guards that hold this page

| file | holds |
|---|---|
| `test/architecture/usability_doc_test.dart` | every `test/` path above, every citation above, and the guard count |
| `test/architecture/usability_jobs_doc_test.dart` | `docs/usability-jobs.md`, the jobs this format's `persona`, `job`, `step` and `severity` are read off |
| `test/architecture/design_system_doc_test.dart` | that the page a citation lands on still matches the code |
| `test/architecture/testing_doc_test.dart` | that every guard, this one included, is named in `docs/testing-architecture.md` |

The citations are checked the way `test/architecture/release_docs_test.dart` checks the labels `docs/release.md`
quotes: the quoted sentence has to still be there, at the line given. A citation that has slid down the page is worse
than none, because it sends a reviewer to the wrong sentence while still looking right.
