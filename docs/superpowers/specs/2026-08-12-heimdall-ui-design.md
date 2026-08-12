# Heimdall UI — Design

Date: 2026-08-12
Status: Approved

## 1. Purpose

Heimdall UI is the Flutter front-end for the [Heimdall API](https://github.com/artur-rios/heimdall-api),
a centralized identity-management API with scope-based multi-tenancy. The client covers every use
case the API exposes (UC-01 … UC-40): end-user authentication and self-service, and the
administrative console for scopes, persons, applications, scope permissions, and Google users.

One codebase ships to four targets: **Web** (browser), **Windows**, **Linux**, and **Android**.
iOS and macOS are out of scope — the code stays platform-neutral so adding them later is a
configuration change, not a rewrite.

## 2. Actors and access

The UI recognizes the API's three roles, and derives them from the authenticated token's claims:

| Role | Value | What the UI shows |
| --- | --- | --- |
| System Admin | `1` | Every scope, person, application, permission, and Google user across the system |
| Scope Admin | `2` | Only the scopes they own, and the persons, applications, permissions, and Google users within them |
| User | `3` | Own profile and own security settings only |

An unauthenticated caller reaches only the public screens: login, Google sign-in, password
recovery, password reset, and email verification.

## 3. Architecture

### 3.1 Layout

Feature-first, three layers per feature.

```
lib/
  app/            HeimdallApp, router + auth redirects, theme, breakpoints
  core/           env config, dio setup, interceptors, token store, failures, result
  features/
    auth/  profile/  scopes/  persons/  applications/  permissions/  google_users/  health/
       data/         repository implementations over the generated client
       domain/       entities, value objects, repository interfaces
       presentation/ screens, widgets, Riverpod notifiers
  shared/         adaptive scaffold, forms, collection views, dialogs, empty/error states
packages/heimdall_api_client/   generated: DTOs + retrofit services (never hand-edited)
api/heimdall.json               vendored snapshot of the API's OpenAPI specification
test/                           mirrors lib/ one-to-one
integration_test/               end-to-end smoke flows against a stubbed API
```

### 3.2 Boundaries

- **Presentation never imports the generated client.** Screens and notifiers depend on the domain
  repository interfaces; only `features/*/data` knows the generated types exist. This is what makes
  notifiers unit-testable against fakes, and what contains the blast radius when the API's
  specification changes.
- **Each feature owns its state.** A feature's Riverpod providers are declared in that feature; the
  only globally shared providers are the session, the theme mode, and the configured `Dio` instance.
- **`shared/` holds widgets with no feature knowledge.** If a widget needs a domain type, it belongs
  to the feature, not to `shared/`.

### 3.3 State management and routing

- **Riverpod** for dependency injection and state. Notifiers expose an immutable state per screen;
  asynchronous work goes through `AsyncValue` so loading and error rendering is uniform.
- **go_router** for declarative routing. Web builds get real, shareable URLs; a redirect hook
  enforces authentication and role, sending an unauthorized caller to login with a return path.

### 3.4 Result and error model

Every API response is a `DataOutput<T>` or a `PaginatedOutput<T>` envelope carrying `success`,
`messages`, `errors`, `timestamp`, and `data` (plus `pageNumber`, `pageSize`, `totalItems`,
`totalPages` when paginated). A single unwrapping layer in `core/` converts an envelope into a
`Result<T>`:

- `success` with `data` → success.
- `success == false`, or a non-2xx status → failure carrying the `errors` list.
- Transport, timeout, or deserialization problems → failure with a message the UI can render.

Failures render in one of two places, never both: field-level messages when the error maps to a form
field, and a banner or snackbar otherwise. A `401` is special-cased in a Dio interceptor — it clears
the session and redirects to login.

## 4. API client

`swagger_parser` (pure Dart, no Java toolchain) generates freezed DTOs and retrofit services from
`api/heimdall.json` into `packages/heimdall_api_client`.

- `tool/refresh_openapi.dart` refreshes the vendored specification from the API repository or a
  running instance.
- `tool/generate_api_client.dart` regenerates the package.
- Generated output is committed. A CI job regenerates and fails on any `git diff`, so a stale client
  cannot be merged — the same drift guard `heimdall-api` applies with its `check-openapi.yml`.

The generated package is never hand-edited. Ergonomic wrappers, when needed, live in the consuming
feature's `data/` layer.

## 5. Session and authentication

### 5.1 Login and the two-factor challenge

`POST /api/auth/login` answers with either a token or a two-factor challenge
(`requiresTwoFactor`, `challengeToken`, `availableMethods`). The session controller models three
states:

```
unauthenticated ──login──> challenged ──2fa/verify──> authenticated
       ^                        │                          │
       └────────────────────────┴────── sign out / 401 ─────┘
```

A challenge token is sent to exactly one endpoint, `POST /api/auth/2fa/verify`, and is never
attached to any other request nor persisted.

### 5.2 Token storage

Tokens live behind a `TokenStore` interface with one implementation per capability:

| Target | Implementation |
| --- | --- |
| Android, Windows, Linux | `flutter_secure_storage` (Keystore / DPAPI / libsecret) |
| Web | `flutter_secure_storage` web backend (WebCrypto-encrypted, `localStorage`) |
| Tests | in-memory fake |

The session restores from the store on start-up, and rejects a stored token whose `expiresAt` has
passed without contacting the API.

### 5.3 Google Sign-In

`google_sign_in` obtains a Google ID token on the platforms that support it; the token is exchanged
at `POST /api/auth/google` for a Heimdall token. Google sign-in is offered only when the target
scope has `googleSignInEnabled`.

## 6. Responsive design and theming

Material 3 throughout, with three breakpoints:

| Breakpoint | Width | Navigation | Collections | Detail |
| --- | --- | --- | --- | --- |
| Compact | `< 600` | Bottom navigation bar | Cards in a list | Full-screen route |
| Medium | `600 – 1024` | Navigation rail | Dense cards | Full-screen route |
| Expanded | `> 1024` | Extended rail or drawer | Paginated data table | Side-by-side pane |

Collections render from one shared widget that chooses its presentation from the breakpoint, so a
feature declares its columns once and gets both layouts.

Light and dark color schemes derive from a single seed color. The mode is `system` by default and
switchable to light or dark, persisted with `shared_preferences`. Every screen is verified in both
modes.

## 7. Testing

The project follows the API's convention: test names read
`GivenSomeCondition_WhenSomeAction_ThenSomeOutput`, and each body is divided by `// Given`,
`// When`, and `// Then` comments in that order.

| Level | Scope | Tools |
| --- | --- | --- |
| Unit | Notifiers, repositories, envelope unwrapping, guards, mappers | `flutter_test`, `mocktail`, Dio `MockAdapter` |
| Widget | Screens, forms, adaptive layout at each breakpoint, light and dark | `flutter_test` |
| Integration | Sign-in, two-factor, and one administrative CRUD flow end to end | `integration_test` against a stubbed API |

No test reaches the network. The gate for every pull request is
`dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test`, all green.

## 8. Documentation

`docs/requirements/` mirrors the seven-document structure of `heimdall-api`:

| Document | Content |
| --- | --- |
| Vision Document | Why the UI exists, its users, goals, success criteria |
| System Requirements Document | Functional and non-functional requirements, screen inventory, authorization matrix |
| Use Case Specification Document | UI-01 … UI-29 with flows, plus traceability to the API use cases |
| Technology Stack Document | Every technology and pinned version |
| Testing Specification Document | How each use case is tested |
| Development Workflow Document | Branch, issue status, testing gate, pull request |
| Operations & Infrastructure Document | Configuration, and build/package/release per target |

A Hugo documentation site is deliberately deferred; it is tracked as a platform issue rather than
built now.

## 9. Backlog

Twenty-nine UI use cases, each traced to the API use cases it consumes, plus four platform items,
across eight milestones. Each use case ships as one branch, one issue, and one pull request, per the
Development Workflow Document.

| Milestone | Items |
| --- | --- |
| Platform & Infrastructure | Scaffolding, generated API client, multi-platform CI, health screen |
| Authentication & Session | Login, two-factor challenge, password recovery, password reset, email verification, Google sign-in, session guarding |
| Profile & Security | Own profile, two-factor management |
| Scope Management | List, create, detail/update, delete, owners, Google sign-in toggle |
| Person Management | List, create, detail/update, delete |
| Application Management | List, create, detail/update, delete |
| Scope Permission Management | List, create, detail/update, delete |
| Google Users | List and detail, delete |

The README carries a delivery tracker with one row per use case, its status
(✅ done · 🚧 in progress · ⬜ not started), and its issue link — the same shape as the API's.

## 10. Scope of the first delivery

The first delivery is the documentation, the milestones and issues, the README, and the scaffolding
issue implemented:

- Flutter project configured for web, Windows, Linux, and Android.
- Material 3 theming with light, dark, and system modes.
- Responsive application shell with adaptive navigation.
- Routing with authentication and role guards.
- Generated API client and the vendored specification.
- Session, token storage, and the Dio interceptor stack.
- CI workflows, and tests covering the above.

The twenty-nine feature use cases are then delivered one at a time.

## 11. Constraints

- The UI is a client only: it holds no identity data of its own and enforces no authorization the
  API does not already enforce. Role-driven navigation is a usability affordance, not a security
  boundary.
- Every identifier the UI handles is a `PublicId` GUID; internal ids never appear.
- The API base URL is configuration, supplied per environment, never compiled in.
- No secret is stored in the repository or in the built artifacts.
