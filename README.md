# Heimdall UI

[![CI](https://github.com/artur-rios/heimdall-ui/actions/workflows/ci.yml/badge.svg)](https://github.com/artur-rios/heimdall-ui/actions/workflows/ci.yml)
[![Build](https://github.com/artur-rios/heimdall-ui/actions/workflows/build.yml/badge.svg)](https://github.com/artur-rios/heimdall-ui/actions/workflows/build.yml)
[![Check API client](https://github.com/artur-rios/heimdall-ui/actions/workflows/check-api-client.yml/badge.svg)](https://github.com/artur-rios/heimdall-ui/actions/workflows/check-api-client.yml)

The Flutter front-end for the [Heimdall API](https://github.com/artur-rios/heimdall-api).

## Overview

Heimdall UI is the interface over Heimdall, a centralized identity-management API with scope-based
multi-tenancy. It covers every use case the API exposes — signing in, answering a second factor,
recovering a password, verifying an address, managing your own profile, and administering scopes,
persons, applications, scope permissions, and Google users.

One codebase ships to four targets:

| Target | Output |
| --- | --- |
| **Web** | A static bundle that runs in any modern browser |
| **Windows** | A desktop application |
| **Linux** | A desktop application |
| **Android** | An APK or App Bundle |

What each person sees follows their role — **System Admin** (governs everything), **Scope Admin**
(governs the scopes they own), and **User** (their own account only). This is a usability decision,
not a security one: the API remains the sole authority on what anyone may actually do.

## Project structure

| Path | Responsibility |
| --- | --- |
| `lib/app/` | Application root, router and its guard, themes |
| `lib/core/` | Configuration, HTTP and interceptors, envelope unwrapping, result model, token storage |
| `lib/features/<feature>/data/` | Repository implementations over the generated client |
| `lib/features/<feature>/domain/` | Entities and repository interfaces |
| `lib/features/<feature>/presentation/` | Screens, widgets, and controllers |
| `lib/shared/` | Widgets with no feature knowledge — the adaptive shell, breakpoints |
| `packages/heimdall_api_client/` | The generated API client (never hand-edited) |
| `api/heimdall.json` | Vendored snapshot of the API's OpenAPI specification |
| `tool/` | Specification refresh and client generation |
| `test/` | Mirrors `lib/` one directory at a time |
| `docs/requirements/` | The specification documents |

Presentation code never imports `package:heimdall_api_client`; it depends on the domain repository
interfaces, and only `data/` knows the generated types exist.

## Documentation

The specification lives in [`docs/requirements`](docs/requirements):

- [Vision Document](docs/requirements/Vision%20Document.md) — why the interface exists, who it
  serves, and what success looks like.
- [System Requirements Document](docs/requirements/System%20Requirements%20Document.md) — functional
  and non-functional requirements, the screen inventory, and the authorization matrix.
- [Use Case Specification Document](docs/requirements/Use%20Case%20Specification%20Document.md) —
  UI-01 … UI-29 with their flows, each traced to the API use cases it consumes.
- [Technology Stack Document](docs/requirements/Technology%20Stack%20Document.md) — every technology
  and version, and how the API client is generated.
- [Testing Specification Document](docs/requirements/Testing%20Specification%20Document.md) — how
  each use case is tested.
- [Development Workflow Document](docs/requirements/Development%20Workflow%20Document.md) — how a use
  case goes from backlog to merged.
- [Operations & Infrastructure Document](docs/requirements/Operations%20%26%20Infrastructure%20Document.md) —
  configuration, prerequisites, and building for each target.

The design this repository was built from is at
[`docs/superpowers/specs`](docs/superpowers/specs), and its implementation plan at
[`docs/superpowers/plans`](docs/superpowers/plans).

## Prerequisites

- **Flutter 3.44.9** or newer, on the stable channel.
- **Web** — a Chromium-based browser for `flutter run -d chrome`.
- **Windows** — Visual Studio (or Build Tools) with the *Desktop development with C++* workload
  **and the C++ ATL component**. Without ATL the build fails on `atlstr.h`, which
  `flutter_secure_storage_windows` includes.
- **Linux** — `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`,
  `libstdc++-12-dev`, and `libsecret-1-dev`. The last is `flutter_secure_storage_linux`'s own
  dependency rather than part of Flutter's generic desktop list, and the build fails without it.
- **Android** — the Android SDK including `cmdline-tools`, the API 37 platform
  (`sdkmanager --install "platforms;android-37.0"`), accepted SDK licences (`flutter doctor
  --android-licenses`), and JDK 17. The app sets `compileSdk = 37` because `flutter_secure_storage`
  11 requires its consumers to, which is one level above Flutter's own default.

```bash
flutter doctor
```

## Install

```bash
git clone https://github.com/artur-rios/heimdall-ui.git
```

```bash
flutter pub get
```

The generated API client is committed, so no generation step is needed for a normal checkout. To
regenerate it after the API's specification changes:

```bash
dart run tool/refresh_openapi.dart ../heimdall-api/docs/openapi/heimdall.json
```

```bash
dart run tool/generate_api_client.dart
```

Commit the refreshed specification and the regenerated client together — CI fails when they
disagree.

## Configure

Configuration is supplied at build time. Nothing is read from a file at runtime.

| Key | Required | Default |
| --- | --- | --- |
| `HEIMDALL_API_BASE_URL` | In any real deployment | `http://localhost:5000` |
| `HEIMDALL_GOOGLE_CLIENT_ID` | Only for Google Sign-In | unset — the Google control is hidden |
| `HEIMDALL_SCOPE_ID` | Only when no calling application supplies one | unset — see below |

### The target scope

Heimdall UI is opened by the applications that use Heimdall's services, and the scope being entered
is theirs to name — there is no screen here that asks for it, and no endpoint an anonymous caller
could list scopes from. On the web the calling application writes the scope's `PublicId` into
**session storage** before sending the user here:

```js
sessionStorage.setItem('heimdall.scopeId', '<scope-public-id>');
```

Session storage rather than a cookie: it is scoped to the tab, so two tabs can act in two scopes; it
is never attached to a request, so the scope cannot become a header the API did not ask for; and it
dies with the tab, so a scope does not outlive the visit on a shared machine. It is read on every
use, so a caller may change it between one attempt and the next.

`HEIMDALL_SCOPE_ID` is the fallback for a build with no such caller — the desktop and Android
targets, or a web build opened directly.

```bash
flutter run --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

Or keep them in `config/local.json`, which is git-ignored:

```bash
flutter run --dart-define-from-file=config/local.json
```

## Run

```bash
flutter run -d chrome --dart-define-from-file=config/local.json
```

```bash
flutter run -d windows --dart-define-from-file=config/local.json
```

```bash
flutter run -d linux --dart-define-from-file=config/local.json
```

```bash
flutter run -d android --dart-define-from-file=config/local.json
```

## Test

```bash
flutter test
```

```bash
flutter test integration_test
```

```bash
flutter test --coverage
```

The gate before every pull request is all three of these, passing:

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Tests are named `GivenSomeCondition_WhenSomeAction_ThenSomeOutput`, and each body is divided by
`// Given`, `// When`, and `// Then` comments. No test reaches the network: HTTP is stubbed through a
local Dio adapter, and controllers are tested against fake repositories. See the
[Testing Specification Document](docs/requirements/Testing%20Specification%20Document.md).

## Build

```bash
flutter build web --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

```bash
flutter build windows --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

```bash
flutter build linux --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

```bash
flutter build apk --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

| Target | Artifact |
| --- | --- |
| Web | `build/web` — a static bundle; the host must fall back to `index.html` for deep links |
| Windows | `build/windows/x64/runner/Release` |
| Linux | `build/linux/x64/release/bundle` |
| Android | `build/app/outputs/flutter-apk` |

## Use case status

Delivery tracker for the use cases in the
[Use Case Specification Document](docs/requirements/Use%20Case%20Specification%20Document.md), plus
the platform work that is not itself a use case. Each one ships on its own branch, issue, and pull
request — see the
[Development Workflow Document](docs/requirements/Development%20Workflow%20Document.md).

The same work is on the public board at
[Heimdall UI Delivery](https://github.com/users/artur-rios/projects/11), which carries the
`Todo → In Progress → Testing → Done` status of every issue. This table is the at-a-glance summary;
the board is where an item's status changes as it moves.

**Legend:** ✅ done and merged &nbsp;·&nbsp; 🚧 in progress &nbsp;·&nbsp; ⬜ not started

### Authentication & Session

| Use case | Status | Issue |
| --- | --- | --- |
| UI-01: Login | ✅ | [#1](https://github.com/artur-rios/heimdall-ui/issues/1) |
| UI-02: Complete two-factor challenge at login | ✅ | [#2](https://github.com/artur-rios/heimdall-ui/issues/2) |
| UI-03: Request password recovery | ✅ | [#3](https://github.com/artur-rios/heimdall-ui/issues/3) |
| UI-04: Reset password | ✅ | [#4](https://github.com/artur-rios/heimdall-ui/issues/4) |
| UI-05: Verify email and resend verification | ✅ | [#5](https://github.com/artur-rios/heimdall-ui/issues/5) |
| UI-06: Sign in and sign out with Google | ✅ | [#6](https://github.com/artur-rios/heimdall-ui/issues/6) |
| UI-07: Guard routes by session and role | ✅ | [#7](https://github.com/artur-rios/heimdall-ui/issues/7) |

### Profile & Security

| Use case | Status | Issue |
| --- | --- | --- |
| UI-08: View and edit own profile | ✅ | [#8](https://github.com/artur-rios/heimdall-ui/issues/8) |
| UI-09: Manage two-factor authentication | ⬜ | [#9](https://github.com/artur-rios/heimdall-ui/issues/9) |

### Scope Management

| Use case | Status | Issue |
| --- | --- | --- |
| UI-10: Browse and search scopes | ✅ | [#10](https://github.com/artur-rios/heimdall-ui/issues/10) |
| UI-11: Create a scope | ✅ | [#11](https://github.com/artur-rios/heimdall-ui/issues/11) |
| UI-12: View and update a scope | ✅ | [#12](https://github.com/artur-rios/heimdall-ui/issues/12) |
| UI-13: Delete a scope, logically and permanently | ✅ | [#13](https://github.com/artur-rios/heimdall-ui/issues/13) |
| UI-14: Manage scope owners | ✅ | [#14](https://github.com/artur-rios/heimdall-ui/issues/14) |
| UI-15: Toggle Google Sign-In for a scope | ✅ | [#15](https://github.com/artur-rios/heimdall-ui/issues/15) |

### Person Management

| Use case | Status | Issue |
| --- | --- | --- |
| UI-16: Browse and search persons in a scope | ✅ | [#16](https://github.com/artur-rios/heimdall-ui/issues/16) |
| UI-17: Create a person | ✅ | [#17](https://github.com/artur-rios/heimdall-ui/issues/17) |
| UI-18: View and update a person | ✅ | [#18](https://github.com/artur-rios/heimdall-ui/issues/18) |
| UI-19: Delete a person, logically and permanently | ✅ | [#19](https://github.com/artur-rios/heimdall-ui/issues/19) |

### Application Management

| Use case | Status | Issue |
| --- | --- | --- |
| UI-20: Browse applications in a scope | ✅ | [#20](https://github.com/artur-rios/heimdall-ui/issues/20) |
| UI-21: Create an application | ✅ | [#21](https://github.com/artur-rios/heimdall-ui/issues/21) |
| UI-22: View and update an application | ✅ | [#22](https://github.com/artur-rios/heimdall-ui/issues/22) |
| UI-23: Delete an application, logically and permanently | ✅ | [#23](https://github.com/artur-rios/heimdall-ui/issues/23) |

### Scope Permission Management

| Use case | Status | Issue |
| --- | --- | --- |
| UI-24: Browse scope permissions | ✅ | [#24](https://github.com/artur-rios/heimdall-ui/issues/24) |
| UI-25: Create a scope permission | ✅ | [#25](https://github.com/artur-rios/heimdall-ui/issues/25) |
| UI-26: View and update a scope permission | ⬜ | [#26](https://github.com/artur-rios/heimdall-ui/issues/26) |
| UI-27: Delete a scope permission, logically and permanently | ⬜ | [#27](https://github.com/artur-rios/heimdall-ui/issues/27) |

### Google Users

| Use case | Status | Issue |
| --- | --- | --- |
| UI-28: Browse and view Google users | ⬜ | [#28](https://github.com/artur-rios/heimdall-ui/issues/28) |
| UI-29: Delete a Google user, logically and permanently | ⬜ | [#29](https://github.com/artur-rios/heimdall-ui/issues/29) |

### Platform

Not use cases, tracked separately.

| Item | Status | Issue |
| --- | --- | --- |
| P-01: Project scaffolding and initial infrastructure | ✅ | [#30](https://github.com/artur-rios/heimdall-ui/issues/30) |
| P-02: Generated API client and specification drift check | ✅ | [#31](https://github.com/artur-rios/heimdall-ui/issues/31) |
| P-03: Multi-platform build and release pipelines | ✅ | [#32](https://github.com/artur-rios/heimdall-ui/issues/32) |
| P-04: API health and diagnostics screen | ⬜ | [#33](https://github.com/artur-rios/heimdall-ui/issues/33) |

The sign-in and home screens exist as part of P-01, so the shell is reachable at all. UI-01 and UI-07
complete them with their alternative flows; every other screen arrives with its own use case, and
until then an unknown route says so plainly rather than throwing.

## Legal

Proprietary. See [LICENSE](LICENSE). Copyright (c) 2026 Artur Rios. All rights reserved.
