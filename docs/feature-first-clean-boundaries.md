# Feature-First Clean Boundaries

This document defines the target architecture for LibreDB Mobile.

## Goals

- Keep the codebase feature-oriented.
- Make dependency direction explicit and enforceable.
- Preserve the current Flutter stack: `flutter_bloc`, `go_router`, manual JSON models.

## Top-Level Ownership

```text
lib/
  app/               # Composition root, app shell, router, bootstrap
  core/              # Cross-cutting primitives, errors, logging abstractions
  infrastructure/    # Storage, HTTP, environment, external adapters
  shared/            # Business-free reusable UI and helpers
  features/          # Business capabilities
  generated/         # Generated localization files
  l10n/              # ARB files
```

## Dependency Rules

Allowed imports:

```text
app -> features
app -> shared
app -> infrastructure
app -> core

features -> shared
features -> infrastructure
features -> core

shared -> core
infrastructure -> core

features -> app/router/app_routes_constants.dart   # the route vocabulary only, see Routing Rules
shared -> app/theme/theme_bloc.dart                # the three settings dialogs only, see Shared vs Core
shared -> app/localization/locale_cubit.dart       # the three settings dialogs only, see Shared vs Core
```

These are the whole of what `features/` and `shared/` may read from `app/`, and
`test/architecture/import_guard_test.dart` holds them: the route vocabulary is matched whole, so a path that merely
starts with it does not come in with it, and each `shared/` dialog is waived by name, so the waiver covers those three
files and no other.

Forbidden imports:

```text
feature_a -> feature_b/presentation
feature_a -> feature_b/data
shared -> features
core -> shared
core -> features
infrastructure -> features/presentation
```

## Feature Structure

Each feature owns its navigation, state, and data contracts.

```text
features/<feature>/
  data/
  domain/
  application/
  presentation/
  navigation/
```

Notes:

- `domain/` stays Flutter-free when possible.
- `application/` contains `Bloc`, `Cubit`, use-case orchestration, and feature coordinators.
- `presentation/` contains pages and feature-local widgets.
- `navigation/` exposes route builders for the app router.
- `data/` contains external models and repository implementations.

## App Responsibilities

`app/` is the only place that may compose concrete implementations for the whole application.

Examples:

- Router composition
- Global providers
- Session bootstrap
- Shell layout
- Theme and localization bootstrap

`app/` must not contain feature business rules.

## Shared vs Core

Use `shared/` for business-free reusable UI:

- design system components
- dialogs
- generic widgets
- generic UI helpers

Use `core/` only for primitives that should not depend on Flutter UI concerns:

- error types
- result wrappers
- logging contracts
- small common types

Do not place theme, routes, widgets, or screens under `core/`.

Three dialogs under `shared/widgets/` read an app-level BLoC, and they stay there on purpose:
`language_selection_dialog.dart` (`LocaleCubit`), `theme_selection_dialog.dart` and
`brightness_selection_dialog.dart` (`ThemeBloc`). What they change — the app's language, palette and day/night mode —
is app-level state by this document's own State Management Rules, and the settings feature is only where it is shown
from. Holding them in `shared/` keeps the import at three files that the guard names; moving them into the feature
that opens them would put the same import in a feature instead, which is the direction with no waiver at all. The
same reasoning is why `BrightnessModeInForce` lives beside its dialog rather than in the feature whose tile shows it.

## Routing Rules

- `app/router` owns route composition.
- Each feature exposes its own routes from `features/<feature>/navigation/`.
- `app/router/app_routes_constants.dart` owns the route *vocabulary*, and a feature may read it. The paths are one
  composed namespace rather than a per-feature list — `accessRequests` is `'$connectionList/requests'`,
  `platformConnectionGrants` is built from `platformConnections`, and `belongsTo`, `tabsFor` and `homeFor` decide over
  all of them at once — so a feature that owned its own paths would have to import another feature's to build its own.
  That is the import this document forbids outright, which makes reading the app-owned vocabulary the smaller
  dependency, not an oversight. Composition still belongs to `app/router`: a feature hands it `GoRoute`s and reads
  paths, never the router.
- Redirect functions must stay pure and free of data loading side effects.
- Route builders must not create repositories directly.

## State Management Rules

- UI should never instantiate repositories directly.
- Feature pages should depend on feature application state only.
- Session/auth state is app-level.
- Shell state is app-level.
- Feature state remains inside the feature module.

## Review Checklist

- Does the file live under the correct owner?
- Does the import direction respect the rules?
- Is UI free from direct repository creation?
- Is the route owned by a feature or by app shell?
- Is reusable UI placed under `shared/` instead of feature folders?
