# Heimdall UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the Heimdall UI documentation set, the GitHub backlog, the README, and the scaffolding and infrastructure the twenty-nine feature use cases will be built on.

**Architecture:** A Flutter application targeting web, Windows, Linux, and Android from one codebase, organized feature-first with `data`/`domain`/`presentation` layers, Riverpod for dependency injection and state, go_router for guarded declarative routing, and a Dart API client generated from the Heimdall API's OpenAPI specification into a local package. Presentation code depends on domain repository interfaces only, never on the generated client.

**Tech Stack:** Flutter 3.44.9 / Dart 3.12.2, Material 3, `flutter_riverpod`, `go_router`, `dio`, `retrofit`, `freezed`, `json_serializable`, `swagger_parser`, `flutter_secure_storage`, `shared_preferences`, `google_sign_in`, `flutter_test`, `mocktail`, `integration_test`, GitHub Actions.

## Global Constraints

- Target platforms are exactly web, Windows, Linux, and Android. Do not create iOS or macOS platform folders.
- Test names use `GivenSomeCondition_WhenSomeAction_ThenSomeOutput`, and each body is divided by `// Given`, `// When`, `// Then` comments in that order.
- No test may reach the network. HTTP is always stubbed through Dio's `MockAdapter` or a fake repository.
- Presentation code (`lib/features/*/presentation`, `lib/app`, `lib/shared`) must never import `package:heimdall_api_client`. Only `lib/features/*/data` may.
- `packages/heimdall_api_client/lib/` is generated output and is never hand-edited.
- Every identifier exchanged with the API is a `PublicId` GUID, typed as `String` in Dart.
- The API base URL is supplied by configuration (`--dart-define=HEIMDALL_API_BASE_URL=...`), never compiled in as a literal outside the default.
- Roles are `SystemAdmin = 1`, `ScopeAdmin = 2`, `User = 3`.
- Every response envelope is `DataOutput<T>` (`messages`, `errors`, `timestamp`, `success`, `data`) or `PaginatedOutput<T>` (the same fields plus `pageNumber`, `pageSize`, `totalItems`, `totalPages`).
- The gate before every commit that touches Dart code is `dart format --set-exit-if-changed .`, `flutter analyze`, and `flutter test`, all passing.
- Commit messages use lower-case Conventional Commits subjects under 50 characters, a blank line, and a body wrapped at 72 columns.

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `docs/requirements/*.md` | The seven specification documents |
| `docs/superpowers/specs/`, `docs/superpowers/plans/` | Design and this plan |
| `api/heimdall.json` | Vendored snapshot of the API's OpenAPI specification |
| `packages/heimdall_api_client/` | Generated DTOs and retrofit services |
| `tool/refresh_openapi.dart` | Refreshes the vendored specification |
| `lib/main.dart` | Entry point: bootstraps configuration and runs the app |
| `lib/app/heimdall_app.dart` | Root widget wiring router and theme |
| `lib/app/router.dart` | Route table and the authentication redirect |
| `lib/app/theme.dart` | Light and dark Material 3 schemes |
| `lib/app/theme_mode_controller.dart` | Persisted theme mode |
| `lib/core/config/app_config.dart` | Base URL and environment values |
| `lib/core/network/dio_client.dart` | Configured `Dio` and its interceptors |
| `lib/core/network/auth_interceptor.dart` | Bearer header and 401 handling |
| `lib/core/network/envelope.dart` | `DataOutput`/`PaginatedOutput` unwrapping |
| `lib/core/result/result.dart` | `Result<T>` and `Failure` |
| `lib/core/storage/token_store.dart` | Token persistence interface and implementations |
| `lib/features/auth/domain/session.dart` | Session state and the authenticated principal |
| `lib/features/auth/presentation/session_controller.dart` | Session state machine |
| `lib/shared/layout/breakpoints.dart` | Compact/medium/expanded classification |
| `lib/shared/layout/adaptive_scaffold.dart` | Navigation that follows the breakpoint |
| `.github/workflows/*.yml` | Analyze/test, multi-platform build, client drift check |
| `README.md` | Overview, install, run, test, docs references, delivery tracker |

---

## Task 1: Requirements documentation

**Files:**
- Create: `docs/requirements/Vision Document.md`
- Create: `docs/requirements/System Requirements Document.md`
- Create: `docs/requirements/Use Case Specification Document.md`
- Create: `docs/requirements/Technology Stack Document.md`
- Create: `docs/requirements/Testing Specification Document.md`
- Create: `docs/requirements/Development Workflow Document.md`
- Create: `docs/requirements/Operations & Infrastructure Document.md`

**Interfaces:**
- Consumes: the approved design at `docs/superpowers/specs/2026-08-12-heimdall-ui-design.md`, and the API's own documents under `D:\Repositories\heimdall-api\docs\requirements\`.
- Produces: the use case identifiers `UI-01` … `UI-29` and platform items `P-01` … `P-04` that Task 2 turns into issues and Task 12 lists in the README tracker.

- [ ] **Step 1: Write the Use Case Specification Document**

This document is written first because every other document and the whole backlog reference its
identifiers. Each use case gets: a name, the actor(s), preconditions, the main flow, alternative
flows numbered `AF-xx`, and a `Traces to` line naming the API use cases it consumes.

The full inventory, which must appear both in the overview table and as individual specifications:

| ID | Use case | Traces to |
| --- | --- | --- |
| UI-01 | Login | UC-11 |
| UI-02 | Complete two-factor challenge at login | UC-38 |
| UI-03 | Request password recovery | UC-12 |
| UI-04 | Reset password | UC-13 |
| UI-05 | Verify email and resend verification | UC-14, UC-15 |
| UI-06 | Sign in and sign out with Google | UC-25, UC-26 |
| UI-07 | Guard routes by session and role | — (cross-cutting) |
| UI-08 | View and edit own profile | UC-07, UC-08 |
| UI-09 | Manage two-factor authentication | UC-36, UC-37, UC-39, UC-40 |
| UI-10 | Browse and search scopes | UC-02 |
| UI-11 | Create a scope | UC-01 |
| UI-12 | View and update a scope | UC-02, UC-03 |
| UI-13 | Delete a scope, logically and permanently | UC-04, UC-05 |
| UI-14 | Manage scope owners | UC-21, UC-22, UC-23 |
| UI-15 | Toggle Google Sign-In for a scope | UC-24 |
| UI-16 | Browse and search persons in a scope | UC-07 |
| UI-17 | Create a person | UC-06 |
| UI-18 | View and update a person | UC-07, UC-08 |
| UI-19 | Delete a person, logically and permanently | UC-09, UC-10 |
| UI-20 | Browse applications in a scope | UC-17 |
| UI-21 | Create an application | UC-16 |
| UI-22 | View and update an application | UC-17, UC-18 |
| UI-23 | Delete an application, logically and permanently | UC-19, UC-20 |
| UI-24 | Browse scope permissions | UC-32 |
| UI-25 | Create a scope permission | UC-31 |
| UI-26 | View and update a scope permission | UC-32, UC-33 |
| UI-27 | Delete a scope permission, logically and permanently | UC-34, UC-35 |
| UI-28 | Browse and view Google users | UC-27 |
| UI-29 | Delete a Google user, logically and permanently | UC-28, UC-29 |

Platform items, which are not use cases and are listed in their own section:

| ID | Item |
| --- | --- |
| P-01 | Project scaffolding and initial infrastructure |
| P-02 | Generated API client and specification drift check |
| P-03 | Multi-platform build and release pipelines |
| P-04 | API health and diagnostics screen (consumes UC-30) |

Write each use case in this shape, using UI-01 as the template for the rest:

```markdown
### UI-01: Login

**Actor:** Anonymous
**Traces to:** UC-11 (Login)
**Precondition:** The application is configured with a reachable API base URL and no valid session exists.

**Main flow**

1. The user opens the application and is redirected to the login screen.
2. The user enters an email address and a password.
3. The user submits the form.
4. The client calls `POST /api/auth/login`.
5. The API answers with a token and its expiry.
6. The client stores the token, establishes the session, and redirects to the screen the user
   originally requested, or to the home screen.

**Alternative flows**

- **AF-01a — Invalid credentials.** The API answers unsuccessfully. The client shows the returned
  errors above the form, keeps the email, and clears the password.
- **AF-01b — Client-side validation fails.** An empty or malformed email, or an empty password,
  blocks submission and marks the offending field. No request is made.
- **AF-01c — Two-factor required.** The response carries `requiresTwoFactor`, a `challengeToken`,
  and `availableMethods`. The client moves the session to `challenged` and routes to UI-02 instead
  of establishing a session.
- **AF-01d — API unreachable.** A transport failure or timeout shows a retryable banner; no session
  state changes.
```

- [ ] **Step 2: Write the Vision Document**

Cover: purpose (a Flutter client for the Heimdall API), scope (all four platforms, every API use
case), definitions (Scope, Person, Application, Scope Permission, Google User, Public Id, and the UI
terms Session, Challenge, Breakpoint), the problem statement (the API has no interface; operators
manage identities through raw HTTP calls), a product position table, stakeholders (System Admin,
Scope Admin, User, and the operator installing the app), core features F-01 … F-10 mapping to the
milestones, and success criteria — a Scope Admin can perform every scope-level task without touching
the API directly, and the same build behaves correctly on all four targets in both themes.

- [ ] **Step 3: Write the System Requirements Document**

Cover functional requirements grouped as `FR-AU-xx` (authentication and session), `FR-SC-xx`
(scopes), `FR-PE-xx` (persons), `FR-AP-xx` (applications), `FR-PM-xx` (permissions), `FR-GU-xx`
(Google users), and `FR-UX-xx` (shell, theming, responsiveness), each traced to the use case that
delivers it. Then non-functional requirements: `NFR-01` responsiveness across the three breakpoints;
`NFR-02` light and dark themes on every screen; `NFR-03` platform parity across web, Windows, Linux,
and Android; `NFR-04` token confidentiality at rest; `NFR-05` no secret in the repository or in a
built artifact; `NFR-06` every list paginated through the API rather than in memory; `NFR-07`
accessibility — focus order, minimum contrast, semantic labels on icon-only controls; `NFR-08`
the client enforces no authorization the API does not; `NFR-09` startup to interactive under three
seconds on the web target over a warm cache.

Include the authorization matrix — a table of screen against role (System Admin, Scope Admin, User,
Anonymous) marking visible, hidden, or read-only — and a screen inventory naming each route path.

- [ ] **Step 4: Write the Technology Stack Document**

Table every technology with its role and its pinned version, in the same shape as the API's
document: Flutter and Dart, `flutter_riverpod`, `go_router`, `dio`, `retrofit`, `freezed`,
`json_serializable`, `build_runner`, `swagger_parser`, `flutter_secure_storage`,
`shared_preferences`, `google_sign_in`, `flutter_test`, `mocktail`, `integration_test`. Leave the
version column as `see pubspec.lock` for now; Task 4 fills in the resolved versions once the
dependencies are actually added, and this document becomes the single place versions are recorded.

- [ ] **Step 5: Write the Testing Specification Document**

Define the three levels (unit, widget, integration), the `GivenSomeCondition_WhenSomeAction_ThenSomeOutput`
naming rule with the `// Given / // When / // Then` body sections, the rule that no test reaches the
network, what each use case must cover (main flow plus every `AF-xx`), the directory mirroring rule
(`test/` mirrors `lib/`), and the commands:

```bash
flutter test
```

```bash
flutter test integration_test
```

Include a worked example using UI-01's login controller so the convention is unambiguous.

- [ ] **Step 6: Write the Development Workflow Document**

Mirror the API's document: one use case = one branch = one issue = one pull request; branch naming
`feature/ui-##-use-case-name` and `feature/p-##-item-name`; the issue status lifecycle Todo → In
Progress → Testing → Done; the testing gate (`dart format --set-exit-if-changed .`,
`flutter analyze`, `flutter test`, all green before a pull request); human review and merge, with
the same authorized-batch-run exception the API grants; and a Definition of Done checklist that adds
two UI-specific items — the screen was verified at all three breakpoints, and in both light and dark
themes.

- [ ] **Step 7: Write the Operations & Infrastructure Document**

Cover configuration (`HEIMDALL_API_BASE_URL` and any Google client id, supplied by `--dart-define`,
with the `--dart-define-from-file` form for local development), the build command for each target,
what each produces, and where release artifacts go:

```bash
flutter build web --release --dart-define=HEIMDALL_API_BASE_URL=https://api.example.com
```

```bash
flutter build windows --release
```

```bash
flutter build linux --release
```

```bash
flutter build apk --release
```

Also cover the Linux build's system dependencies, web hosting requirements (the app is a static
bundle; the API must permit the origin via CORS), and the fact that no server-side component exists.

- [ ] **Step 8: Commit**

```bash
git add docs/requirements
git commit -m "docs: add heimdall ui requirements documents"
```

---

## Task 2: Milestones and backlog issues

**Files:**
- Create: `.github/ISSUE_TEMPLATE/use-case.md`

**Interfaces:**
- Consumes: `UI-01` … `UI-29` and `P-01` … `P-04` from Task 1.
- Produces: GitHub issue numbers, which Task 12 links from the README tracker.

- [ ] **Step 1: Write the issue template**

```markdown
---
name: Use case
about: A use case from the Use Case Specification Document
title: "UI-00: Use case name"
labels: use-case
---

## Use case

Link to the use case in the [Use Case Specification Document](../../docs/requirements/Use%20Case%20Specification%20Document.md).

**Traces to:** API use case(s) this consumes.

## Scope

What the screen or flow must do, in terms of the main flow and each alternative flow.

## Definition of Done

- [ ] Main flow and every alternative flow implemented.
- [ ] Unit tests cover the controller and any mapping or guard logic.
- [ ] Widget tests cover the screen at compact, medium, and expanded breakpoints.
- [ ] Verified in both light and dark themes.
- [ ] `dart format --set-exit-if-changed .`, `flutter analyze`, and `flutter test` all pass.
- [ ] Pull request merged and branch deleted.
```

- [ ] **Step 2: Create the milestones**

```bash
for m in "Platform & Infrastructure" "Authentication & Session" "Profile & Security" "Scope Management" "Person Management" "Application Management" "Scope Permission Management" "Google Users"; do gh api repos/artur-rios/heimdall-ui/milestones -f title="$m" >/dev/null; done
```

- [ ] **Step 3: Verify the milestones exist**

```bash
gh api repos/artur-rios/heimdall-ui/milestones --jq '.[].title'
```

Expected: the eight titles above, one per line.

- [ ] **Step 4: Create the four platform issues**

Each issue body states the goal, the scope of work, and a Definition of Done. Create them with
`gh issue create --title ... --body ... --milestone "Platform & Infrastructure" --label platform`.
`P-01` must enumerate exactly what this plan's Tasks 3 and 5 through 10 deliver, `P-02` what Task 4
delivers, `P-03` what Task 11 delivers, and `P-04` the health screen, which is not implemented in
this plan.

- [ ] **Step 5: Create the twenty-nine use case issues**

One issue per row of the UI-01 … UI-29 table, titled `UI-##: Use case name`, bodied from the issue
template with the traceability line filled in, labelled `use-case`, and assigned to its milestone:
UI-01 … UI-07 to Authentication & Session, UI-08 … UI-09 to Profile & Security, UI-10 … UI-15 to
Scope Management, UI-16 … UI-19 to Person Management, UI-20 … UI-23 to Application Management,
UI-24 … UI-27 to Scope Permission Management, UI-28 … UI-29 to Google Users.

- [ ] **Step 6: Verify the backlog**

```bash
gh issue list --repo artur-rios/heimdall-ui --limit 50 --json number,title,milestone
```

Expected: 33 issues, each with a milestone. Record the number of each so Task 12 can link them.

- [ ] **Step 7: Commit the template**

```bash
git add .github/ISSUE_TEMPLATE
git commit -m "chore: add use case issue template"
```

---

## Task 3: Flutter project scaffolding

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `LICENSE`, `lib/main.dart`, and the `web/`, `windows/`, `linux/`, `android/` platform folders
- Test: `test/smoke_test.dart`

**Interfaces:**
- Produces: a runnable Flutter application named `heimdall_ui` with the four platform targets, which every later task builds on.

- [ ] **Step 1: Create the project in place**

```bash
flutter create --project-name heimdall_ui --org com.arturrios --platforms web,windows,linux,android --description "Flutter front-end for the Heimdall API" .
```

- [ ] **Step 2: Verify only the intended platforms exist**

```bash
ls -d android ios linux macos web windows 2>&1
```

Expected: `android`, `linux`, `web`, `windows` present; `ios` and `macos` absent.

- [ ] **Step 3: Add the linter configuration**

Replace `analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "packages/heimdall_api_client/lib/**"
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  language:
    strict-casts: true
    strict-raw-types: true

linter:
  rules:
    - always_declare_return_types
    - avoid_print
    - prefer_const_constructors
    - prefer_final_locals
    - require_trailing_commas
    - unawaited_futures
```

- [ ] **Step 4: Add the LICENSE**

Copy the MIT licence text from `D:\Repositories\heimdall-api\LICENSE` verbatim, keeping the same
copyright holder and year line.

- [ ] **Step 5: Replace the generated counter test with a smoke test**

Delete `test/widget_test.dart` and create `test/smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'GivenMaterialApp_WhenPumped_ThenRendersWithoutError',
    (tester) async {
      // Given
      const app = MaterialApp(home: Scaffold(body: Text('Heimdall')));

      // When
      await tester.pumpWidget(app);

      // Then
      expect(find.text('Heimdall'), findsOneWidget);
    },
  );
}
```

- [ ] **Step 6: Run the gate**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: formatting clean, no analyzer issues, one test passing.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "build: scaffold flutter project for four targets"
```

---

## Task 4: Vendored specification and generated API client

**Files:**
- Create: `api/heimdall.json`, `swagger_parser.yaml`, `tool/refresh_openapi.dart`, `packages/heimdall_api_client/` (generated)
- Modify: `pubspec.yaml`, `docs/requirements/Technology Stack Document.md`
- Test: `test/api_client/generated_client_test.dart`

**Interfaces:**
- Produces: `package:heimdall_api_client` exposing retrofit services (`AuthService`, `ScopesService`, `PersonsService`, `ApplicationsService`, `ScopePermissionsService`, `GoogleUsersService`, `HealthCheckService`) and the DTOs named in the specification's `components.schemas`, each constructed with a `Dio` instance: `AuthService(dio, baseUrl: ...)`.

- [ ] **Step 1: Vendor the specification**

```bash
mkdir -p api && cp "D:/Repositories/heimdall-api/docs/openapi/heimdall.json" api/heimdall.json
```

- [ ] **Step 2: Add the runtime and generation dependencies**

```bash
flutter pub add dio retrofit json_annotation && flutter pub add --dev build_runner retrofit_generator json_serializable swagger_parser
```

- [ ] **Step 3: Configure the generator**

Create `swagger_parser.yaml`:

```yaml
swagger_parser:
  schema_path: api/heimdall.json
  output_directory: packages/heimdall_api_client
  language: dart
  json_serializer: json_serializable
  root_client: false
  put_clients_in_folder: true
  enums_to_json: true
  unknown_enum_value: true
  name: heimdall_api_client
```

- [ ] **Step 4: Generate the client**

```bash
dart run swagger_parser && cd packages/heimdall_api_client && dart pub get && dart run build_runner build --delete-conflicting-outputs && cd ../..
```

If `swagger_parser` cannot process the specification, stop and report the failure rather than
hand-writing the package: the drift check in Task 11 depends on generation being reproducible.

- [ ] **Step 5: Depend on the generated package**

Add to `pubspec.yaml` under `dependencies`:

```yaml
  heimdall_api_client:
    path: packages/heimdall_api_client
```

Then:

```bash
flutter pub get
```

- [ ] **Step 6: Write a test proving the generated client is usable and offline**

Create `test/api_client/generated_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_api_client/heimdall_api_client.dart';

void main() {
  test(
    'GivenGeneratedLoginOutput_WhenDeserialized_ThenCarriesTheTwoFactorChallenge',
    () {
      // Given
      final json = <String, dynamic>{
        'requiresTwoFactor': true,
        'challengeToken': 'challenge-token',
        'availableMethods': <String>['Totp', 'Email'],
      };

      // When
      final output = LoginCommandOutput.fromJson(json);

      // Then
      expect(output.requiresTwoFactor, isTrue);
      expect(output.challengeToken, 'challenge-token');
      expect(output.availableMethods, containsAll(<String>['Totp', 'Email']));
    },
  );

  test('GivenDioInstance_WhenServiceConstructed_ThenNoRequestIsMade', () {
    // Given
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));

    // When
    final service = AuthService(dio);

    // Then
    expect(service, isNotNull);
  });
}
```

Adjust the imported symbol names to those the generator actually emitted; the class names come from
`components.schemas` in `api/heimdall.json`.

- [ ] **Step 7: Write the specification refresh tool**

Create `tool/refresh_openapi.dart`, which copies the specification from a path or downloads it from a
URL given as the single argument, writes `api/heimdall.json`, and prints whether the content changed:

```dart
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/refresh_openapi.dart <path-or-url>');
    exitCode = 64;
    return;
  }

  final source = args.single;
  final target = File('api/heimdall.json');
  final previous = target.existsSync() ? target.readAsStringSync() : '';

  final String fetched;
  if (source.startsWith('http://') || source.startsWith('https://')) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(source));
      final response = await request.close();
      if (response.statusCode != 200) {
        stderr.writeln('fetch failed: HTTP ${response.statusCode}');
        exitCode = 1;
        return;
      }
      fetched = await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  } else {
    fetched = File(source).readAsStringSync();
  }

  target.parent.createSync(recursive: true);
  target.writeAsStringSync(fetched);
  stdout.writeln(previous == fetched ? 'specification unchanged' : 'specification updated');
}
```

- [ ] **Step 8: Record the resolved versions**

Read the resolved versions from `pubspec.lock` and fill in the version column of
`docs/requirements/Technology Stack Document.md`, replacing every `see pubspec.lock` placeholder.

- [ ] **Step 9: Run the gate**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: all pass. The analyzer excludes the generated package, so generator style does not fail the
build.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: generate dart api client from openapi spec"
```

---

## Task 5: Configuration, result model, and envelope unwrapping

**Files:**
- Create: `lib/core/config/app_config.dart`, `lib/core/result/result.dart`, `lib/core/network/envelope.dart`
- Test: `test/core/result/result_test.dart`, `test/core/network/envelope_test.dart`, `test/core/config/app_config_test.dart`

**Interfaces:**
- Produces:
  - `class AppConfig { const AppConfig({required String apiBaseUrl, String? googleClientId}); factory AppConfig.fromEnvironment(); final String apiBaseUrl; final String? googleClientId; }`
  - `sealed class Result<T>` with `Success<T>(T value)` and `FailureResult<T>(Failure failure)`, plus `bool get isSuccess`, `T? get valueOrNull`, `Failure? get failureOrNull`, and `R fold<R>({required R Function(T) onSuccess, required R Function(Failure) onFailure})`.
  - `class Failure { const Failure({required FailureKind kind, required List<String> errors, String? message}); }` and `enum FailureKind { validation, unauthorized, forbidden, notFound, conflict, server, network, unknown }`.
  - `class Page<T> { const Page({required List<T> items, required int pageNumber, required int pageSize, required int totalItems, required int totalPages}); }`
  - `Result<T> unwrapData<T>(Map<String, dynamic> json, T Function(Object? data) parse)` and `Result<Page<T>> unwrapPage<T>(Map<String, dynamic> json, T Function(Object? item) parse)`.
  - `Failure failureFromDioException(DioException error)`.

- [ ] **Step 1: Write the failing tests for `Result` and `Failure`**

Create `test/core/result/result_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';

void main() {
  test('GivenSuccess_WhenFolded_ThenSuccessBranchRuns', () {
    // Given
    const Result<int> result = Success<int>(7);

    // When
    final folded = result.fold(
      onSuccess: (value) => 'ok:$value',
      onFailure: (failure) => 'error',
    );

    // Then
    expect(folded, 'ok:7');
    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, 7);
    expect(result.failureOrNull, isNull);
  });

  test('GivenFailure_WhenFolded_ThenFailureBranchCarriesTheErrors', () {
    // Given
    const failure = Failure(
      kind: FailureKind.validation,
      errors: <String>['Name is required'],
    );
    const Result<int> result = FailureResult<int>(failure);

    // When
    final folded = result.fold(
      onSuccess: (value) => 'ok',
      onFailure: (f) => f.errors.join(),
    );

    // Then
    expect(folded, 'Name is required');
    expect(result.isSuccess, isFalse);
    expect(result.valueOrNull, isNull);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/core/result/result_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:heimdall_ui/core/result/result.dart'`.

- [ ] **Step 3: Implement `Result` and `Failure`**

Create `lib/core/result/result.dart`:

```dart
/// The kind of a failure, which determines how the interface reacts to it.
enum FailureKind {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  network,
  unknown,
}

/// A failed outcome, carrying the API's own error messages when it produced any.
class Failure {
  const Failure({required this.kind, required this.errors, this.message});

  final FailureKind kind;
  final List<String> errors;
  final String? message;

  /// The single line worth showing when there is no field to attach errors to.
  String get displayMessage =>
      message ?? (errors.isNotEmpty ? errors.first : 'Something went wrong.');

  @override
  String toString() => 'Failure($kind, $errors, $message)';
}

/// The outcome of an operation that can fail without throwing.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    FailureResult<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    FailureResult<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/core/result/result_test.dart
```

Expected: PASS, two tests.

- [ ] **Step 5: Write the failing tests for envelope unwrapping**

Create `test/core/network/envelope_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/envelope.dart';
import 'package:heimdall_ui/core/result/result.dart';

void main() {
  test('GivenSuccessfulEnvelope_WhenUnwrapped_ThenYieldsTheParsedData', () {
    // Given
    final json = <String, dynamic>{
      'success': true,
      'messages': <String>['Created'],
      'errors': <String>[],
      'data': <String, dynamic>{'name': 'Acme'},
    };

    // When
    final result = unwrapData<String>(
      json,
      (data) => (data! as Map<String, dynamic>)['name']! as String,
    );

    // Then
    expect(result.valueOrNull, 'Acme');
  });

  test('GivenUnsuccessfulEnvelope_WhenUnwrapped_ThenYieldsAValidationFailure', () {
    // Given
    final json = <String, dynamic>{
      'success': false,
      'errors': <String>['Name already exists'],
      'data': null,
    };

    // When
    final result = unwrapData<String>(json, (data) => data! as String);

    // Then
    expect(result.failureOrNull?.kind, FailureKind.validation);
    expect(result.failureOrNull?.errors, <String>['Name already exists']);
  });

  test('GivenPaginatedEnvelope_WhenUnwrapped_ThenCarriesItemsAndPaging', () {
    // Given
    final json = <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <dynamic>[
        <String, dynamic>{'name': 'Acme'},
        <String, dynamic>{'name': 'Globex'},
      ],
      'pageNumber': 1,
      'pageSize': 20,
      'totalItems': 2,
      'totalPages': 1,
    };

    // When
    final result = unwrapPage<String>(
      json,
      (item) => (item! as Map<String, dynamic>)['name']! as String,
    );

    // Then
    final page = result.valueOrNull!;
    expect(page.items, <String>['Acme', 'Globex']);
    expect(page.pageNumber, 1);
    expect(page.totalItems, 2);
  });

  test('GivenUnauthorizedResponse_WhenMapped_ThenFailureKindIsUnauthorized', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/api/scopes'),
        statusCode: 401,
        data: <String, dynamic>{'errors': <String>['Token expired']},
      ),
      type: DioExceptionType.badResponse,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.unauthorized);
    expect(failure.errors, <String>['Token expired']);
  });

  test('GivenConnectionTimeout_WhenMapped_ThenFailureKindIsNetwork', () {
    // Given
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/scopes'),
      type: DioExceptionType.connectionTimeout,
    );

    // When
    final failure = failureFromDioException(error);

    // Then
    expect(failure.kind, FailureKind.network);
  });
}
```

- [ ] **Step 6: Run the tests to verify they fail**

```bash
flutter test test/core/network/envelope_test.dart
```

Expected: FAIL — `envelope.dart` does not exist.

- [ ] **Step 7: Implement envelope unwrapping**

Create `lib/core/network/envelope.dart`:

```dart
import 'package:dio/dio.dart';

import '../result/result.dart';

/// One page of a `PaginatedOutput<T>` response.
class Page<T> {
  const Page({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  bool get hasNextPage => pageNumber < totalPages;
}

List<String> _errorsOf(Map<String, dynamic> json) =>
    (json['errors'] as List<dynamic>? ?? const <dynamic>[])
        .map((error) => error.toString())
        .toList(growable: false);

/// Unwraps a `DataOutput<T>` envelope into a [Result].
Result<T> unwrapData<T>(
  Map<String, dynamic> json,
  T Function(Object? data) parse,
) {
  if (json['success'] != true) {
    return FailureResult<T>(
      Failure(kind: FailureKind.validation, errors: _errorsOf(json)),
    );
  }

  return Success<T>(parse(json['data']));
}

/// Unwraps a `PaginatedOutput<T>` envelope into a [Result] carrying a [Page].
Result<Page<T>> unwrapPage<T>(
  Map<String, dynamic> json,
  T Function(Object? item) parse,
) {
  if (json['success'] != true) {
    return FailureResult<Page<T>>(
      Failure(kind: FailureKind.validation, errors: _errorsOf(json)),
    );
  }

  final data = json['data'] as List<dynamic>? ?? const <dynamic>[];

  return Success<Page<T>>(
    Page<T>(
      items: data.map(parse).toList(growable: false),
      pageNumber: json['pageNumber'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? data.length,
      totalItems: json['totalItems'] as int? ?? data.length,
      totalPages: json['totalPages'] as int? ?? 1,
    ),
  );
}

/// Maps a transport or HTTP failure onto the domain's [Failure] model.
Failure failureFromDioException(DioException error) {
  final response = error.response;

  if (response == null) {
    return Failure(
      kind: switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => FailureKind.network,
        _ => FailureKind.unknown,
      },
      errors: const <String>[],
      message: error.message,
    );
  }

  final body = response.data;
  final errors = body is Map<String, dynamic>
      ? _errorsOf(body)
      : const <String>[];

  return Failure(
    kind: switch (response.statusCode) {
      400 || 422 => FailureKind.validation,
      401 => FailureKind.unauthorized,
      403 => FailureKind.forbidden,
      404 => FailureKind.notFound,
      409 => FailureKind.conflict,
      final int status when status >= 500 => FailureKind.server,
      _ => FailureKind.unknown,
    },
    errors: errors,
  );
}
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
flutter test test/core/network/envelope_test.dart
```

Expected: PASS, five tests.

- [ ] **Step 9: Write the failing test for configuration**

Create `test/core/config/app_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/config/app_config.dart';

void main() {
  test('GivenNoDefine_WhenReadFromEnvironment_ThenFallsBackToLocalhost', () {
    // Given the suite runs without --dart-define

    // When
    final config = AppConfig.fromEnvironment();

    // Then
    expect(config.apiBaseUrl, 'http://localhost:5000');
    expect(config.googleClientId, isNull);
  });

  test('GivenTrailingSlash_WhenConstructed_ThenBaseUrlIsNormalized', () {
    // Given
    const raw = 'https://api.example.com/';

    // When
    const config = AppConfig(apiBaseUrl: raw);

    // Then
    expect(config.apiBaseUrl, 'https://api.example.com');
  });
}
```

- [ ] **Step 10: Run the test to verify it fails**

```bash
flutter test test/core/config/app_config_test.dart
```

Expected: FAIL — `app_config.dart` does not exist.

- [ ] **Step 11: Implement configuration**

Create `lib/core/config/app_config.dart`:

```dart
/// Values supplied at build time with `--dart-define`.
class AppConfig {
  const AppConfig({required String apiBaseUrl, this.googleClientId})
    : _rawApiBaseUrl = apiBaseUrl;

  /// Reads the configuration from the compile-time environment, falling back to
  /// a local API so a developer can run the app with no flags at all.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'HEIMDALL_API_BASE_URL',
      defaultValue: 'http://localhost:5000',
    ),
    googleClientId: bool.hasEnvironment('HEIMDALL_GOOGLE_CLIENT_ID')
        ? const String.fromEnvironment('HEIMDALL_GOOGLE_CLIENT_ID')
        : null,
  );

  final String _rawApiBaseUrl;
  final String? googleClientId;

  /// The API root, without a trailing slash, so paths concatenate predictably.
  String get apiBaseUrl => _rawApiBaseUrl.endsWith('/')
      ? _rawApiBaseUrl.substring(0, _rawApiBaseUrl.length - 1)
      : _rawApiBaseUrl;
}
```

If the `factory` cannot be `const` because of the conditional, replace the body with a non-const
factory that reads both defines into locals first and returns `AppConfig(...)`.

- [ ] **Step 12: Run the gate**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: all pass.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat: add config, result model, and envelope unwrapping"
```

---

## Task 6: Token storage and the session state machine

**Files:**
- Create: `lib/core/storage/token_store.dart`, `lib/features/auth/domain/session.dart`, `lib/features/auth/domain/auth_repository.dart`, `lib/features/auth/presentation/session_controller.dart`
- Test: `test/core/storage/token_store_test.dart`, `test/features/auth/presentation/session_controller_test.dart`

**Interfaces:**
- Consumes: `Result`, `Failure`, `FailureKind` from Task 5.
- Produces:
  - `abstract interface class TokenStore { Future<AuthToken?> read(); Future<void> write(AuthToken token); Future<void> clear(); }`, with `SecureTokenStore` and `InMemoryTokenStore` implementations.
  - `class AuthToken { const AuthToken({required String value, required DateTime expiresAt}); bool get isExpired; }`
  - `class Principal { const Principal({required String id, required String email, required Role role, String? scopeId, List<String> ownedScopeIds}); }` and `enum Role { systemAdmin, scopeAdmin, user }` with `Role roleFromValue(int value)`.
  - `sealed class SessionState` with `Unauthenticated`, `Challenged({required String challengeToken, required List<String> availableMethods})`, `Authenticated({required AuthToken token, required Principal principal})`, and `SessionRestoring`.
  - `abstract interface class AuthRepository { Future<Result<LoginOutcome>> login({required String email, required String password}); Future<Result<AuthToken>> verifySecondFactor({required String challengeToken, required String code}); }`
  - `sealed class LoginOutcome` with `LoggedIn(AuthToken token)` and `TwoFactorRequired({required String challengeToken, required List<String> availableMethods})`.
  - `class SessionController extends Notifier<SessionState>` exposing `Future<Result<void>> signIn({required String email, required String password})`, `Future<Result<void>> submitSecondFactor(String code)`, and `Future<void> signOut()`.

- [ ] **Step 1: Add the storage and state dependencies**

```bash
flutter pub add flutter_riverpod flutter_secure_storage shared_preferences && flutter pub add --dev mocktail
```

- [ ] **Step 2: Write the failing test for the in-memory token store**

Create `test/core/storage/token_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';

void main() {
  test('GivenEmptyStore_WhenRead_ThenReturnsNull', () async {
    // Given
    final store = InMemoryTokenStore();

    // When
    final token = await store.read();

    // Then
    expect(token, isNull);
  });

  test('GivenWrittenToken_WhenRead_ThenReturnsTheSameToken', () async {
    // Given
    final store = InMemoryTokenStore();
    final token = AuthToken(
      value: 'jwt',
      expiresAt: DateTime.utc(2030),
    );

    // When
    await store.write(token);
    final read = await store.read();

    // Then
    expect(read?.value, 'jwt');
    expect(read?.expiresAt, DateTime.utc(2030));
  });

  test('GivenWrittenToken_WhenCleared_ThenReadReturnsNull', () async {
    // Given
    final store = InMemoryTokenStore();
    await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)));

    // When
    await store.clear();

    // Then
    expect(await store.read(), isNull);
  });

  test('GivenPastExpiry_WhenInspected_ThenTokenIsExpired', () {
    // Given
    final token = AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000));

    // When
    final expired = token.isExpired;

    // Then
    expect(expired, isTrue);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

```bash
flutter test test/core/storage/token_store_test.dart
```

Expected: FAIL — `token_store.dart` does not exist.

- [ ] **Step 4: Implement the token store**

Create `lib/core/storage/token_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A bearer token together with the moment it stops being valid.
class AuthToken {
  const AuthToken({required this.value, required this.expiresAt});

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
    value: json['value']! as String,
    expiresAt: DateTime.parse(json['expiresAt']! as String),
  );

  final String value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'value': value,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

/// Where the session token lives between launches.
abstract interface class TokenStore {
  Future<AuthToken?> read();
  Future<void> write(AuthToken token);
  Future<void> clear();
}

/// The store used by tests, which never touches the platform.
class InMemoryTokenStore implements TokenStore {
  AuthToken? _token;

  @override
  Future<AuthToken?> read() async => _token;

  @override
  Future<void> write(AuthToken token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// The production store: Keystore on Android, DPAPI on Windows, libsecret on
/// Linux, and WebCrypto-encrypted local storage on the web.
class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage);

  static const String _key = 'heimdall.session.token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthToken?> read() async {
    final raw = await _storage.read(key: _key);

    if (raw == null) {
      return null;
    }

    return AuthToken.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(AuthToken token) =>
      _storage.write(key: _key, value: jsonEncode(token.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/core/storage/token_store_test.dart
```

Expected: PASS, four tests.

- [ ] **Step 6: Write the failing tests for the session controller**

Create `test/features/auth/presentation/session_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/auth_repository.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repository;
  late InMemoryTokenStore store;

  AuthToken tokenFor(String value) =>
      AuthToken(value: value, expiresAt: DateTime.utc(2030));

  ProviderContainer containerWith() => ProviderContainer(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(repository),
      tokenStoreProvider.overrideWithValue(store),
    ],
  );

  setUp(() {
    repository = _MockAuthRepository();
    store = InMemoryTokenStore();
  });

  test('GivenValidCredentials_WhenSignedIn_ThenSessionIsAuthenticated', () async {
    // Given
    when(
      () => repository.login(email: 'a@b.c', password: 'secret'),
    ).thenAnswer((_) async => Success<LoginOutcome>(LoggedIn(tokenFor('jwt'))));
    final container = containerWith();
    addTearDown(container.dispose);

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'a@b.c', password: 'secret');

    // Then
    final state = container.read(sessionControllerProvider);
    expect(state, isA<Authenticated>());
    expect((await store.read())?.value, 'jwt');
  });

  test('GivenTwoFactorRequired_WhenSignedIn_ThenSessionIsChallenged', () async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        const TwoFactorRequired(
          challengeToken: 'challenge',
          availableMethods: <String>['Totp'],
        ),
      ),
    );
    final container = containerWith();
    addTearDown(container.dispose);

    // When
    await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'a@b.c', password: 'secret');

    // Then
    final state = container.read(sessionControllerProvider);
    expect(state, isA<Challenged>());
    expect((state as Challenged).challengeToken, 'challenge');
    expect(await store.read(), isNull);
  });

  test('GivenChallengedSession_WhenCodeAccepted_ThenSessionIsAuthenticated', () async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'secret')).thenAnswer(
      (_) async => Success<LoginOutcome>(
        const TwoFactorRequired(
          challengeToken: 'challenge',
          availableMethods: <String>['Totp'],
        ),
      ),
    );
    when(
      () => repository.verifySecondFactor(
        challengeToken: 'challenge',
        code: '123456',
      ),
    ).thenAnswer((_) async => Success<AuthToken>(tokenFor('jwt')));
    final container = containerWith();
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.signIn(email: 'a@b.c', password: 'secret');

    // When
    await controller.submitSecondFactor('123456');

    // Then
    expect(container.read(sessionControllerProvider), isA<Authenticated>());
  });

  test('GivenInvalidCredentials_WhenSignedIn_ThenSessionStaysUnauthenticated', () async {
    // Given
    when(() => repository.login(email: 'a@b.c', password: 'wrong')).thenAnswer(
      (_) async => const FailureResult<LoginOutcome>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['Invalid credentials'],
        ),
      ),
    );
    final container = containerWith();
    addTearDown(container.dispose);

    // When
    final result = await container
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'a@b.c', password: 'wrong');

    // Then
    expect(result.isSuccess, isFalse);
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  test('GivenAuthenticatedSession_WhenSignedOut_ThenTokenIsCleared', () async {
    // Given
    when(
      () => repository.login(email: 'a@b.c', password: 'secret'),
    ).thenAnswer((_) async => Success<LoginOutcome>(LoggedIn(tokenFor('jwt'))));
    final container = containerWith();
    addTearDown(container.dispose);
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.signIn(email: 'a@b.c', password: 'secret');

    // When
    await controller.signOut();

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
    expect(await store.read(), isNull);
  });
}
```

- [ ] **Step 7: Run the tests to verify they fail**

```bash
flutter test test/features/auth/presentation/session_controller_test.dart
```

Expected: FAIL — `session.dart`, `auth_repository.dart`, and `session_controller.dart` do not exist.

- [ ] **Step 8: Implement the session domain**

Create `lib/features/auth/domain/session.dart`:

```dart
import '../../../core/storage/token_store.dart';

/// The API's roles, by their stored values.
enum Role {
  systemAdmin(1),
  scopeAdmin(2),
  user(3);

  const Role(this.value);

  final int value;
}

Role roleFromValue(int value) =>
    Role.values.firstWhere((role) => role.value == value, orElse: () => Role.user);

/// Who the session belongs to, as read from the token's claims.
class Principal {
  const Principal({
    required this.id,
    required this.email,
    required this.role,
    this.scopeId,
    this.ownedScopeIds = const <String>[],
  });

  final String id;
  final String email;
  final Role role;
  final String? scopeId;
  final List<String> ownedScopeIds;

  bool get isSystemAdmin => role == Role.systemAdmin;
  bool get isScopeAdmin => role == Role.scopeAdmin;
}

/// Every state the session can be in.
sealed class SessionState {
  const SessionState();
}

/// The session is being restored from storage at start-up.
final class SessionRestoring extends SessionState {
  const SessionRestoring();
}

/// No valid session exists.
final class Unauthenticated extends SessionState {
  const Unauthenticated();
}

/// Credentials were accepted but a second factor is still required. The
/// challenge token is valid for `POST /api/auth/2fa/verify` and nothing else.
final class Challenged extends SessionState {
  const Challenged({
    required this.challengeToken,
    required this.availableMethods,
  });

  final String challengeToken;
  final List<String> availableMethods;
}

/// A usable session.
final class Authenticated extends SessionState {
  const Authenticated({required this.token, required this.principal});

  final AuthToken token;
  final Principal principal;
}
```

- [ ] **Step 9: Implement the auth repository contract**

Create `lib/features/auth/domain/auth_repository.dart`:

```dart
import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';

/// What a login attempt produced.
sealed class LoginOutcome {
  const LoginOutcome();
}

final class LoggedIn extends LoginOutcome {
  const LoggedIn(this.token);

  final AuthToken token;
}

final class TwoFactorRequired extends LoginOutcome {
  const TwoFactorRequired({
    required this.challengeToken,
    required this.availableMethods,
  });

  final String challengeToken;
  final List<String> availableMethods;
}

/// The authentication operations the session depends on. Implemented in
/// `features/auth/data` over the generated client; faked in tests.
abstract interface class AuthRepository {
  Future<Result<LoginOutcome>> login({
    required String email,
    required String password,
  });

  Future<Result<AuthToken>> verifySecondFactor({
    required String challengeToken,
    required String code,
  });
}
```

- [ ] **Step 10: Implement the session controller**

Create `lib/features/auth/presentation/session_controller.dart`. `principalFromToken` decodes the
JWT payload's `sub`/`nameid`, `email`, and `role` claims; when a claim is missing it falls back to
`Role.user` so a malformed token cannot escalate.

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';

/// Overridden at start-up with the platform store, and in tests with a fake.
final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (ref) => throw UnimplementedError('tokenStoreProvider must be overridden'),
);

/// Overridden at start-up with the client-backed implementation.
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider must be overridden'),
);

final NotifierProvider<SessionController, SessionState> sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Reads the principal out of a JWT without verifying it — the API is the only
/// authority on validity; this is for showing the right navigation.
Principal principalFromToken(AuthToken token) {
  final segments = token.value.split('.');

  if (segments.length != 3) {
    return const Principal(id: '', email: '', role: Role.user);
  }

  final payload =
      jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
          )
          as Map<String, dynamic>;

  final rawRole = payload['role'];

  return Principal(
    id: (payload['sub'] ?? payload['nameid'] ?? '').toString(),
    email: (payload['email'] ?? '').toString(),
    role: switch (rawRole) {
      final int value => roleFromValue(value),
      final String value => roleFromValue(int.tryParse(value) ?? Role.user.value),
      _ => Role.user,
    },
    scopeId: payload['scopeId']?.toString(),
    ownedScopeIds:
        (payload['ownedScopeIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((id) => id.toString())
            .toList(growable: false),
  );
}

/// Owns the session state machine: unauthenticated → challenged → authenticated.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    unawaited(_restore());

    return const SessionRestoring();
  }

  TokenStore get _store => ref.read(tokenStoreProvider);
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final stored = await _store.read();

    if (stored == null || stored.isExpired) {
      await _store.clear();
      state = const Unauthenticated();

      return;
    }

    state = Authenticated(token: stored, principal: principalFromToken(stored));
  }

  /// Attempts a password login. A two-factor challenge is not a failure: it
  /// moves the session to [Challenged] and still returns success.
  Future<Result<void>> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _repository.login(email: email, password: password);

    return result.fold(
      onSuccess: (outcome) async {
        switch (outcome) {
          case LoggedIn(:final token):
            await _establish(token);
          case TwoFactorRequired(:final challengeToken, :final availableMethods):
            state = Challenged(
              challengeToken: challengeToken,
              availableMethods: availableMethods,
            );
        }

        return const Success<void>(null);
      },
      onFailure: (failure) async {
        state = const Unauthenticated();

        return FailureResult<void>(failure);
      },
    );
  }

  /// Answers the login challenge. Only valid while the session is [Challenged].
  Future<Result<void>> submitSecondFactor(String code) async {
    final current = state;

    if (current is! Challenged) {
      return const FailureResult<void>(
        Failure(
          kind: FailureKind.unknown,
          errors: <String>['No two-factor challenge is in progress.'],
        ),
      );
    }

    final result = await _repository.verifySecondFactor(
      challengeToken: current.challengeToken,
      code: code,
    );

    return result.fold(
      onSuccess: (token) async {
        await _establish(token);

        return const Success<void>(null);
      },
      onFailure: (failure) async => FailureResult<void>(failure),
    );
  }

  Future<void> signOut() async {
    await _store.clear();
    state = const Unauthenticated();
  }

  Future<void> _establish(AuthToken token) async {
    await _store.write(token);
    state = Authenticated(token: token, principal: principalFromToken(token));
  }
}
```

Note the `fold` calls return futures; declare their return type as `Future<Result<void>>` and `await`
the fold, or restructure with a plain `switch` on the result if the analyzer objects. Import
`dart:async` for `unawaited`.

- [ ] **Step 11: Run the tests to verify they pass**

```bash
flutter test test/features/auth/presentation/session_controller_test.dart
```

Expected: PASS, five tests.

- [ ] **Step 12: Run the gate**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: all pass.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat: add token storage and session state machine"
```

---

## Task 7: Dio client and the authentication interceptor

**Files:**
- Create: `lib/core/network/auth_interceptor.dart`, `lib/core/network/dio_client.dart`, `lib/features/auth/data/auth_repository_impl.dart`
- Test: `test/core/network/auth_interceptor_test.dart`

**Interfaces:**
- Consumes: `AppConfig` (Task 5), `TokenStore`, `AuthToken`, `SessionState` (Task 6), the generated `AuthService` (Task 4).
- Produces:
  - `class AuthInterceptor extends Interceptor { AuthInterceptor({required TokenStore tokenStore, required Future<void> Function() onUnauthorized}); }`
  - `Dio createDio({required AppConfig config, required TokenStore tokenStore, required Future<void> Function() onUnauthorized})`
  - `final Provider<Dio> dioProvider`, `final Provider<AppConfig> appConfigProvider`
  - `class ApiAuthRepository implements AuthRepository { ApiAuthRepository(AuthService service); }`

- [ ] **Step 1: Write the failing tests for the interceptor**

Create `test/core/network/auth_interceptor_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/network/auth_interceptor.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';

void main() {
  late InMemoryTokenStore store;
  late Dio dio;
  late int unauthorizedCalls;

  setUp(() {
    store = InMemoryTokenStore();
    unauthorizedCalls = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..interceptors.add(
        AuthInterceptor(
          tokenStore: store,
          onUnauthorized: () async => unauthorizedCalls++,
        ),
      );
  });

  test('GivenStoredToken_WhenRequestSent_ThenBearerHeaderIsAttached', () async {
    // Given
    await store.write(
      AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
    );
    String? seenHeader;
    dio.httpClientAdapter = _CapturingAdapter((options) {
      seenHeader = options.headers['Authorization'] as String?;

      return 200;
    });

    // When
    await dio.get<dynamic>('/api/scopes');

    // Then
    expect(seenHeader, 'Bearer jwt');
  });

  test('GivenNoToken_WhenRequestSent_ThenNoBearerHeaderIsAttached', () async {
    // Given
    String? seenHeader;
    dio.httpClientAdapter = _CapturingAdapter((options) {
      seenHeader = options.headers['Authorization'] as String?;

      return 200;
    });

    // When
    await dio.get<dynamic>('/api/auth/login');

    // Then
    expect(seenHeader, isNull);
  });

  test('GivenUnauthorizedResponse_WhenReceived_ThenSessionIsCleared', () async {
    // Given
    await store.write(
      AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
    );
    dio.httpClientAdapter = _CapturingAdapter((_) => 401);

    // When
    await expectLater(
      dio.get<dynamic>('/api/scopes'),
      throwsA(isA<DioException>()),
    );

    // Then
    expect(unauthorizedCalls, 1);
  });
}

/// An adapter that answers locally and reports what it was asked for, so no
/// test ever reaches the network.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this._respond);

  final int Function(RequestOptions options) _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"success":true,"errors":[],"data":null}',
    _respond(options),
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/core/network/auth_interceptor_test.dart
```

Expected: FAIL — `auth_interceptor.dart` does not exist.

- [ ] **Step 3: Implement the interceptor**

Create `lib/core/network/auth_interceptor.dart`:

```dart
import 'package:dio/dio.dart';

import '../storage/token_store.dart';

/// Attaches the bearer token to outgoing requests and reacts to a rejected one.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required TokenStore tokenStore, required this.onUnauthorized})
    : _tokenStore = tokenStore;

  final TokenStore _tokenStore;

  /// Called on a 401 so the session can be cleared and the user sent to login.
  final Future<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.read();

    if (token != null && !token.isExpired) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await onUnauthorized();
    }

    handler.next(err);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/core/network/auth_interceptor_test.dart
```

Expected: PASS, three tests.

- [ ] **Step 5: Implement the Dio factory and its providers**

Create `lib/core/network/dio_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

/// Overridden at start-up with the configuration read from the environment.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

/// Builds the single [Dio] every service shares.
Dio createDio({
  required AppConfig config,
  required TokenStore tokenStore,
  required Future<void> Function() onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      // The API answers with an envelope on failures too, so let the
      // repositories read it instead of letting Dio throw on every 4xx.
      validateStatus: (status) => status != null && status < 500,
    ),
  )..interceptors.add(
    AuthInterceptor(tokenStore: tokenStore, onUnauthorized: onUnauthorized),
  );

  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
  }

  return dio;
}
```

Add `dioProvider` in the same file, reading `appConfigProvider` and `tokenStoreProvider` and calling
`ref.read(sessionControllerProvider.notifier).signOut()` as `onUnauthorized`.

- [ ] **Step 6: Implement the API-backed auth repository**

Create `lib/features/auth/data/auth_repository_impl.dart`, implementing `AuthRepository` over the
generated `AuthService`: `login` posts `LoginCommand(email, password)`, unwraps the envelope with
`unwrapData`, and maps `requiresTwoFactor` to `TwoFactorRequired` or the token and `expiresAt` to
`LoggedIn`; `verifySecondFactor` posts to `/api/auth/2fa/verify` with the challenge token and code
and maps the result to an `AuthToken`. Wrap every call in `try`/`on DioException` and convert with
`failureFromDioException`.

- [ ] **Step 7: Run the gate**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add dio client and authentication interceptor"
```

---

## Task 8: Theming

**Files:**
- Create: `lib/app/theme.dart`, `lib/app/theme_mode_controller.dart`
- Test: `test/app/theme_test.dart`, `test/app/theme_mode_controller_test.dart`

**Interfaces:**
- Produces:
  - `ThemeData buildLightTheme()`, `ThemeData buildDarkTheme()`, `const Color heimdallSeedColor`
  - `class ThemeModeController extends AsyncNotifier<ThemeMode>` with `Future<void> setMode(ThemeMode mode)`, exposed as `themeModeControllerProvider`, persisting to `shared_preferences` under `heimdall.theme.mode`.

- [ ] **Step 1: Write the failing test for the themes**

Create `test/app/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme.dart';

void main() {
  test('GivenLightTheme_WhenBuilt_ThenUsesMaterialThreeAndLightBrightness', () {
    // Given / When
    final theme = buildLightTheme();

    // Then
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('GivenDarkTheme_WhenBuilt_ThenUsesMaterialThreeAndDarkBrightness', () {
    // Given / When
    final theme = buildDarkTheme();

    // Then
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });

  test('GivenBothThemes_WhenCompared_ThenTheySpringFromTheSameSeed', () {
    // Given
    final light = buildLightTheme();
    final dark = buildDarkTheme();

    // When
    final differ = light.colorScheme.primary != dark.colorScheme.primary;

    // Then
    expect(differ, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/app/theme_test.dart
```

Expected: FAIL — `theme.dart` does not exist.

- [ ] **Step 3: Implement the themes**

Create `lib/app/theme.dart`:

```dart
import 'package:flutter/material.dart';

/// Heimdall guards the bridge; the palette starts from its watchful blue.
const Color heimdallSeedColor = Color(0xFF1B5E9C);

ThemeData _themeFor(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: heimdallSeedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}

ThemeData buildLightTheme() => _themeFor(Brightness.light);

ThemeData buildDarkTheme() => _themeFor(Brightness.dark);
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/app/theme_test.dart
```

Expected: PASS, three tests.

- [ ] **Step 5: Write the failing test for the persisted mode**

Create `test/app/theme_mode_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('GivenNoStoredPreference_WhenRead_ThenModeIsSystem', () async {
    // Given
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // When
    final mode = await container.read(themeModeControllerProvider.future);

    // Then
    expect(mode, ThemeMode.system);
  });

  test('GivenModeSetToDark_WhenReadAgain_ThenDarkIsRemembered', () async {
    // Given
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeControllerProvider.future);

    // When
    await container
        .read(themeModeControllerProvider.notifier)
        .setMode(ThemeMode.dark);

    // Then
    expect(container.read(themeModeControllerProvider).value, ThemeMode.dark);
    final reread = ProviderContainer();
    addTearDown(reread.dispose);
    expect(await reread.read(themeModeControllerProvider.future), ThemeMode.dark);
  });
}
```

- [ ] **Step 6: Run the test to verify it fails**

```bash
flutter test test/app/theme_mode_controller_test.dart
```

Expected: FAIL — `theme_mode_controller.dart` does not exist.

- [ ] **Step 7: Implement the persisted mode**

Create `lib/app/theme_mode_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AsyncNotifierProvider<ThemeModeController, ThemeMode>
themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

/// Remembers whether the user chose light, dark, or the system's own setting.
class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const String _key = 'heimdall.theme.mode';

  @override
  Future<ThemeMode> build() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_key);

    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, mode.name);
    state = AsyncData<ThemeMode>(mode);
  }
}
```

- [ ] **Step 8: Run the test to verify it passes**

```bash
flutter test test/app/theme_mode_controller_test.dart
```

Expected: PASS, two tests.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add light and dark themes with persisted mode"
```

---

## Task 9: Responsive shell

**Files:**
- Create: `lib/shared/layout/breakpoints.dart`, `lib/shared/layout/adaptive_scaffold.dart`, `lib/shared/layout/destination.dart`
- Test: `test/shared/layout/breakpoints_test.dart`, `test/shared/layout/adaptive_scaffold_test.dart`

**Interfaces:**
- Produces:
  - `enum Breakpoint { compact, medium, expanded }` with `Breakpoint breakpointFor(double width)` and `extension BreakpointContext on BuildContext { Breakpoint get breakpoint; }`
  - `class AppDestination { const AppDestination({required String label, required IconData icon, required String route, required bool Function(Principal) isVisibleTo}); }`
  - `class AdaptiveScaffold extends StatelessWidget { const AdaptiveScaffold({required List<AppDestination> destinations, required int selectedIndex, required ValueChanged<int> onDestinationSelected, required Widget body, Widget? title, List<Widget>? actions}); }`

- [ ] **Step 1: Write the failing test for the breakpoints**

Create `test/shared/layout/breakpoints_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/layout/breakpoints.dart';

void main() {
  test('GivenNarrowWidth_WhenClassified_ThenBreakpointIsCompact', () {
    // Given / When / Then
    expect(breakpointFor(320), Breakpoint.compact);
    expect(breakpointFor(599), Breakpoint.compact);
  });

  test('GivenMediumWidth_WhenClassified_ThenBreakpointIsMedium', () {
    // Given / When / Then
    expect(breakpointFor(600), Breakpoint.medium);
    expect(breakpointFor(1024), Breakpoint.medium);
  });

  test('GivenWideWidth_WhenClassified_ThenBreakpointIsExpanded', () {
    // Given / When / Then
    expect(breakpointFor(1025), Breakpoint.expanded);
    expect(breakpointFor(1920), Breakpoint.expanded);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/shared/layout/breakpoints_test.dart
```

Expected: FAIL — `breakpoints.dart` does not exist.

- [ ] **Step 3: Implement the breakpoints**

Create `lib/shared/layout/breakpoints.dart`:

```dart
import 'package:flutter/widgets.dart';

/// The three window classes the interface adapts to.
enum Breakpoint { compact, medium, expanded }

Breakpoint breakpointFor(double width) => switch (width) {
  < 600 => Breakpoint.compact,
  <= 1024 => Breakpoint.medium,
  _ => Breakpoint.expanded,
};

extension BreakpointContext on BuildContext {
  Breakpoint get breakpoint => breakpointFor(MediaQuery.sizeOf(this).width);
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/shared/layout/breakpoints_test.dart
```

Expected: PASS, three tests.

- [ ] **Step 5: Write the failing widget test for the shell**

Create `test/shared/layout/adaptive_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/shared/layout/adaptive_scaffold.dart';
import 'package:heimdall_ui/shared/layout/destination.dart';

void main() {
  const destinations = <AppDestination>[
    AppDestination(label: 'Scopes', icon: Icons.domain, route: '/scopes'),
    AppDestination(label: 'Persons', icon: Icons.people, route: '/persons'),
  ];

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveScaffold(
          destinations: destinations,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          body: const Text('content'),
        ),
      ),
    );
  }

  testWidgets(
    'GivenCompactWidth_WhenRendered_ThenShowsBottomNavigation',
    (tester) async {
      // Given / When
      await pumpAt(tester, const Size(400, 800));

      // Then
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('content'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenMediumWidth_WhenRendered_ThenShowsCollapsedRail',
    (tester) async {
      // Given / When
      await pumpAt(tester, const Size(800, 800));

      // Then
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'GivenExpandedWidth_WhenRendered_ThenShowsExtendedRail',
    (tester) async {
      // Given / When
      await pumpAt(tester, const Size(1400, 900));

      // Then
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    },
  );

  testWidgets(
    'GivenCompactWidth_WhenDestinationTapped_ThenSelectionIsReported',
    (tester) async {
      // Given
      var selected = -1;
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            destinations: destinations,
            selectedIndex: 0,
            onDestinationSelected: (index) => selected = index,
            body: const Text('content'),
          ),
        ),
      );

      // When
      await tester.tap(find.text('Persons'));
      await tester.pumpAndSettle();

      // Then
      expect(selected, 1);
    },
  );
}
```

- [ ] **Step 6: Run the test to verify it fails**

```bash
flutter test test/shared/layout/adaptive_scaffold_test.dart
```

Expected: FAIL — `adaptive_scaffold.dart` and `destination.dart` do not exist.

- [ ] **Step 7: Implement the destination and the shell**

Create `lib/shared/layout/destination.dart`:

```dart
import 'package:flutter/material.dart';

/// One entry in the application's navigation.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
```

Create `lib/shared/layout/adaptive_scaffold.dart`:

```dart
import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'destination.dart';

/// The application shell: bottom navigation when the window is narrow, a rail
/// when it is not, and an extended rail when there is room for the labels.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.title,
    this.actions,
    super.key,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final breakpoint = context.breakpoint;
    final appBar = (title != null || actions != null)
        ? AppBar(title: title, actions: actions)
        : null;

    if (breakpoint == Breakpoint.compact) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: <Widget>[
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: <Widget>[
          NavigationRail(
            extended: breakpoint == Breakpoint.expanded,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: breakpoint == Breakpoint.expanded
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: <NavigationRailDestination>[
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
flutter test test/shared/layout/adaptive_scaffold_test.dart
```

Expected: PASS, four tests.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add responsive application shell"
```

---

## Task 10: Router, guards, and application entry point

**Files:**
- Create: `lib/app/router.dart`, `lib/app/heimdall_app.dart`, `lib/features/auth/presentation/login_screen.dart`, `lib/features/home/presentation/home_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/app/router_test.dart`, `test/app/heimdall_app_test.dart`

**Interfaces:**
- Consumes: `SessionState`, `Principal`, `Role` (Task 6), `AdaptiveScaffold` (Task 9), themes (Task 8), `AppConfig` (Task 5).
- Produces:
  - `String? redirectFor({required SessionState session, required String location})` — the pure guard, unit-tested without a widget tree.
  - `final Provider<GoRouter> routerProvider`
  - `class HeimdallApp extends ConsumerWidget`
  - `List<AppDestination> destinationsFor(Principal principal)`

- [ ] **Step 1: Add go_router**

```bash
flutter pub add go_router
```

- [ ] **Step 2: Write the failing tests for the guard**

Create `test/app/router_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/router.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/domain/session.dart';

void main() {
  final authenticated = Authenticated(
    token: AuthToken(value: 'jwt', expiresAt: DateTime.utc(2030)),
    principal: const Principal(
      id: 'id',
      email: 'a@b.c',
      role: Role.systemAdmin,
    ),
  );

  test('GivenUnauthenticated_WhenVisitingPrivateRoute_ThenRedirectsToLogin', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(session: session, location: '/scopes');

    // Then
    expect(redirect, '/login?from=%2Fscopes');
  });

  test('GivenUnauthenticated_WhenVisitingLogin_ThenNoRedirect', () {
    // Given
    const session = Unauthenticated();

    // When
    final redirect = redirectFor(session: session, location: '/login');

    // Then
    expect(redirect, isNull);
  });

  test('GivenChallenged_WhenVisitingAnyRoute_ThenRedirectsToTheChallenge', () {
    // Given
    const session = Challenged(
      challengeToken: 'challenge',
      availableMethods: <String>['Totp'],
    );

    // When
    final redirect = redirectFor(session: session, location: '/scopes');

    // Then
    expect(redirect, '/login/two-factor');
  });

  test('GivenAuthenticated_WhenVisitingLogin_ThenRedirectsHome', () {
    // Given / When
    final redirect = redirectFor(session: authenticated, location: '/login');

    // Then
    expect(redirect, '/');
  });

  test('GivenAuthenticated_WhenVisitingPrivateRoute_ThenNoRedirect', () {
    // Given / When
    final redirect = redirectFor(session: authenticated, location: '/scopes');

    // Then
    expect(redirect, isNull);
  });

  test('GivenSessionRestoring_WhenVisitingAnyRoute_ThenNoRedirect', () {
    // Given
    const session = SessionRestoring();

    // When
    final redirect = redirectFor(session: session, location: '/scopes');

    // Then
    expect(redirect, isNull);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
flutter test test/app/router_test.dart
```

Expected: FAIL — `router.dart` does not exist.

- [ ] **Step 4: Implement the guard and the router**

Create `lib/app/router.dart` with the pure guard first:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/session.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/home/presentation/home_screen.dart';

/// Routes an unauthenticated caller may reach.
const Set<String> publicRoutes = <String>{
  '/login',
  '/login/two-factor',
  '/password-recovery',
  '/password-reset',
  '/verify-email',
};

/// Decides where a caller in [session] asking for [location] should end up, or
/// `null` when they may stay. Pure, so the whole guard is unit-testable.
String? redirectFor({
  required SessionState session,
  required String location,
}) {
  final isPublic = publicRoutes.any(
    (route) => location == route || location.startsWith('$route?'),
  );

  return switch (session) {
    SessionRestoring() => null,
    Challenged() =>
      location == '/login/two-factor' ? null : '/login/two-factor',
    Unauthenticated() when isPublic => null,
    Unauthenticated() => '/login?from=${Uri.encodeComponent(location)}',
    Authenticated() when location == '/login' || location == '/login/two-factor' =>
      '/',
    Authenticated() => null,
  };
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => redirectFor(
      session: ref.read(sessionControllerProvider),
      location: state.uri.toString(),
    ),
    refreshListenable: _SessionListenable(ref),
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    ],
  );
});

/// Re-runs the redirect whenever the session changes.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen<SessionState>(
      sessionControllerProvider,
      (_, __) => notifyListeners(),
    );
  }
}
```

Routes for the feature use cases are added by their own issues; only `/` and `/login` exist now.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
flutter test test/app/router_test.dart
```

Expected: PASS, six tests.

- [ ] **Step 6: Implement the placeholder screens**

`lib/features/auth/presentation/login_screen.dart` renders a centred, width-constrained card with
email and password fields and a submit button that calls `signIn`, showing
`failure.displayMessage` in an error banner. It is deliberately minimal — UI-01 completes it.

`lib/features/home/presentation/home_screen.dart` renders `AdaptiveScaffold` with the destinations
`destinationsFor(principal)` returns for the signed-in principal, a body naming the signed-in user,
a theme-mode action in the app bar, and a sign-out action.

`destinationsFor` returns: Scopes, Persons, Applications, Permissions, Google users, and Profile for
a System Admin; the same minus nothing but restricted to owned scopes for a Scope Admin; and Profile
only for a User.

- [ ] **Step 7: Write the failing test for the application root**

Create `test/app/heimdall_app_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/app/heimdall_app.dart';
import 'package:heimdall_ui/core/config/app_config.dart';
import 'package:heimdall_ui/core/network/dio_client.dart';
import 'package:heimdall_ui/core/storage/token_store.dart';
import 'package:heimdall_ui/features/auth/presentation/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'GivenNoSession_WhenAppStarts_ThenLoginScreenIsShown',
    (tester) async {
      // Given
      final container = ProviderContainer(
        overrides: <Override>[
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'https://example.invalid'),
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HeimdallApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Then
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    },
  );
}
```

- [ ] **Step 8: Run the test to verify it fails**

```bash
flutter test test/app/heimdall_app_test.dart
```

Expected: FAIL — `heimdall_app.dart` does not exist.

- [ ] **Step 9: Implement the root widget and the entry point**

`lib/app/heimdall_app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

/// The application root: theme, router, and nothing else.
class HeimdallApp extends ConsumerWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'Heimdall',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

`lib/main.dart` builds the configuration from the environment, constructs the `SecureTokenStore`, and
runs `HeimdallApp` inside a `ProviderScope` that overrides `appConfigProvider`, `tokenStoreProvider`,
and `authRepositoryProvider`.

- [ ] **Step 10: Run the gate**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: all pass.

- [ ] **Step 11: Verify the application actually builds for the web**

```bash
flutter build web --release --dart-define=HEIMDALL_API_BASE_URL=https://api.example.com
```

Expected: `build/web` produced, no errors.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat: add guarded router and application entry point"
```

---

## Task 11: Continuous integration

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/build.yml`, `.github/workflows/check-api-client.yml`

**Interfaces:**
- Consumes: the commands established in Tasks 3, 4, and 10.

- [ ] **Step 1: Write the analyze-and-test workflow**

Create `.github/workflows/ci.yml`, triggered on push to `main` and on pull requests, running on
`ubuntu-latest`: check out, `subosito/flutter-action@v2` pinned to the Flutter version in use with
`channel: stable`, `flutter pub get`, `dart format --output=none --set-exit-if-changed .`,
`flutter analyze`, and `flutter test`.

- [ ] **Step 2: Write the multi-platform build workflow**

Create `.github/workflows/build.yml`, triggered on push to `main` and manually, with a matrix over
`ubuntu-latest` (web and Linux) and `windows-latest` (Windows), plus Android on `ubuntu-latest` with
a JDK 17 step. Each job installs Flutter, runs its `flutter build` command, and uploads the artifact.
The Linux job installs the desktop dependencies first:

```bash
sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

- [ ] **Step 3: Write the client drift workflow**

Create `.github/workflows/check-api-client.yml`, which regenerates the client and fails if the
committed output differs:

```yaml
      - run: dart run swagger_parser
      - run: dart pub get
        working-directory: packages/heimdall_api_client
      - run: dart run build_runner build --delete-conflicting-outputs
        working-directory: packages/heimdall_api_client
      - name: Fail if the generated client is stale
        run: git diff --exit-code -- packages/heimdall_api_client
```

- [ ] **Step 4: Validate the workflow syntax**

```bash
gh workflow list --repo artur-rios/heimdall-ui
```

Expected: after the push in Task 12, the three workflows appear. Before the push, confirm the YAML
parses with any local YAML check available.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows
git commit -m "ci: add analyze, build, and client drift workflows"
```

---

## Task 12: README and delivery tracker

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: the issue numbers from Task 2 and the commands from Tasks 3, 4, 10, and 11.

- [ ] **Step 1: Write the README**

Sections, in this order:

1. **Title and one-line description**, with badges for the CI workflow and the licence.
2. **Overview** — what Heimdall UI is, which API it serves with a link to
   `https://github.com/artur-rios/heimdall-api`, the four supported targets, and the roles it serves.
3. **Project structure** — the table from this plan's File Structure section.
4. **Documentation** — links to each of the seven requirements documents, and to the design
   specification.
5. **Prerequisites** — Flutter 3.44.9 or newer, and per-target requirements: a Chromium-based browser
   for web, Visual Studio with the Desktop development with C++ workload for Windows, the apt
   packages listed in Task 11 for Linux, and the Android SDK with JDK 17 for Android.
6. **Install** — clone, `flutter pub get`, and generating the API client.
7. **Configure** — `HEIMDALL_API_BASE_URL` and `HEIMDALL_GOOGLE_CLIENT_ID` through `--dart-define`,
   with the `--dart-define-from-file` alternative for local development.
8. **Run** — one fenced `bash` block per target.
9. **Test** — `flutter test`, `flutter test integration_test`, the coverage command, and the
   `GivenSomeCondition_WhenSomeAction_ThenSomeOutput` naming rule with a pointer to the Testing
   Specification Document.
10. **Build** — the four release build commands and where each artifact lands.
11. **Use case status** — the tracker.
12. **Legal** — MIT, matching the API's wording.

- [ ] **Step 2: Write the tracker**

Reproduce the API README's shape exactly: the legend line
`**Legend:** ✅ done and merged &nbsp;·&nbsp; 🚧 in progress &nbsp;·&nbsp; ⬜ not started`, then one
table per milestone with `| Use case | Status | Issue |` columns, one row per use case, each linking
its issue by number. All twenty-nine use cases start at ⬜. In the Platform table, `P-01`, `P-02`,
and `P-03` are ✅ because this plan delivers them, and `P-04` is ⬜.

- [ ] **Step 3: Verify every link resolves**

Check each documentation link points at a file that exists, and that each issue link matches the
number recorded in Task 2.

```bash
gh issue list --repo artur-rios/heimdall-ui --limit 50 --json number,title --jq '.[] | "\(.number) \(.title)"'
```

- [ ] **Step 4: Run the full gate one last time**

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Expected: all pass.

- [ ] **Step 5: Commit and push**

```bash
git add README.md
git commit -m "docs: add readme with delivery tracker"
git push -u origin main
```

- [ ] **Step 6: Close the delivered platform issues**

```bash
gh issue close <P-01-number> <P-02-number> <P-03-number> --repo artur-rios/heimdall-ui --comment "Delivered by the foundation plan."
```

---

## Self-Review

**Spec coverage.** Design §2 platforms → Task 3. §3 architecture and boundaries → Tasks 5–10, enforced
by the analyzer configuration and the layer rule in the Global Constraints. §3.4 result and error
model → Task 5. §4 API client → Task 4. §5 session, two-factor, token storage → Tasks 6 and 7. §5.3
Google Sign-In → deferred to UI-06, correctly out of this plan's scope. §6 responsive and theming →
Tasks 8 and 9. §7 testing → every task's test steps, plus the Testing Specification in Task 1. §8
documentation → Task 1. §9 backlog → Task 2. §10 first delivery → Tasks 3–12. §11 constraints →
Global Constraints.

**Placeholders.** Task 1, Task 11, and Task 12 describe documents and configuration files by their
required content rather than reproducing every line — appropriate for prose deliverables, and each
one names its exact sections, identifiers, and commands. Every code deliverable carries real code.

**Type consistency.** `Result`/`Success`/`FailureResult`/`Failure`/`FailureKind` (Task 5) are used
unchanged in Tasks 6, 7, and 10. `AuthToken`/`TokenStore` (Task 6) are consumed by Task 7's
interceptor and Task 10's guard test. `SessionState` variants (`SessionRestoring`, `Unauthenticated`,
`Challenged`, `Authenticated`) are exhaustive in `redirectFor`'s switch. `tokenStoreProvider` and
`authRepositoryProvider` are declared in Task 6 and overridden in Tasks 7 and 10. `AppDestination`
lives in `destination.dart` and is imported by `adaptive_scaffold.dart` in Task 9.

**Known risk.** Task 4 depends on `swagger_parser` handling this specification. Its step 4 stops the
run on failure rather than substituting a hand-written package, because the drift check in Task 11
only means something if generation is reproducible.
