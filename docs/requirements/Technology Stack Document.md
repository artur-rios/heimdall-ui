---
title: "Technology Stack Document"
linkTitle: "Technology Stack Document"
weight: 40
description: "The technologies, libraries, and pinned versions Heimdall UI is built on."
---

# Technology Stack Document — Heimdall UI

## 1. Purpose

This document is the **single source of truth for the technologies used to build Heimdall UI** — the
framework, language, state management, routing, networking, storage, code generation, and testing
tools, together with the version each is pinned to and the role it plays.

Every other document references this one for technical choices instead of restating them, so that
versions and roles are maintained in exactly one place.

> **Rule:** when a technology choice changes, it changes here first. The authoritative resolved
> versions live in `pubspec.lock`; the tables below record the constraint declared in `pubspec.yaml`
> and what each dependency is for.

---

## 2. Platform and language

| Concern | Choice | Notes |
| --- | --- | --- |
| Framework | **Flutter 3.44.9** (stable) | One codebase for every target. |
| Language | **Dart 3.12.2** | Ships with the Flutter version above. Pattern matching, sealed classes, and exhaustive `switch` expressions are used freely, and the session and result models depend on them. |
| Design system | **Material 3** | `useMaterial3: true`, with both schemes derived from one seed color. |
| Targets | **Web, Windows, Linux, Android** | No iOS or macOS platform folder exists. |
| Analysis | `flutter_lints`, with `strict-casts` and `strict-raw-types` enabled | Generated code is excluded from analysis. |

---

## 3. Application dependencies

| Package | Constraint | Role |
| --- | --- | --- |
| **flutter_riverpod** | `^3.1.1` | Dependency injection and state. Providers are the only global wiring; each feature owns its own. `Notifier` and `AsyncNotifier` back the session and the theme mode. |
| **go_router** | `^17.4.0` | Declarative routing. Gives the web target real URLs, and hosts the single redirect that guards every route by session and role. |
| **dio** | `^5.11.0` | HTTP. One configured instance is shared by every generated client, carrying the bearer-token interceptor and the timeouts. |
| **retrofit** | `^4.9.2` | The generated clients' runtime: turns the annotated interfaces `swagger_parser` emits into `dio` calls. |
| **json_annotation** | `^4.12.0` | The generated models' runtime, paired with `json_serializable` at build time. |
| **flutter_secure_storage** | `^9.2.4` | Token storage: Keystore on Android, DPAPI on Windows, libsecret on Linux, and WebCrypto-encrypted local storage on the web. |
| **shared_preferences** | `^2.5.3` | Non-sensitive preferences — currently only the chosen theme mode. Never used for tokens. |
| **google_sign_in** | `^7.2.0` | Obtains the Google ID token the API exchanges for a Heimdall token. |
| **qr** | `^4.0.0` | Encodes the `otpAuthUri` of a two-factor setup into a QR matrix (FR-AU-18). Pure Dart, no platform code: the drawing is this repository's own `QrCodeView`, so the dependency is an encoder rather than a widget. |

---

## 4. Code generation

| Package | Constraint | Role |
| --- | --- | --- |
| **swagger_parser** | `^1.44.1` | Generates the DTOs and retrofit clients in `packages/heimdall_api_client/lib` from `api/heimdall.json`. Pure Dart, so no Java toolchain is required. Configured by `swagger_parser.yaml`. |
| **build_runner** | `^2.15.1` | Runs the generators. |
| **json_serializable** | `^6.14.1` | Emits the `fromJson`/`toJson` bodies for the generated models. |
| **retrofit_generator** | `^10.2.8` | Emits the client implementations. |

### 4.1 The generation pipeline

Generation runs as one command, which is what CI reruns:

```bash
dart run tool/generate_api_client.dart
```

It does three things in order:

1. Runs `swagger_parser` over `api/heimdall.json`.
2. Runs `build_runner` inside the package to emit the `.g.dart` bodies.
3. Runs `dart format` over the package, because the generators' own line breaking differs from what
   `dart format` at the repository root would produce — and a difference there would fail the drift
   check for no real reason.

The pipeline is deterministic: running it twice over an unchanged specification produces byte-identical
output, which is what makes the drift check meaningful.

> **A note on what this pipeline used to carry.** Until the API's
> [server-populated fields fix](https://github.com/artur-rios/heimdall-api/pull/83), several
> operations published both a path parameter `scopeId` and a query parameter `ScopeId` — the filter
> object's own property, which the path already supplied — alongside `ActingPersonId` and
> `ActingRole`. Dart identifiers are case-sensitive but the generator lower-camel-cases both names,
> so the emitted method declared `scopeId` twice and did not compile, and the pipeline carried a step
> that renamed the query side. The API now guards its published contract against server-populated
> fields with its own test, so that step has been removed rather than kept as a standing workaround.
> A recurrence would surface as a compilation failure in the generated package, which CI catches.

The generated package is committed, and CI regenerates it and fails on any difference — the same
drift guard the API applies to its own specification. Everything under
`packages/heimdall_api_client/lib` is generated and is never hand-edited; the package's own
`pubspec.yaml` is not generated and is maintained by hand. Ergonomic wrappers belong in the
consuming feature's `data/` layer.

The package's public entry point is `package:heimdall_api_client/export.dart`, and its clients are
named after their area — `AuthClient`, `ScopeClient`, `PersonClient`, `ApplicationClient`,
`ScopePermissionClient`, `GoogleUserClient`, and `HealthCheckClient` — each constructed as
`AuthClient(dio)`.

---

## 5. Testing

| Package | Constraint | Role |
| --- | --- | --- |
| **flutter_test** | SDK | The test framework for unit and widget tests. |
| **integration_test** | SDK | Drives end-to-end flows against a stubbed API. |
| **mocktail** | `^1.0.4` | The single mocking library, for repositories and other collaborators. Chosen over `mockito` because it needs no code generation. Do not introduce a second one. |

How tests are written — naming, structure, and what each use case must cover — is defined in the
[Testing Specification Document](Testing%20Specification%20Document.md).

Dio's own `HttpClientAdapter` is replaced in tests with a local adapter that answers from memory, so
no test reaches the network.

---

## 6. Continuous integration

| Tool | Role |
| --- | --- |
| **GitHub Actions** | Runs the analyze-and-test gate, the multi-platform builds, and the client drift check. |
| **subosito/flutter-action** | Installs the pinned Flutter version on each runner. |

---

## 7. Version summary

| Category | Package / tool | Version |
| --- | --- | --- |
| Framework | Flutter | `3.44.9` |
| Language | Dart | `3.12.2` |
| State | flutter_riverpod | `^3.1.1` |
| Routing | go_router | `^17.4.0` |
| HTTP | dio | `^5.11.0` |
| HTTP | retrofit | `^4.9.2` |
| Serialization | json_annotation | `^4.12.0` |
| Storage | flutter_secure_storage | `^9.2.4` |
| Storage | shared_preferences | `^2.5.3` |
| Authentication | google_sign_in | `^7.2.0` |
| Encoding | qr | `^4.0.0` |
| Generation | swagger_parser | `^1.44.1` |
| Generation | build_runner | `^2.15.1` |
| Generation | json_serializable | `^6.14.1` |
| Generation | retrofit_generator | `^10.2.8` |
| Testing | mocktail | `^1.0.4` |
| Lints | flutter_lints | `^6.0.0` |

> The exact resolved versions are in `pubspec.lock`, which is committed. When a constraint here and
> the lock file disagree, the lock file is what was built and this table is what is wrong.
