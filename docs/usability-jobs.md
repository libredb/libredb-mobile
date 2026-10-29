# The jobs the personas do

The usage layer of M16 (#285), written out: who is run as a user, what each of them is trying to find out, where they
start, what they do, and what counts as having done it. The record format of what they hit is
`docs/usability-findings.md`; this page is the other half of it, and the two are one format in two files. That page
reads `persona`, `job`, `step` and `severity` off this one, so every job here carries a persona id it may be written
with and numbered steps a `step` can point into.

**This page is the whole brief.** The run that executes it (the third child of #285) has nobody to ask: it gets a
build, a stage, a job and its steps, and anything the page leaves out is a question that cannot be answered mid-run.
So every job names the build it runs, the screen it starts on, the steps in order, and a `done:` that can be read off
the screen. A job whose `done:` cannot be checked from the screen is not a job; it was rewritten until it could.

**This page does not say what is wrong with the app, and it is not a test plan.** It says what a person came to do.
Nothing here asserts that a step works or fails today, and nothing here is a feature tour: a persona is not asked to
"explore the object browser", it is asked how big the table the alert named is. A step list is the route the job's
own question implies, not a script to be ticked off — a persona that answers the question by another route has
finished the job, and the finding format has a severity for exactly that.

---

## What a job is

One job is one block of keys, then its steps. Every key is required, in this order, and no key is added:

```text
job:           dba-on-call/1
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.connectionList — signed in, nothing starred, no connection open
asks:          Whether the connection the alert named answers now, and what it is pointed at.
done:          The status line of that connection on ApplicationRoutesConstants.connectionList reads a latency, a
               reachable-without-health line or a failure, and its details sheet shows a host and a database.
takeaway:      One sentence the person can now say: the connection answered in so many ms, or it did not, and it
               points at that host and that database.
```

| key | what it holds | read from |
|---|---|---|
| `job` | the job's id, `<persona>/<n>`, the same id the heading carries | this page |
| `target` | the entry point the build is made from | `lib/main/` |
| `environment` | `mock`, `local` or `prod` | `Environment` in `lib/infrastructure/config/environment.dart` |
| `session` | `studio` or `platform` | `SessionTarget` in `lib/shared/models/session_target.dart` |
| `start` | the screen the job starts on, as a constant of `ApplicationRoutesConstants`, and the state it is in | `lib/app/router/app_routes_constants.dart` |
| `asks` | what the person is trying to learn or do, in their words, never a feature's name | this page |
| `done` | what is on screen when the job is finished, and on which screen | this page |
| `takeaway` | the sentence the person can say afterwards, which is what `S2` is read against | this page |

**Why `start` and `done` name a route constant.** The same reason the finding format gives for `screen`: a prose name
cannot be opened. "The table page" is `ApplicationRoutesConstants.browseObjects`,
`ApplicationRoutesConstants.browseRows` and `ApplicationRoutesConstants.browseDetail`, three different pages, and the
paths under Browse are relative fragments that name nothing on their own. A sheet or a dialog is written as the route
it sits over plus the widget's class, as the finding format writes it.

**Why `done` is read off the screen and not off the person.** "The analyst understood the result" cannot be checked
by anyone who was not there, so it cannot be a finish line; "the result area shows a stats line and, when Studio
bounded the result, the bounded notice" can. This is also what makes severity comparable across personas: the finding
format reads `S1` off whether the job finished, and a job whose finish is a feeling has no `S1`.

**Why `takeaway` is a key of its own.** `S2` is "finished, and the takeaway was wrong" — the app's own presentation
made the person believe something untrue. That level is unwritable unless the true sentence is written down in
advance, because afterwards every run believes its own reading. The takeaway is the sentence the job's answer is
supposed to be; if the screen left another one, the finding is `S2` however smoothly the steps went.

### How severity is read off a job

The scale and its four levels belong to `docs/usability-findings.md`. This page supplies what each level is read
against, per job, and the mapping is the same for all of them:

- **S1** — the job's `done:` is not on screen at the end, or it is only there because the person left the app.
- **S2** — `done:` is on screen, and the sentence the screen left is not the job's `takeaway:`.
- **S3** — `done:` is on screen and the takeaway holds, reached by steps other than the job's.
- **S4** — `done:` is on screen, the takeaway holds, the steps were the job's, and one of them had to be read twice.

No persona raises a level because a step annoyed it, and none lowers one because it recovered.

---

## The roster

Five personas, and all five are people who would use a mobile database client. The evaluating roles — UX, Designer,
product owner, Flutter developer — are not here and are never run as users, which is the binding ruling of #285: a
finding carrying one of their names is discarded by the finding format without being read.

| persona | who it is | why it reaches for a phone | session |
|---|---|---|---|
| `dba-on-call` | the database administrator carrying the pager | an alert arrived away from a desk, and the first question is whether the thing is reachable at all | `studio` |
| `data-analyst` | an analyst answering one question from the data | someone asked for one number, in a meeting or a corridor, and the laptop is shut | `studio` |
| `software-developer` | a developer debugging their own feature | the bug report names a table and a statement, and the shape of the data decides whether the bug is theirs | `studio` |
| `data-engineer` | an engineer watching a pipeline | the nightly load either landed or did not, and the check is a count and a key walk, not a console | `studio` |
| `platform-engineer` | a Platform admin governing access | access questions arrive as messages, and the answer is who holds which grant and what already ran | `platform` |

The `platform-engineer` is the only persona that sees the Platform shell, and it needs a build with
`PLATFORM_API_URL`; the others never leave the Studio shell.

### The sixth persona is not written here

#285 asks the owner to settle what **"Q&A test agent"** meant before the roster is fixed, and that question is not
settled yet. Both readings are live, and they are different work:

- **QA**, a testing role, belongs to the review layer or nowhere in this epic, and adds no persona here.
- **Q&A**, a person who arrives with a question and tries to answer it from the data, is a sixth persona with jobs of
  its own.

So the roster above is five, and this page says five rather than guessing at six. If the owner answers "Q&A", the
sixth persona is added to the roster table with two or three jobs in the same shape, and nothing already written
changes — the guard checks the roster table against the job ids, so adding a row without its jobs fails instead of
passing quietly.

---

## The stage every job runs against

One stage, so two runs are comparable and a job is reproducible: the local stack of
`tool/studio-dev/docker-compose.yml`, which `docs/studio.md` documents. It is the only stage in reach that has real
latency, real database errors, a connection marked production, a connection through a role that may only read, and a
Redis with enough keys to page through. The mock build answers from fixtures, so several jobs below could not fail in
it at all; the fixtures' own stage is named per job where it is the fallback.

```shell
docker compose -f tool/studio-dev/docker-compose.yml up -d --wait
tool/studio-dev/trust-android-emulator.sh
fvm flutter run --target lib/main/main_prod.dart --dart-define-from-file=tool/studio-dev/studio-dev.env \
  --dart-define=SCREEN_CAPTURE_PROTECTION=false
```

`SCREEN_CAPTURE_PROTECTION=false` is not optional: `docs/usability-findings.md` requires a screenshot per finding, and
a prod build blacks out exactly the screens that show data. A finding whose evidence is a black image is discarded.

**Sign-in** is through the stack's Keycloak; `docs/studio.md` names the users of the realm and their roles. No
password is written on this page, in a finding, or in a run's notes.

**What the stage holds**, from `tool/studio-dev/seed-connections.yaml`, `tool/studio-dev/postgres/seed.sql` and
`tool/studio-dev/redis/seed.redis`:

| connection | what a job uses it for |
|---|---|
| `Dev Postgres` | the database `app`: `public.customers`, `public.orders` with its index and foreign key, `public.order_items`, the view `sales.order_totals`, `sales.ledger` with 100 rows |
| `Dev Postgres server` | the same server with no database named, so Browse starts at the databases `app` and `archive` |
| `Dev Postgres (read-only role)` | the same database through a role that owns nothing, for which Studio reports no primary key and no foreign key |
| `Prod Postgres` | the same database, marked `production`, so the editor asks for the typed connection name before a write |
| `Dev Redis` | databases 0 and 1; database 1 holds 1,200 `user:NNNN` keys, so a walk takes several pages |

`public.customers` holds the columns `email` and `card_number`, which Studio masks — the job that reads a row is
written around that, because a masked value read as the value is the finding format's own example of `S2`.

**The axes of a pass.** One pass per job, with the palette `classic`, the phone's own light or dark setting and the
locale `en`; every finding records all of them anyway, so a second pass that changes exactly one axis stays
comparable. Three jobs are also run once in `tr`, because their `done:` is a sentence the app formats — a count, a
date or a plural — and those are where a translation breaks the sentence rather than the word: `data-analyst/3`,
`data-engineer/3` and `platform-engineer/1`. The run uses the app's own language setting, not the emulator's, so the
device stays one device.

**Nothing below writes data**, except `platform-engineer/2`, which is a grant on a disposable local install. No job
runs an `INSERT`, an `UPDATE` or a `DELETE` against a seeded database; the two jobs that reach a write confirmation
reach it and stop there, because what they are about is the confirmation, not the write.

---

## dba-on-call

### dba-on-call/1 — Is the database the alert named reachable, and what is it pointed at?

```text
job:           dba-on-call/1
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.connectionList — just signed in, nothing starred, no connection open
asks:          Whether Prod Postgres answers right now, how long it took, and which host and database the app would
               reach, before anyone is woken up.
done:          On ApplicationRoutesConstants.connectionList the status line of Prod Postgres reads a reachable line
               with its latency, a reachable-without-health line, or a check-failed line; its ConnectionDetailsSheet
               shows a host, a database and an environment; and Prod Postgres is listed under Favorites.
takeaway:      Prod Postgres answered in so many ms or did not answer, it points at that host and that database, and
               it is the production one of the five.
```

1. Find `Prod Postgres` in the list, among connections whose names differ by one word.
2. Start its check and wait for the status line to settle.
3. Read the status line: reachable with a latency, reachable without health data, or failed.
4. Open its details sheet and read the host, the database and the environment.
5. Star it, and confirm it is listed under Favorites for the next call.

The alert names a database, not a connection, and five connections point at the same server here. Telling them apart
from the list is part of the job, not noise around it.

### dba-on-call/2 — How big is the table the alert named, and is its key where I think?

```text
job:           dba-on-call/2
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.connectionList — signed in, Dev Postgres open from job 1's star
asks:          How many rows public.orders holds now, whether it has a primary key, and whether the column the alert
               blamed is indexed.
done:          ApplicationRoutesConstants.browseDetail shows the counted rows of orders, a number or a
               could-not-count line, its columns with a primary-key marker, and its indexes with a named index on
               the blamed column.
takeaway:      orders holds so many rows, its primary key is id, and customer_id carries an index named in the list.
```

1. Open `Dev Postgres` in the Browse tab.
2. Walk down the container level to the schema `public`.
3. Read the kind screen: which kinds are counted, which say they could not be counted.
4. Open the tables and find `orders`, whose tile carries the row count Studio listed with it.
5. Open its details and count its rows there, reading the counted number or the failure line.
6. Read its columns, then its indexes.

A count that says it could not be counted is a finished job, not an unfinished one: the DBA learned that the number
is not available, which is an answer. What the takeaway cannot survive is a number that is not the table's.

### dba-on-call/3 — A statement is taking too long: stop it from the phone.

```text
job:           dba-on-call/3
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.sql — Dev Postgres active, the editor empty
asks:          Whether a statement that is already running can be stopped from the phone, and whether the app says
               afterwards what became of it.
done:          ApplicationRoutesConstants.sql shows a cancelled line, a stopped-waiting line or a
               cancel-not-confirmed line, and the StatementHistorySheet over it holds the statement with an outcome.
takeaway:      The statement was cancelled on the server, or the app says it could not confirm that, and the history
               says which of the two happened.
```

1. Type a statement that sleeps for a minute, such as a `pg_sleep` select, and run it.
2. Watch the elapsed line while it runs, for at least five seconds.
3. Cancel it.
4. Read what the screen says once the cancel settles.
5. Open the history and read the entry for that statement.

The statement reads nothing and changes nothing; it exists to take time. "Cancelled" and "the cancel could not be
confirmed" are both finished jobs — one of them is worse news, and the finding format has a takeaway key so that the
difference between the two is not lost.

---

## data-analyst

### data-analyst/1 — What does one customer's record actually hold?

```text
job:           data-analyst/1
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.connectionList — signed in, no connection open
asks:          What is in one customer's row, so the number asked for in the corridor can be read out.
done:          ApplicationRoutesConstants.browseRows shows rows of public.customers, the RowDetailSheet over it shows
               that row's fields with its position in the result, and a copy confirmation appears after one value is
               copied.
takeaway:      That customer's row holds these values, and the ones the app showed as masked are not the values, so
               nothing masked is read out as if it were.
```

1. Open `Dev Postgres` and walk to the tables of the schema `public`.
2. Open `customers` and view its rows.
3. Open the first row's detail.
4. Read every field, `email` and `card_number` among them.
5. Copy one value, and read the confirmation.

Two of the columns are masked by Studio. The job is finished when the analyst can say what the row holds **and**
which of it is masked; a masked value read out as the value is the `S2` this job exists to catch.

### data-analyst/2 — Where does a table whose schema I don't know live?

```text
job:           data-analyst/2
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.browse — Dev Postgres server active, nothing opened under it
asks:          Which database and schema the table someone named by its bare name lives in, without being told.
done:          ApplicationRoutesConstants.browseSearch lists matches, each with the path it was found at, and opening
               one lands on ApplicationRoutesConstants.browseDetail for that object; or the screen says search is not
               available on this connection and the same object is reached by walking the container levels.
takeaway:      The table is in that database and that schema, and the analyst can now open it again from the top.
```

1. Open the search over the connection.
2. Search for part of the name, such as `order`.
3. Read the matches and the path each was found at.
4. Open one match.
5. Read where it says the object lives.

The connection names no database, so this one starts at the databases `app` and `archive`, which is why the path a
match carries is the answer and not decoration. The search being unavailable is a finished job too, by the branch the
`done:` names — the analyst got there by walking.

### data-analyst/3 — Is what I am looking at the whole answer?

```text
job:           data-analyst/3
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.sql — Dev Postgres active, the editor empty
asks:          Whether the rows on screen are all the rows the table holds, before the number is passed on.
done:          ApplicationRoutesConstants.sql shows the result with its row-and-time line and, when Studio bounded
               the result, the bounded notice, and ApplicationRoutesConstants.browseDetail shows the same table's
               own counted rows.
takeaway:      The result on screen is all of the table's rows, or it is the first so many of so many, and the
               analyst can say which by a number that is on screen.
```

1. Select everything from `sales.ledger` and run it.
2. Read the row-and-time line under the result.
3. Read the notices above or below the rows.
4. Load more rows if the screen offers it, and read the line again.
5. Open the same table in Browse, open its details, and count its rows there.
6. Compare the two numbers.

This is also run once in `tr`, because the lines that answer it are formatted counts.

---

## software-developer

### software-developer/1 — Why does my join return nothing?

```text
job:           software-developer/1
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.browse — Dev Postgres active, the schema public open
asks:          Which column of orders points at customers, and whether a join on it returns anything at all.
done:          ApplicationRoutesConstants.browseDetail names the referenced table and column under foreign keys, and
               ApplicationRoutesConstants.sql holds the statement opened from the object and shows either rows with
               their row-and-time line or the query-returned-no-data state.
takeaway:      orders joins to customers on that column, and the join returns rows, or it returns none for a reason
               the developer can now name.
```

1. Open `orders` and read its details.
2. Read the foreign keys: which table and column they reference.
3. Open the object in the editor from the object's own menu.
4. Write the join the foreign key implies, against `customers`.
5. Run it and read the result or the empty state.

### software-developer/2 — Is the definition that is deployed the one I think I deployed?

```text
job:           software-developer/2
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.browse — Dev Postgres active, the schema sales open
asks:          What the view's definition says on the server, and whether what is shown is the stored text.
done:          ApplicationRoutesConstants.browseSource shows the definition, with any regenerated, partial or
               truncated notice that belongs to it, and a copy confirmation appears after the text is copied.
takeaway:      The deployed definition says this, and it is either the stored text or Studio's regeneration of it —
               and the developer knows which, rather than assuming.
```

1. Open the views of the schema `sales`.
2. Open `order_totals` and view its source.
3. Read the notices above the text.
4. Read the definition to its end, scrolling if it is longer than the screen.
5. Copy it, and read the confirmation.

A regenerated definition is not a defect; a regenerated definition that reads as the stored text is the `S2` here.

### software-developer/3 — I have a two-statement fix: what ran and what did not?

```text
job:           software-developer/3
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.sql — Dev Postgres active, the editor empty
asks:          When a script of two statements is run and the second one fails, which of them ran, and what the
               database said about the one that did not.
done:          ApplicationRoutesConstants.sql shows one entry per statement, each with its own succeeded or failed
               outcome, the failed one carrying the database's own message, and the rows of the statement that
               succeeded can be opened from its entry.
takeaway:      The first statement ran and returned its rows, the second failed with that message, and nothing has to
               be run again to learn it.
```

1. Type two statements: one that selects a constant, then one that selects from a table that does not exist.
2. Run them, and read the confirmation that appears before anything runs.
3. Confirm, having read what it says will run.
4. Read the outcome of each statement in turn.
5. Open the rows of the statement that succeeded.

The confirmation appears because the editor is being asked to run more than one statement; reading it is step 2 of
the job, since a developer who confirms without reading has not learned what was about to happen.

---

## data-engineer

### data-engineer/1 — Did last night's load land in the table it was meant to?

```text
job:           data-engineer/1
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.connectionList — signed in, no connection open
asks:          How many rows the loaded tables hold now, and whether the two counts are plausible against each other.
done:          ApplicationRoutesConstants.browseKinds shows the counted kinds of the schema, and
               ApplicationRoutesConstants.browseDetail shows a counted number for each of the two tables, or a
               could-not-count line.
takeaway:      orders holds so many rows and order_items so many, and the second over the first is a believable
               number of items per order.
```

1. Open `Dev Postgres` in Browse and walk to the schema `public`.
2. Read the kind screen: how many tables, and which kinds could not be counted.
3. Open the tables, open the details of `orders`, and count its rows there.
4. Do the same for `order_items`.
5. Compare the two counts.

### data-engineer/2 — The pipeline's role sees less than mine: what, exactly?

```text
job:           data-engineer/2
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.browseDetail — Dev Postgres active, public.orders open on its details
asks:          Whether the role the pipeline signs in as sees the keys of the table it writes, or only the columns.
done:          ApplicationRoutesConstants.browseDetail is read under both connections for the same table, with the
               ConnectionSwitcherSheet over ApplicationRoutesConstants.browse showing the active one changed between
               the two readings.
takeaway:      Through one role the table has a primary key and a foreign key, through the other it has neither, and
               the difference is the database role and not the app.
```

1. Read the columns, the indexes and the foreign keys of `orders` as it is.
2. Switch the active connection to `Dev Postgres (read-only role)`.
3. Confirm from the switcher which connection is now active.
4. Walk to the same table and open its details.
5. Read the same three tabs and name every difference.

The two connections differ by one word in the list and point at the same database, so a reading taken under the wrong
one is the trap this job is shaped around: a finding here is only a finding if the evidence shows which connection
was active.

### data-engineer/3 — How far does a key walk get before it stops being the whole truth?

```text
job:           data-engineer/3
target:        lib/main/main_prod.dart
environment:   prod
session:       studio
start:         ApplicationRoutesConstants.browse — Dev Redis active, nothing opened under it
asks:          How many of the pipeline's keys a walk actually covered, whether more remain, and what one of them
               holds.
done:          ApplicationRoutesConstants.browseKeys shows a scanned-or-found line with a number and whether more
               remain, and ApplicationRoutesConstants.browseKeyValue shows one key's type and value, or says the app
               has no read for that type.
takeaway:      The walk covered so many keys of so many, more remain or they do not, and that key holds this value.
```

1. Open the container level and choose the database that holds the pipeline's keys.
2. From that database's kind screen, open the key browser and narrow it to a pattern, such as the users prefix.
3. Read the line that says how many were scanned or found, and whether more remain.
4. Load another page, then stop the walk, and read the line again.
5. Open one key and read its value.

The walk's own arithmetic is the point: "found 200" means nothing until it is read against what the database holds and
whether the walk is finished. This job is also run once in `tr`, where those lines are formatted counts.

---

## platform-engineer

The three jobs below run against the `platform` profile of `tool/studio-dev/docker-compose.yml`, built with
`tool/studio-dev/studio-dev-platform.env`, which is the stage #285 names for this persona:

```shell
docker compose -f tool/studio-dev/docker-compose.yml --profile platform up -d --wait
fvm flutter run --target lib/main/main_prod.dart \
  --dart-define-from-file=tool/studio-dev/studio-dev-platform.env --dart-define=SCREEN_CAPTURE_PROTECTION=false
```

**That stage needs a license the owner holds.** Without one, Platform starts in state `invalid` and the first call of
any bearer route answers 403, so no job of this persona starts at all — `docs/studio.md` says how the license file is
put in place, and it is not in the repository. If the owner has not supplied one when the run begins, the fallback
build is `lib/main/main_mock.dart`, whose Platform answers come from `assets/mock/GET_v1_connections.json` and its
neighbours; the run records `environment: mock` on every finding, and two things of the mock stage are then **not**
findings, because they are the fixtures and not the app: a grant that reappears after a refresh, since the list is
re-read from the same file, and any judgement about what the data itself says.

### platform-engineer/1 — Who can reach this database, at what level, and until when?

```text
job:           platform-engineer/1
target:        lib/main/main_prod.dart
environment:   prod
session:       platform
start:         ApplicationRoutesConstants.platformHome — signed in as a Platform admin, nothing opened yet
asks:          Who holds access to one connection, at what level, and which of those grants expire.
done:          ApplicationRoutesConstants.platformConnectionGrants lists each holder with a read or write level and
               an expiry line or a no-expiry line, or shows the no-one-has-access-yet state.
takeaway:      These people hold access to that connection, at these levels, and these of them lapse on these dates.
```

1. Open the connections of the install from the home screen.
2. Find the connection the question is about, by name or engine.
3. Open its grants.
4. Read each grant: who, which level, when it expires, who granted it.
5. Say which grants would lapse this month.

Also run once in `tr`: the expiry lines are formatted dates, and a date that reads as another date is `S2`.

### platform-engineer/2 — Give one person read access that expires, and confirm it is on.

```text
job:           platform-engineer/2
target:        lib/main/main_prod.dart
environment:   prod
session:       platform
start:         ApplicationRoutesConstants.platformConnectionGrants — the grants of one connection, read in job 1
asks:          Whether read access that lapses on a date can be given from the phone, and whether the app confirms it
               is on afterwards.
done:          ApplicationRoutesConstants.platformGrantEditor reports the grant saved, and
               ApplicationRoutesConstants.platformConnectionGrants then shows that user with a read level and an
               expiry line.
takeaway:      That user can read that database until that date, and the app said so rather than the engineer
               assuming it.
```

1. Start a new grant from the grants screen.
2. Search the directory and choose a user, reading what the picker says about them.
3. Choose the read level.
4. Set an expiry in the future, and read how it says the time is read.
5. Save, read the confirmation, and find the new grant in the list.

This is the only job on this page that writes. It writes one grant, on a disposable local install, and it is the
whole point of the persona: a Platform admin who cannot grant access from the phone has no reason to install the app.

### platform-engineer/3 — What did Studio run on this connection, and was the statement recorded?

```text
job:           platform-engineer/3
target:        lib/main/main_prod.dart
environment:   prod
session:       platform
start:         ApplicationRoutesConstants.platformAudit — the audit log as it opens, unfiltered
asks:          What ran on one connection in a window of time, who ran it, how it ended, and whether the statement
               text itself was recorded.
done:          ApplicationRoutesConstants.platformAudit shows events narrowed by the filters that were set, each
               filter visible as a chip, and ApplicationRoutesConstants.platformAuditEvent shows one event's user,
               connection, outcome, duration and either its statement or the reason there is none.
takeaway:      This person ran that statement on that connection at that time, it ended this way, and its text was
               captured in full, redacted, or not captured at all.
```

1. Open the filters and narrow the log to one connection.
2. Narrow it again by outcome, and by a day.
3. Read the chips that say what the list is now showing.
4. Open one event.
5. Read who ran it, when, how long it took, how it ended, and what the capture line says about its text.
6. Narrow the log to that user from the event itself, and read the list again.

A log that answers "not captured" has answered: the engineer learns that this install does not keep the text, which is
a governance fact. What the takeaway cannot survive is a redacted statement read as the statement.

---

## The guards that hold this page

| file | holds |
|---|---|
| `test/architecture/usability_jobs_doc_test.dart` | the roster against the job ids, the blocks against their keys, the steps against their numbering, every screen against `ApplicationRoutesConstants`, every build against `lib/main/`, every path against the tree, and every severity against the finding format |
| `test/architecture/usability_doc_test.dart` | the finding format this page is the other half of |
| `test/architecture/testing_doc_test.dart` | that both guards are named in `docs/testing-architecture.md` |

What the first one does **not** hold is whether a job is a good job. No guard can read that. It holds the things that
make a job executable without its author in the room, which are the things that fail quietly: an id that no persona
owns, a screen that was renamed, a step number that cannot be written into a finding, a path that moved.
