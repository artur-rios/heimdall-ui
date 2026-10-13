# Scope Sign-in Settings and Admin Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an administrator configure a scope's sign-in and sign-up (Google Sign-In, self-registration, email links) from Heimdall UI, resend a second-factor email code at sign-in, and work the outstanding erasure-request queue — all over endpoints Heimdall API 1.4.0 already has.

**Architecture:** Flutter + Riverpod 3 + go_router. Each feature keeps the repo's three layers: `domain/` (entities, repository interface, provider), `data/` (wraps the generated `heimdall_api_client`), `presentation/` (Notifier controllers + screens). Nothing in `presentation/` imports `package:heimdall_api_client`. Three branches, each a PR into `develop`.

**Tech Stack:** Flutter (Dart 3), flutter_riverpod 3, go_router, dio + retrofit-style generated client (`swagger_parser`), mocktail, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-13-scope-sign-in-settings-and-admin-gaps-design.md`

## Global Constraints

- Repository: `D:\Repositories\heimdall-ui`. All paths below are relative to it.
- Test names: `GivenSomeCondition_WhenSomeAction_ThenSomeOutput`; every test body has `// Given`, `// When`, `// Then` comments (merged as `// Given / When` when a step is empty). AF identifiers go in comments, never in test names.
- Every use case covers: main flow, every alternative flow, widget tests at compact (400×900), medium (800×900) and expanded (1400×900), the dark theme (`buildDarkTheme()`), and the API's `errors` shown as returned.
- No test reaches the network: repositories are tested with a stub `HttpClientAdapter`; controllers and screens with mocktail mocks of the domain repository.
- Gate before every commit: `dart format --set-exit-if-changed . && flutter analyze && flutter test` (run the affected test files during TDD; the whole suite before the commit).
- Commit subjects: lowercase Conventional Commits, ≤ 50 characters; every commit ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Stage paths explicitly. Do not push and do not use `gh`.
- Copy is exactly as written in this plan (it comes from the spec).
- Email-link rule: when non-empty after trimming, an `http`/`https` URL with a scheme and a non-empty host, at most 2048 characters; values are sent trimmed, and an empty field is sent as `null`.
- Resend pacing: 30-second cooldown after each send; after the 3rd send for a challenge the control becomes **Start over**.

## Review Focus

1. **A link with a fragment** (`https://app.example.com/#/verify-email`, a hash-routed Flutter web app) must be accepted, as the API accepts it — `Uri.isAbsolute` is false for it, so the validator must not use `isAbsolute`. Pinned in Task 2.
2. **Toggling Google Sign-In must not wipe self-registration or the privacy settings** from the scope on screen: `SetGoogleSignInCommandOutput` carries no `selfRegistrationEnabled`, `defaultLegalBasis` or `privacyNoticeUri`. Pinned in Task 3.
3. **Saving links that did not change** (including whitespace-only edits of an empty field) sends nothing. Pinned in Task 3.
4. **A failed resend** (network) neither counts toward the three sends nor starts the countdown, and a tap during the countdown sends nothing. Pinned in Task 9.
5. **Pasted identifiers in mixed case or repeated** are de-duplicated case-insensitively and the dialog's count reflects the de-duplicated list. Pinned in Task 10.

## File Structure

**Branch 1 — `feature/ui-31-scope-sign-in-settings`** (already exists, holds the spec commit)

| File | Responsibility |
| --- | --- |
| `api/heimdall.json`, `packages/heimdall_api_client/**` | Refreshed spec + regenerated client (Task 1) |
| `lib/features/scopes/domain/scope.dart` | `Scope` gains `selfRegistrationEnabled`, `emailVerificationUrl`, `passwordResetUrl`; merge helpers |
| `lib/features/scopes/domain/email_link.dart` (new) | `validateEmailLink`, `normalizeEmailLink`, `emailLinkMaxLength` |
| `lib/features/scopes/domain/scope_repository.dart` | `setSelfRegistration`, `setEmailLinks` |
| `lib/features/scopes/data/scope_repository_impl.dart` | Their implementations; mapping of the new fields everywhere |
| `lib/features/scopes/presentation/scope_sign_in_settings_controller.dart` (new) | UI-31 state and actions |
| `lib/features/scopes/presentation/scope_sign_in_settings_screen.dart` (new) | UI-31 screen, `signInSettingsSummary` |
| `lib/features/scopes/presentation/scope_detail_controller.dart`, `scope_detail_screen.dart` | Lose the Google Sign-In toggle; the links list gains the new entry with its summary |
| `lib/features/google_users/presentation/google_user_list_screen.dart` | Empty-state action points at the new screen |
| `lib/app/router.dart` | The new route |
| Docs: `docs/requirements/Use Case Specification Document.md`, `docs/requirements/System Requirements Document.md`, `CHANGELOG.md` | UI-31, FR-SC-13/14 |

**Branch 2 — `feature/ui-02-resend-second-factor-code`** (cut from `develop`)

| File | Responsibility |
| --- | --- |
| `lib/features/auth/domain/auth_repository.dart`, `lib/features/auth/data/auth_repository_impl.dart` | `resendSecondFactorCode` |
| `lib/features/auth/presentation/session_controller.dart` | `resendSecondFactorCode()` using the held challenge |
| `lib/features/auth/presentation/two_factor_screen.dart` | The resend control, cooldown, Start over |
| Docs | UI-02 amendment, FR-AU-26, CHANGELOG |

**Branch 3 — `feature/ui-32-erasure-requests`** (cut from `develop`)

| File | Responsibility |
| --- | --- |
| `lib/features/erasure_requests/domain/outstanding_erasure.dart` (new) | `OutstandingErasure`, `ReconciliationOutcome`, `parseSubjectIds` |
| `lib/features/erasure_requests/domain/erasure_request_repository.dart` (new) | Interface + `erasureRequestRepositoryProvider` |
| `lib/features/erasure_requests/data/erasure_request_repository_impl.dart` (new) | Over `AuthClient` |
| `lib/features/erasure_requests/presentation/erasure_request_list_controller.dart`, `erasure_request_list_screen.dart` (new) | The queue |
| `lib/features/erasure_requests/presentation/reconciliation_controller.dart`, `reconciliation_dialog.dart` (new) | Re-apply erasures |
| `lib/main.dart`, `lib/app/router.dart`, `lib/app/route_access.dart`, `lib/features/home/presentation/destinations.dart` | Wiring, route, access, navigation |
| Docs | UI-32, FR-DA-01/02, CHANGELOG |

**Ruling (deviation from spec §7):** the spec cuts branches 2 and 3 after branch 1 merges, assuming they need the refreshed client. They do not: `POST /api/auth/2fa/challenge/resend`, `GET /api/auth/erasure-requests` and `POST /api/auth/erasure-reconciliation` are already in the committed `api/heimdall.json` (only `/api/auth/register`, `/self-registration` and `/email-links` are missing). So branches 2 and 3 are cut from `develop` now. Cost if wrong: none to code; the three PRs touch the same docs and CHANGELOG `[Unreleased]`, so whichever merges later resolves a small text conflict.

---

## Branch 1 — `feature/ui-31-scope-sign-in-settings`

Before Task 1: `git switch feature/ui-31-scope-sign-in-settings` (it already holds the spec commit `a609b9b` and this plan).

### Task 1: Refresh the API specification and regenerate the client

**Files:**
- Modify: `api/heimdall.json`
- Modify: `packages/heimdall_api_client/lib/**` (generated)

**Interfaces:**
- Produces (generated, used by Task 2): `ScopeClient.scopeSetSelfRegistration({required String id, SetSelfRegistrationCommand? body})` → `Future<SetSelfRegistrationCommandOutputDataOutput>`; `ScopeClient.scopeSetEmailLinks({required String id, SetScopeEmailLinksCommand? body})` → `Future<SetScopeEmailLinksCommandOutputDataOutput>`; `SetSelfRegistrationCommand({bool? enabled})`; `SetScopeEmailLinksCommand({String? emailVerificationUrl, String? passwordResetUrl})`; `ScopeOutput`, `CreateScopeCommandOutput`, `UpdateScopeCommandOutput`, `SetSelfRegistrationCommandOutput`, `SetScopeEmailLinksCommandOutput` gain `selfRegistrationEnabled`, `emailVerificationUrl`, `passwordResetUrl` (`SetGoogleSignInCommandOutput` gains only the two URLs).

- [ ] **Step 1: Confirm the API source is the released 1.4.0 spec**

Run: `git -C ../heimdall-api log -1 --format=%H%n%s origin/main -- docs/openapi/heimdall.json` and `git -C ../heimdall-api show origin/main:docs/openapi/heimdall.json > "$TMP/heimdall-1.4.0.json"` (use the scratch dir), then check it has the new paths:

```bash
grep -c '"/api/scopes/{id}/email-links"\|"/api/scopes/{id}/self-registration"\|"/api/auth/register"' "$TMP/heimdall-1.4.0.json"
```

Expected: `3`.

- [ ] **Step 2: Refresh and regenerate**

```bash
dart run tool/refresh_openapi.dart "$TMP/heimdall-1.4.0.json"
dart run tool/generate_api_client.dart
```

Expected: `api/heimdall.json` changes; new files `packages/heimdall_api_client/lib/models/set_self_registration_command*.dart`, `set_scope_email_links_command*.dart`, `register_command*.dart` appear; `scope_client.dart` gains the two methods.

- [ ] **Step 3: Verify nothing else broke**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
Expected: all pass (no hand-written code uses the new fields yet; regenerated nullable fields are additive).

- [ ] **Step 4: Commit**

```bash
git add api/heimdall.json packages/heimdall_api_client
git commit -m "chore: refresh the api client for heimdall 1.4.0" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Scope settings in the domain and the repository

**Files:**
- Modify: `lib/features/scopes/domain/scope.dart`
- Create: `lib/features/scopes/domain/email_link.dart`
- Modify: `lib/features/scopes/domain/scope_repository.dart`
- Modify: `lib/features/scopes/data/scope_repository_impl.dart`
- Test: `test/features/scopes/domain/email_link_test.dart` (new), `test/features/scopes/domain/scope_test.dart` (new), `test/features/scopes/data/scope_repository_impl_test.dart`

**Interfaces:**
- Consumes: Task 1's generated client.
- Produces:
  - `Scope` fields `bool selfRegistrationEnabled` (default `false`), `String? emailVerificationUrl`, `String? passwordResetUrl`; getter `bool hasCustomEmailLinks`; `Scope withPrivacySettingsOf(Scope other)` (now also keeps `this`'s new fields); `Scope withSelfRegistrationOf(Scope other)`.
  - `const int emailLinkMaxLength = 2048;` `String? validateEmailLink(String? value)`; `String? normalizeEmailLink(String? value)`.
  - `ScopeRepository.setSelfRegistration({required String id, required bool enabled})` → `Future<Result<Scope>>`; `ScopeRepository.setEmailLinks({required String id, required String? emailVerificationUrl, required String? passwordResetUrl})` → `Future<Result<Scope>>`.

- [ ] **Step 1: Write the failing validator tests**

`test/features/scopes/domain/email_link_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/scopes/domain/email_link.dart';

void main() {
  test('GivenAnHttpsLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final error = validateEmailLink('https://app.example.com/verify-email');

    // Then
    expect(error, isNull);
  });

  test('GivenAnHttpLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final error = validateEmailLink('http://localhost:8080/verify-email');

    // Then
    expect(error, isNull);
  });

  test('GivenAHashRoutedLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final error = validateEmailLink('https://app.example.com/#/verify-email');

    // Then
    expect(error, isNull);
  });

  test('GivenAnEmptyOrBlankLink_WhenValidated_ThenItIsAccepted', () {
    // Given / When
    final errors = <String?>[
      validateEmailLink(null),
      validateEmailLink(''),
      validateEmailLink('   '),
    ];

    // Then
    expect(errors, everyElement(isNull));
  });

  test('GivenARelativePath_WhenValidated_ThenItIsRefused', () {
    // Given / When
    final error = validateEmailLink('/verify-email');

    // Then
    expect(error, 'Enter a full link starting with https:// or http://.');
  });

  test('GivenAnotherScheme_WhenValidated_ThenItIsRefused', () {
    // Given / When
    final error = validateEmailLink('ftp://app.example.com/verify-email');

    // Then
    expect(error, 'Enter a full link starting with https:// or http://.');
  });

  test('GivenALinkWithoutAHost_WhenValidated_ThenItIsRefused', () {
    // Given / When
    final error = validateEmailLink('https:///verify-email');

    // Then
    expect(error, 'Enter a full link starting with https:// or http://.');
  });

  test('GivenALinkOverTheLimit_WhenValidated_ThenItIsRefused', () {
    // Given
    final link = 'https://app.example.com/${'a' * 2030}';

    // When
    final error = validateEmailLink(link);

    // Then
    expect(link.length, greaterThan(emailLinkMaxLength));
    expect(error, 'Use at most 2048 characters.');
  });

  test('GivenSurroundingSpaces_WhenNormalized_ThenTheyAreTrimmed', () {
    // Given / When
    final link = normalizeEmailLink('  https://app.example.com/x  ');

    // Then
    expect(link, 'https://app.example.com/x');
  });

  test('GivenABlankLink_WhenNormalized_ThenItIsNull', () {
    // Given / When
    final link = normalizeEmailLink('   ');

    // Then
    expect(link, isNull);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/scopes/domain/email_link_test.dart`
Expected: FAIL — `email_link.dart` does not exist.

- [ ] **Step 3: Write the validator**

`lib/features/scopes/domain/email_link.dart`:

```dart
/// The base links a scope's emails point at (UI-31): mirrored from the API's
/// `SetScopeEmailLinksCommandValidator`, so the form refuses what the API
/// would. The API stays the authority; this only spares the round trip.
library;

/// The longest link the API stores.
const int emailLinkMaxLength = 2048;

/// Why [value] is not a usable link, or `null` when it is — an empty one
/// included, since an empty link is a clear, not an error.
///
/// Deliberately not `Uri.isAbsolute`: that is false for a link with a
/// fragment, and a hash-routed web application's screens are exactly such
/// links (`https://app.example.com/#/verify-email`). The API accepts them.
String? validateEmailLink(String? value) {
  final link = value?.trim() ?? '';

  if (link.isEmpty) {
    return null;
  }

  if (link.length > emailLinkMaxLength) {
    return 'Use at most $emailLinkMaxLength characters.';
  }

  final uri = Uri.tryParse(link);
  final usable =
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;

  return usable ? null : 'Enter a full link starting with https:// or http://.';
}

/// [value] as it is sent: trimmed, and `null` when nothing is left, which the
/// API reads as "clear this link".
String? normalizeEmailLink(String? value) {
  final link = value?.trim() ?? '';

  return link.isEmpty ? null : link;
}
```

- [ ] **Step 4: Run the validator tests**

Run: `flutter test test/features/scopes/domain/email_link_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing `Scope` tests**

`test/features/scopes/domain/scope_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';

const _known = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  selfRegistrationEnabled: true,
  defaultLegalBasis: 2,
  privacyNoticeUri: 'https://acme.example/privacy',
  emailVerificationUrl: 'https://acme.example/verify-email',
);

const _fromToggle = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  emailVerificationUrl: 'https://acme.example/verify-email',
);

void main() {
  test('GivenATogglesAnswer_WhenMergedWithTheKnownScope_ThenPrivacyIsKept', () {
    // Given / When
    final merged = _fromToggle.withPrivacySettingsOf(_known);

    // Then
    expect(merged.defaultLegalBasis, 2);
    expect(merged.privacyNoticeUri, 'https://acme.example/privacy');
    expect(merged.googleSignInEnabled, isTrue);
    expect(merged.emailVerificationUrl, 'https://acme.example/verify-email');
  });

  test('GivenATogglesAnswer_WhenMergedWithTheKnownScope_ThenSignUpIsKept', () {
    // Given / When
    final merged = _fromToggle.withSelfRegistrationOf(_known);

    // Then
    expect(merged.selfRegistrationEnabled, isTrue);
    expect(merged.googleSignInEnabled, isTrue);
  });

  test('GivenEitherLink_WhenAsked_ThenTheLinksAreCustom', () {
    // Given / When / Then
    expect(_known.hasCustomEmailLinks, isTrue);
    expect(
      const Scope(id: 'x', name: 'x', description: '').hasCustomEmailLinks,
      isFalse,
    );
  });
}
```

- [ ] **Step 6: Run them to see them fail**

Run: `flutter test test/features/scopes/domain/scope_test.dart`
Expected: FAIL — no `selfRegistrationEnabled` named parameter.

- [ ] **Step 7: Extend `Scope`**

In `lib/features/scopes/domain/scope.dart`, add the three constructor parameters after `googleSignInEnabled`:

```dart
    this.selfRegistrationEnabled = false,
    this.emailVerificationUrl,
    this.passwordResetUrl,
```

the fields after `googleSignInEnabled`:

```dart
  /// Whether people may create their own account in this scope (UC-47).
  /// UI-31 toggles it.
  final bool selfRegistrationEnabled;

  /// Where this scope's verification and sign-up confirmation emails link to,
  /// or `null` for Heimdall's default. UI-31 sets it.
  final String? emailVerificationUrl;

  /// Where this scope's password-reset emails link to, or `null` for
  /// Heimdall's default. UI-31 sets it.
  final String? passwordResetUrl;
```

the getter after `ownerCount`:

```dart
  /// Whether either email link overrides Heimdall's default.
  bool get hasCustomEmailLinks =>
      emailVerificationUrl != null || passwordResetUrl != null;
```

and replace `withPrivacySettingsOf` with these two methods:

```dart
  /// This scope, with the privacy settings of [other].
  ///
  /// The update, Google Sign-In, self-registration and email-links endpoints
  /// answer with outputs that do not carry those settings, so the record the
  /// API returns from them is merged with the one already known rather than
  /// read as having none.
  Scope withPrivacySettingsOf(Scope other) => Scope(
    id: id,
    name: name,
    description: description,
    googleSignInEnabled: googleSignInEnabled,
    selfRegistrationEnabled: selfRegistrationEnabled,
    emailVerificationUrl: emailVerificationUrl,
    passwordResetUrl: passwordResetUrl,
    defaultLegalBasis: other.defaultLegalBasis,
    privacyNoticeUri: other.privacyNoticeUri,
    isDeleted: isDeleted,
    ownerIds: ownerIds,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// This scope, with the self-registration state of [other].
  ///
  /// The Google Sign-In endpoint's output does not carry it, so its answer is
  /// merged with the scope already known rather than read as "closed".
  Scope withSelfRegistrationOf(Scope other) => Scope(
    id: id,
    name: name,
    description: description,
    googleSignInEnabled: googleSignInEnabled,
    selfRegistrationEnabled: other.selfRegistrationEnabled,
    emailVerificationUrl: emailVerificationUrl,
    passwordResetUrl: passwordResetUrl,
    defaultLegalBasis: defaultLegalBasis,
    privacyNoticeUri: privacyNoticeUri,
    isDeleted: isDeleted,
    ownerIds: ownerIds,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
```

Update the `googleSignInEnabled` doc comment from "UI-15 toggles it." to "UI-15 toggles it, on UI-31's screen."

- [ ] **Step 8: Run the `Scope` tests**

Run: `flutter test test/features/scopes/domain/scope_test.dart`
Expected: PASS.

- [ ] **Step 9: Write the failing repository tests**

Append to `test/features/scopes/data/scope_repository_impl_test.dart`, inside `main()` (the file already has `repositoryAnswering`, `_Answer`, `_StubAdapter` with `bodies`):

```dart
  const signUpOpened = _Answer(
    status: 200,
    body: <String, dynamic>{
      'success': true,
      'errors': <String>[],
      'data': <String, dynamic>{
        'id': 'scope-1',
        'name': 'Acme',
        'description': 'The first tenant',
        'googleSignInEnabled': false,
        'selfRegistrationEnabled': true,
        'emailVerificationUrl': 'https://acme.example/verify-email',
        'passwordResetUrl': null,
        'ownerIds': <String>['person-1'],
      },
    },
  );

  test('GivenScopeSettings_WhenRead_ThenTheyAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'scope-1',
            'name': 'Acme',
            'description': 'The first tenant',
            'selfRegistrationEnabled': true,
            'emailVerificationUrl': 'https://acme.example/verify-email',
            'passwordResetUrl': 'https://acme.example/password-reset',
          },
        },
      ),
    );

    // When
    final result = await repository.getById('scope-1');

    // Then
    final scope = result.valueOrNull!;
    expect(scope.selfRegistrationEnabled, isTrue);
    expect(scope.emailVerificationUrl, 'https://acme.example/verify-email');
    expect(scope.passwordResetUrl, 'https://acme.example/password-reset');
  });

  test('GivenAnEmptyLinkFromTheApi_WhenRead_ThenItIsNoLink', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'id': 'scope-1',
            'name': 'Acme',
            'description': '',
            'emailVerificationUrl': '',
          },
        },
      ),
    );

    // When
    final result = await repository.getById('scope-1');

    // Then
    expect(result.valueOrNull!.emailVerificationUrl, isNull);
  });

  test('GivenSelfRegistration_WhenOpened_ThenTheBodySaysSo', () async {
    // Given
    final repository = repositoryAnswering(signUpOpened);

    // When
    await repository.setSelfRegistration(id: 'scope-1', enabled: true);

    // Then
    expect(adapter.bodies.single, <String, dynamic>{'enabled': true});
  });

  test('GivenSelfRegistration_WhenOpened_ThenTheScopeIsReturned', () async {
    // Given
    final repository = repositoryAnswering(signUpOpened);

    // When
    final result = await repository.setSelfRegistration(
      id: 'scope-1',
      enabled: true,
    );

    // Then
    expect(result.valueOrNull!.selfRegistrationEnabled, isTrue);
    expect(
      result.valueOrNull!.emailVerificationUrl,
      'https://acme.example/verify-email',
    );
  });

  test('GivenARefusedSelfRegistration_WhenSet_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 403,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['You do not own this scope.'],
        },
      ),
    );

    // When
    final result = await repository.setSelfRegistration(
      id: 'scope-1',
      enabled: true,
    );

    // Then
    expect(result.failureOrNull!.kind, FailureKind.forbidden);
    expect(result.failureOrNull!.errors, <String>['You do not own this scope.']);
  });

  test('GivenEmailLinks_WhenSet_ThenBothTravelInTheBody', () async {
    // Given
    final repository = repositoryAnswering(signUpOpened);

    // When
    await repository.setEmailLinks(
      id: 'scope-1',
      emailVerificationUrl: 'https://acme.example/verify-email',
      passwordResetUrl: null,
    );

    // Then
    expect(adapter.bodies.single, <String, dynamic>{
      'emailVerificationUrl': 'https://acme.example/verify-email',
      'passwordResetUrl': null,
    });
  });

  test('GivenRefusedEmailLinks_WhenSet_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['The email link must be an absolute URL.'],
        },
      ),
    );

    // When
    final result = await repository.setEmailLinks(
      id: 'scope-1',
      emailVerificationUrl: 'nope',
      passwordResetUrl: null,
    );

    // Then
    expect(result.failureOrNull!.kind, FailureKind.validation);
    expect(result.failureOrNull!.errors, <String>[
      'The email link must be an absolute URL.',
    ]);
  });

  test('GivenNoConnection_WhenEmailLinksSet_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.setEmailLinks(
      id: 'scope-1',
      emailVerificationUrl: null,
      passwordResetUrl: null,
    );

    // Then
    expect(result.failureOrNull!.kind, FailureKind.network);
  });
```

Note: if the generated `SetScopeEmailLinksCommand.toJson` omits null fields (`includeIfNull: false`), the API still reads an absent link as cleared, but the body-assertion test above must then expect `<String, dynamic>{'emailVerificationUrl': 'https://acme.example/verify-email'}`. Check `packages/heimdall_api_client/lib/models/set_scope_email_links_command.g.dart` and assert what it actually sends; record the observation in the report.

- [ ] **Step 10: Run them to see them fail**

Run: `flutter test test/features/scopes/data/scope_repository_impl_test.dart`
Expected: FAIL — `setSelfRegistration` / `setEmailLinks` not defined; mapping test fails.

- [ ] **Step 11: Add the interface methods**

In `lib/features/scopes/domain/scope_repository.dart`, after `setGoogleSignIn`:

```dart
  /// Opens or closes self-registration for a scope (UC-47 toggle).
  ///
  /// Returns the scope as the API now holds it, so the control settles on the
  /// confirmed state rather than on the one it was moved to.
  Future<Result<Scope>> setSelfRegistration({
    required String id,
    required bool enabled,
  });

  /// Sets the links the scope's verification and password-reset emails point
  /// at. Both are sent every time: the API treats the body as the whole state,
  /// so a link left out — or `null` — is cleared and Heimdall's default
  /// applies again.
  Future<Result<Scope>> setEmailLinks({
    required String id,
    required String? emailVerificationUrl,
    required String? passwordResetUrl,
  });
```

- [ ] **Step 12: Implement them and map the new fields**

In `lib/features/scopes/data/scope_repository_impl.dart`:

1. Add the helper at the bottom of the file, next to `scopeFromOutput`:

```dart
/// An empty link is no link: the API clears one sent empty, and the screen
/// should not show a blank override as if one were set.
String? _link(String? value) =>
    (value == null || value.trim().isEmpty) ? null : value;
```

2. In `scopeFromOutput`, after `googleSignInEnabled:` add:

```dart
  selfRegistrationEnabled: output.selfRegistrationEnabled ?? false,
  emailVerificationUrl: _link(output.emailVerificationUrl),
  passwordResetUrl: _link(output.passwordResetUrl),
```

3. In `create` and `update`, add the same three lines (reading `data.` instead of `output.`) after `googleSignInEnabled:`. In `setGoogleSignIn`, add only the two link lines (its output has no `selfRegistrationEnabled`; the controller merges it — Task 3).

4. Add the two methods after `setGoogleSignIn`:

```dart
  @override
  Future<Result<Scope>> setSelfRegistration({
    required String id,
    required bool enabled,
  }) async {
    try {
      final response = await _client.scopeSetSelfRegistration(
        id: id,
        body: SetSelfRegistrationCommand(enabled: enabled),
      );

      if (response.success != true) {
        return FailureResult<Scope>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Scope>(_incompleteResponse);
      }

      // Its output carries no privacy settings and no `isDeleted`: the API
      // refuses a deleted scope, and the controller keeps the privacy
      // settings it already knows.
      return Success<Scope>(
        Scope(
          id: data.id ?? id,
          name: data.name ?? '',
          description: data.description ?? '',
          googleSignInEnabled: data.googleSignInEnabled ?? false,
          selfRegistrationEnabled: data.selfRegistrationEnabled ?? enabled,
          emailVerificationUrl: _link(data.emailVerificationUrl),
          passwordResetUrl: _link(data.passwordResetUrl),
          ownerIds: data.ownerIds ?? const <String>[],
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Scope>(failureFromDioException(error));
    }
  }

  @override
  Future<Result<Scope>> setEmailLinks({
    required String id,
    required String? emailVerificationUrl,
    required String? passwordResetUrl,
  }) async {
    try {
      final response = await _client.scopeSetEmailLinks(
        id: id,
        body: SetScopeEmailLinksCommand(
          emailVerificationUrl: emailVerificationUrl,
          passwordResetUrl: passwordResetUrl,
        ),
      );

      if (response.success != true) {
        return FailureResult<Scope>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      final data = response.data;

      if (data == null) {
        return const FailureResult<Scope>(_incompleteResponse);
      }

      return Success<Scope>(
        Scope(
          id: data.id ?? id,
          name: data.name ?? '',
          description: data.description ?? '',
          googleSignInEnabled: data.googleSignInEnabled ?? false,
          selfRegistrationEnabled: data.selfRegistrationEnabled ?? false,
          emailVerificationUrl: _link(data.emailVerificationUrl),
          passwordResetUrl: _link(data.passwordResetUrl),
          ownerIds: data.ownerIds ?? const <String>[],
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        ),
      );
    } on DioException catch (error) {
      return FailureResult<Scope>(failureFromDioException(error));
    }
  }
```

If the generated model or method names differ from these (check `scope_client.dart` after Task 1), use the generated names and note it in the report.

5. `ScopeDetailController.setGoogleSignIn` must keep self-registration: change its `onSuccess` to

```dart
      onSuccess: (scope) => current.copyWith(
        scope: scope
            .withPrivacySettingsOf(current.scope)
            .withSelfRegistrationOf(current.scope),
        togglingGoogleSignIn: false,
      ),
```

(This controller loses the toggle in Task 5; until then it must not drop the field.)

6. Every other `ScopeRepository` implementation in `test/` (mocktail mocks need nothing; any hand-written fake must gain the two methods) — run `grep -rn "implements ScopeRepository" test lib` and update each.

- [ ] **Step 13: Run the scope tests**

Run: `flutter test test/features/scopes`
Expected: PASS.

- [ ] **Step 14: Gate and commit**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
Expected: PASS.

```bash
git add lib/features/scopes/domain/scope.dart lib/features/scopes/domain/email_link.dart lib/features/scopes/domain/scope_repository.dart lib/features/scopes/data/scope_repository_impl.dart lib/features/scopes/presentation/scope_detail_controller.dart test/features/scopes/domain test/features/scopes/data/scope_repository_impl_test.dart
git commit -m "feat: read and set scope sign-up settings" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Add any fake you updated in step 12.6 to the `git add`.)

---

### Task 3: The sign-in settings controller

**Files:**
- Create: `lib/features/scopes/presentation/scope_sign_in_settings_controller.dart`
- Test: `test/features/scopes/presentation/scope_sign_in_settings_controller_test.dart`

**Interfaces:**
- Consumes: `scopeRepositoryProvider` (`lib/features/scopes/presentation/scope_list_controller.dart`), `ScopeRepository.getById/setGoogleSignIn/setSelfRegistration/setEmailLinks`, `Scope.withPrivacySettingsOf/withSelfRegistrationOf`, `normalizeEmailLink`.
- Produces:
  - `enum SignInSettingsAction { googleSignIn, selfRegistration, emailLinks }`
  - `sealed class SignInSettingsState`; `SignInSettingsLoading`; `SignInSettingsUnavailable(Failure failure)` with `isNotFound`, `isForbidden`; `SignInSettingsLoaded(Scope scope, {SignInSettingsAction? inFlight, Failure? googleSignInFailure, Failure? selfRegistrationFailure, Failure? linksFailure, bool linksSaved = false})` with `bool get isBusy`, `bool get isReadOnly`.
  - `scopeSignInSettingsControllerProvider` — `NotifierProvider.family<ScopeSignInSettingsController, SignInSettingsState, String>`.
  - `ScopeSignInSettingsController`: `Future<void> load()`, `Future<void> setGoogleSignIn(bool enabled)`, `Future<void> setSelfRegistration(bool enabled)`, `Future<void> saveEmailLinks({required String? emailVerificationUrl, required String? passwordResetUrl})`, `void acknowledgeLinks()`.

- [ ] **Step 1: Write the failing tests**

`test/features/scopes/presentation/scope_sign_in_settings_controller_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/core/result/result.dart';
import 'package:heimdall_ui/features/scopes/domain/scope.dart';
import 'package:heimdall_ui/features/scopes/domain/scope_repository.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_list_controller.dart';
import 'package:heimdall_ui/features/scopes/presentation/scope_sign_in_settings_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockScopeRepository extends Mock implements ScopeRepository {}

const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  selfRegistrationEnabled: true,
  defaultLegalBasis: 2,
  privacyNoticeUri: 'https://acme.example/privacy',
  emailVerificationUrl: 'https://acme.example/verify-email',
);

/// What the Google Sign-In endpoint answers: no self-registration, no privacy.
const _toggledOn = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  emailVerificationUrl: 'https://acme.example/verify-email',
);

const _deleted = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  isDeleted: true,
);

const _refused = Failure(
  kind: FailureKind.forbidden,
  errors: <String>['You do not own this scope.'],
);

void main() {
  late _MockScopeRepository repository;
  late ProviderContainer container;

  ScopeSignInSettingsController controllerUnderTest() {
    container = ProviderContainer(
      overrides: <Override>[
        scopeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    return container.read(
      scopeSignInSettingsControllerProvider('scope-1').notifier,
    );
  }

  SignInSettingsState currentState() =>
      container.read(scopeSignInSettingsControllerProvider('scope-1'));

  SignInSettingsLoaded loaded() => currentState() as SignInSettingsLoaded;

  void answerGetWith(Result<Scope> result) {
    when(
      () => repository.getById(any(), includeDeleted: any(named: 'includeDeleted')),
    ).thenAnswer((_) async => result);
  }

  void answerGoogleWith(Result<Scope> result) {
    when(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerSignUpWith(Result<Scope> result) {
    when(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) async => result);
  }

  void answerLinksWith(Result<Scope> result) {
    when(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    repository = _MockScopeRepository();
  });

  test('GivenAScope_WhenLoaded_ThenItsSettingsAreShown', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(loaded().scope.selfRegistrationEnabled, isTrue);
  });

  // AF-31a
  test('GivenAMissingScope_WhenLoaded_ThenStateIsNotFound', () async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect((currentState() as SignInSettingsUnavailable).isNotFound, isTrue);
  });

  // AF-31b
  test('GivenADeletedScope_WhenLoaded_ThenItIsReadOnly', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();

    // When
    await controller.load();

    // Then
    expect(loaded().isReadOnly, isTrue);
  });

  test('GivenADeletedScope_WhenSignUpOpened_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_deleted));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setSelfRegistration(true);

    // Then
    verifyNever(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  test('GivenGoogleOff_WhenTurnedOn_ThenSignUpAndPrivacyAreKept', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerGoogleWith(const Success<Scope>(_toggledOn));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setGoogleSignIn(true);

    // Then
    final scope = loaded().scope;
    expect(scope.googleSignInEnabled, isTrue);
    expect(scope.selfRegistrationEnabled, isTrue);
    expect(scope.defaultLegalBasis, 2);
    expect(scope.privacyNoticeUri, 'https://acme.example/privacy');
  });

  test('GivenSignUpOn_WhenClosed_ThenTheApiIsAskedAndTheStateSettles', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerSignUpWith(
      const Success<Scope>(
        Scope(id: 'scope-1', name: 'Acme', description: 'The first tenant'),
      ),
    );
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setSelfRegistration(false);

    // Then
    verify(
      () => repository.setSelfRegistration(id: 'scope-1', enabled: false),
    ).called(1);
    expect(loaded().scope.selfRegistrationEnabled, isFalse);
    expect(loaded().scope.privacyNoticeUri, 'https://acme.example/privacy');
    expect(loaded().isBusy, isFalse);
  });

  // AF-31c
  test('GivenARefusedSignUpToggle_WhenAttempted_ThenTheStateIsUnchanged', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerSignUpWith(const FailureResult<Scope>(_refused));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setSelfRegistration(false);

    // Then
    expect(loaded().scope.selfRegistrationEnabled, isTrue);
    expect(loaded().selfRegistrationFailure, same(_refused));
  });

  test('GivenARequestInFlight_WhenAnotherIsAsked_ThenOnlyOneIsSent', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final pending = Completer<Result<Scope>>();
    when(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = controllerUnderTest();
    await controller.load();

    // When
    final first = controller.setSelfRegistration(false);
    await controller.setGoogleSignIn(true);
    pending.complete(const Success<Scope>(_acme));
    await first;

    // Then
    verifyNever(
      () => repository.setGoogleSignIn(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  test('GivenChangedLinks_WhenSaved_ThenBothAreSentTrimmed', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: '  https://acme.example/verify-email  ',
      passwordResetUrl: ' https://acme.example/password-reset ',
    );

    // Then
    verify(
      () => repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: 'https://acme.example/verify-email',
        passwordResetUrl: 'https://acme.example/password-reset',
      ),
    ).called(1);
    expect(loaded().linksSaved, isTrue);
  });

  test('GivenAnEmptiedLink_WhenSaved_ThenItIsSentAsNull', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: '   ',
      passwordResetUrl: null,
    );

    // Then
    verify(
      () => repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: null,
        passwordResetUrl: null,
      ),
    ).called(1);
  });

  test('GivenUnchangedLinks_WhenSaved_ThenNoRequestIsMade', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: ' https://acme.example/verify-email ',
      passwordResetUrl: '   ',
    );

    // Then
    verifyNever(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    );
  });

  // AF-31d
  test('GivenRefusedLinks_WhenSaved_ThenApiErrorsAreKept', () async {
    // Given
    const refusal = Failure(
      kind: FailureKind.validation,
      errors: <String>['The email link must be an absolute URL.'],
    );
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const FailureResult<Scope>(refusal));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.saveEmailLinks(
      emailVerificationUrl: 'https://other.example/verify',
      passwordResetUrl: null,
    );

    // Then
    expect(loaded().linksFailure, same(refusal));
    expect(loaded().scope.emailVerificationUrl, 'https://acme.example/verify-email');
    expect(loaded().linksSaved, isFalse);
  });

  test('GivenSavedLinks_WhenAcknowledged_ThenTheNoticeClears', () async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_acme));
    final controller = controllerUnderTest();
    await controller.load();
    await controller.saveEmailLinks(
      emailVerificationUrl: null,
      passwordResetUrl: null,
    );

    // When
    controller.acknowledgeLinks();

    // Then
    expect(loaded().linksSaved, isFalse);
    expect(loaded().linksFailure, isNull);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/scopes/presentation/scope_sign_in_settings_controller_test.dart`
Expected: FAIL — the controller file does not exist.

- [ ] **Step 3: Write the controller**

`lib/features/scopes/presentation/scope_sign_in_settings_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;

import '../../../core/result/result.dart';
import '../domain/email_link.dart';
import '../domain/scope.dart';
import 'scope_list_controller.dart';

/// Which of UI-31's three writes is outstanding.
enum SignInSettingsAction { googleSignIn, selfRegistration, emailLinks }

/// How far UI-31's screen has got.
sealed class SignInSettingsState {
  const SignInSettingsState();
}

/// The scope is being read.
final class SignInSettingsLoading extends SignInSettingsState {
  const SignInSettingsLoading();
}

/// AF-31a and AF-31h — the scope could not be read.
final class SignInSettingsUnavailable extends SignInSettingsState {
  const SignInSettingsUnavailable(this.failure);

  final Failure failure;

  bool get isNotFound => failure.kind == FailureKind.notFound;
  bool get isForbidden => failure.kind == FailureKind.forbidden;
}

/// The scope's settings are on screen.
final class SignInSettingsLoaded extends SignInSettingsState {
  const SignInSettingsLoaded(
    this.scope, {
    this.inFlight,
    this.googleSignInFailure,
    this.selfRegistrationFailure,
    this.linksFailure,
    this.linksSaved = false,
  });

  final Scope scope;

  /// The write on its way, if any. One at a time: each settles on the state
  /// it started from, so a second in flight would be overwritten by whichever
  /// answered last.
  final SignInSettingsAction? inFlight;

  /// AF-15a / AF-31c — the API refused the Google Sign-In toggle.
  final Failure? googleSignInFailure;

  /// AF-31c — the API refused the self-registration toggle.
  final Failure? selfRegistrationFailure;

  /// AF-31d — the API refused the links.
  final Failure? linksFailure;

  /// The links were saved; the card shows the saved notice.
  final bool linksSaved;

  bool get isBusy => inFlight != null;

  /// AF-31b — a logically deleted scope is shown, and nothing changes it.
  bool get isReadOnly => scope.isDeleted;
}

final NotifierProviderFamily<
  ScopeSignInSettingsController,
  SignInSettingsState,
  String
>
scopeSignInSettingsControllerProvider =
    NotifierProvider.family<
      ScopeSignInSettingsController,
      SignInSettingsState,
      String
    >(ScopeSignInSettingsController.new);

/// UI-31 — one scope's ways in: Google Sign-In, self-registration, and the
/// links its emails point at.
class ScopeSignInSettingsController extends Notifier<SignInSettingsState> {
  ScopeSignInSettingsController(this.arg);

  /// The scope's identifier.
  final String arg;

  @override
  SignInSettingsState build() => const SignInSettingsLoading();

  Future<void> load() async {
    state = const SignInSettingsLoading();

    final result = await ref.read(scopeRepositoryProvider).getById(arg);

    state = result.fold(
      onSuccess: SignInSettingsLoaded.new,
      onFailure: SignInSettingsUnavailable.new,
    );
  }

  /// UI-15, now on this screen. The toggle's output carries neither the
  /// privacy settings nor self-registration, so both are kept from the scope
  /// already known rather than read as cleared.
  Future<void> setGoogleSignIn(bool enabled) => _write(
    SignInSettingsAction.googleSignIn,
    (repository) => repository.setGoogleSignIn(id: arg, enabled: enabled),
    merge: (answer, known) =>
        answer.withPrivacySettingsOf(known).withSelfRegistrationOf(known),
  );

  /// Opens or closes self-registration. The screen asks first (AF-31f,
  /// AF-31g); by the time this runs the person has agreed.
  Future<void> setSelfRegistration(bool enabled) => _write(
    SignInSettingsAction.selfRegistration,
    (repository) => repository.setSelfRegistration(id: arg, enabled: enabled),
    merge: (answer, known) => answer.withPrivacySettingsOf(known),
  );

  /// Saves both links, trimmed, with an empty one sent as `null` (a clear).
  /// Nothing is sent when neither differs from what the API holds.
  Future<void> saveEmailLinks({
    required String? emailVerificationUrl,
    required String? passwordResetUrl,
  }) async {
    final current = state;
    final verification = normalizeEmailLink(emailVerificationUrl);
    final reset = normalizeEmailLink(passwordResetUrl);

    if (current is SignInSettingsLoaded &&
        verification == current.scope.emailVerificationUrl &&
        reset == current.scope.passwordResetUrl) {
      return;
    }

    await _write(
      SignInSettingsAction.emailLinks,
      (repository) => repository.setEmailLinks(
        id: arg,
        emailVerificationUrl: verification,
        passwordResetUrl: reset,
      ),
      merge: (answer, known) => answer.withPrivacySettingsOf(known),
    );
  }

  /// Drops the saved notice and any refused save, so a later edit starts
  /// clean.
  void acknowledgeLinks() {
    if (state case final SignInSettingsLoaded loaded) {
      state = SignInSettingsLoaded(
        loaded.scope,
        inFlight: loaded.inFlight,
        googleSignInFailure: loaded.googleSignInFailure,
        selfRegistrationFailure: loaded.selfRegistrationFailure,
      );
    }
  }

  Future<void> _write(
    SignInSettingsAction action,
    Future<Result<Scope>> Function(ScopeRepository repository) send, {
    required Scope Function(Scope answer, Scope known) merge,
  }) async {
    final current = state;

    if (current is! SignInSettingsLoaded ||
        current.isBusy ||
        current.isReadOnly) {
      return;
    }

    // A new write clears the refusal it would replace; the others stay.
    state = SignInSettingsLoaded(
      current.scope,
      inFlight: action,
      googleSignInFailure: action == SignInSettingsAction.googleSignIn
          ? null
          : current.googleSignInFailure,
      selfRegistrationFailure: action == SignInSettingsAction.selfRegistration
          ? null
          : current.selfRegistrationFailure,
      linksFailure: action == SignInSettingsAction.emailLinks
          ? null
          : current.linksFailure,
    );

    final result = await send(ref.read(scopeRepositoryProvider));

    state = result.fold(
      onSuccess: (answer) => SignInSettingsLoaded(
        merge(answer, current.scope),
        googleSignInFailure: action == SignInSettingsAction.googleSignIn
            ? null
            : current.googleSignInFailure,
        selfRegistrationFailure:
            action == SignInSettingsAction.selfRegistration
            ? null
            : current.selfRegistrationFailure,
        linksFailure: action == SignInSettingsAction.emailLinks
            ? null
            : current.linksFailure,
        linksSaved: action == SignInSettingsAction.emailLinks,
      ),
      // The scope on screen stays the one the API last confirmed.
      onFailure: (failure) => SignInSettingsLoaded(
        current.scope,
        googleSignInFailure: action == SignInSettingsAction.googleSignIn
            ? failure
            : current.googleSignInFailure,
        selfRegistrationFailure:
            action == SignInSettingsAction.selfRegistration
            ? failure
            : current.selfRegistrationFailure,
        linksFailure: action == SignInSettingsAction.emailLinks
            ? failure
            : current.linksFailure,
      ),
    );
  }
}
```

Add `import '../domain/scope_repository.dart';` for the `ScopeRepository` type used in `_write`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/scopes/presentation/scope_sign_in_settings_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Gate and commit**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`

```bash
git add lib/features/scopes/presentation/scope_sign_in_settings_controller.dart test/features/scopes/presentation/scope_sign_in_settings_controller_test.dart
git commit -m "feat: add the scope sign-in settings controller" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The "Sign-in & sign-up" screen and its route

**Files:**
- Create: `lib/features/scopes/presentation/scope_sign_in_settings_screen.dart`
- Modify: `lib/app/router.dart` (route after `/scopes/:scopeId/owners`)
- Test: `test/features/scopes/presentation/scope_sign_in_settings_screen_test.dart`, `test/app/router_test.dart` (one route test, following its existing pattern)

**Interfaces:**
- Consumes: Task 3's controller and states; `googleUserRepositoryProvider` (`lib/features/google_users/domain/google_user_repository.dart`, `countIn(String scopeId)` → `Future<Result<int>>`); `validateEmailLink`; shared widgets `AppShell`, `EditableSection`, `recordFieldDecoration`, `confirmDiscardChanges`, `showConfirm`, `ErrorBanner`, `RetryBanner`, `CollectionEmpty`, `CollectionFailed`, `NothingToSaveHint` as used by `scope_detail_screen.dart`.
- Produces: `class ScopeSignInSettingsScreen extends ConsumerStatefulWidget { const ScopeSignInSettingsScreen({required String scopeId}) }`; top-level `String signInSettingsSummary(Scope scope)`; route `/scopes/:scopeId/sign-in-settings`.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/scopes/presentation/scope_sign_in_settings_screen_test.dart`. Copy the harness from `test/features/scopes/presentation/scope_detail_screen_test.dart` lines 1–208 (imports, `_jwt`, mocks, sizes, `pump`, `answerGetWith`, `setUp`) with these changes: the router's `initialLocation` is `'/scopes/scope-1/sign-in-settings'`; routes are `/scopes/:scopeId` → `Scaffold(body: Text('scope'))` and `/scopes/:scopeId/sign-in-settings` → `ScopeSignInSettingsScreen(scopeId: …)`; add answer helpers `answerGoogleWith`, `answerSignUpWith`, `answerLinksWith` (same stubs as Task 3's test) and keep `answerCountWith` from the detail test's Google toggle section. Fixtures:

```dart
const _acme = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  googleSignInEnabled: true,
  ownerIds: <String>['person-1'],
);

const _linked = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  emailVerificationUrl: 'https://acme.example/verify-email',
  passwordResetUrl: 'https://acme.example/password-reset',
);

const _open = Scope(
  id: 'scope-1',
  name: 'Acme',
  description: 'The first tenant',
  selfRegistrationEnabled: true,
  emailVerificationUrl: 'https://acme.example/verify-email',
);
```

Then **move** the Google Sign-In widget tests from `scope_detail_screen_test.dart` (the block from `GivenAScope_WhenOpened_ThenTheGoogleControlReflectsIt` through `GivenADeletedScope_WhenRendered_ThenTheControlIsDisabled`, lines ~835–1033) into this file unchanged except for the pumped route. Do not delete them from the detail test yet — Task 5 does.

Add these tests (finders: `find.widgetWithText(SwitchListTile, 'Self-registration')`, `find.widgetWithText(TextFormField, 'Verification link')`):

```dart
  testWidgets('GivenAScope_WhenOpened_ThenItsWaysInAreShown', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_open));

    // When
    await pump(tester);

    // Then
    final signUp = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Self-registration'),
    );
    expect(signUp.value, isTrue);
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
  });

  // AF-31f
  testWidgets('GivenNoVerificationLink_WhenSignUpOpened_ThenItAsksFirst', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Open self-registration?'), findsOneWidget);
    expect(
      find.textContaining("link to Heimdall's default page"),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheOpenWarning_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  testWidgets('GivenTheOpenWarning_WhenConfirmed_ThenTheApiIsAsked', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerSignUpWith(const Success<Scope>(_open));
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(FilledButton, 'Open'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.setSelfRegistration(id: 'scope-1', enabled: true),
    ).called(1);
  });

  testWidgets('GivenAVerificationLink_WhenSignUpOpened_ThenItDoesNotAsk', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_linked));
    answerSignUpWith(const Success<Scope>(_open));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Open self-registration?'), findsNothing);
    verify(
      () => repository.setSelfRegistration(id: 'scope-1', enabled: true),
    ).called(1);
  });

  // AF-31g
  testWidgets('GivenSignUpOpen_WhenClosed_ThenTheLossIsExplained', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_open));
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('Close self-registration?'), findsOneWidget);
    expect(find.textContaining('will not be able to finish'), findsOneWidget);
  });

  testWidgets('GivenTheCloseWarning_WhenCancelled_ThenNothingIsSent', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_open));
    await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    verifyNever(
      () => repository.setSelfRegistration(
        id: any(named: 'id'),
        enabled: any(named: 'enabled'),
      ),
    );
  });

  // AF-31c
  testWidgets('GivenARefusedSignUpToggle_WhenAttempted_ThenApiErrorsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_linked));
    answerSignUpWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.forbidden,
          errors: <String>['You do not own this scope.'],
        ),
      ),
    );
    await pump(tester);

    // When
    await tester.tap(find.widgetWithText(SwitchListTile, 'Self-registration'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('You do not own this scope.'), findsOneWidget);
  });

  testWidgets('GivenEditedLinks_WhenSaved_ThenBothAreSent', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(const Success<Scope>(_linked));
    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://acme.example/verify-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password-reset link'),
      'https://acme.example/password-reset',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Then
    verify(
      () => repository.setEmailLinks(
        id: 'scope-1',
        emailVerificationUrl: 'https://acme.example/verify-email',
        passwordResetUrl: 'https://acme.example/password-reset',
      ),
    ).called(1);
    expect(find.text('Saved.'), findsOneWidget);
  });

  // AF-31e
  testWidgets('GivenARelativeLink_WhenSaved_ThenNothingIsSent', (tester) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      '/verify-email',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Then
    expect(
      find.text('Enter a full link starting with https:// or http://.'),
      findsOneWidget,
    );
    verifyNever(
      () => repository.setEmailLinks(
        id: any(named: 'id'),
        emailVerificationUrl: any(named: 'emailVerificationUrl'),
        passwordResetUrl: any(named: 'passwordResetUrl'),
      ),
    );
  });

  // AF-31d
  testWidgets('GivenRefusedLinks_WhenSaved_ThenApiErrorsAndInputAreKept', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    answerLinksWith(
      const FailureResult<Scope>(
        Failure(
          kind: FailureKind.validation,
          errors: <String>['The email link must be an absolute URL.'],
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    // When
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://acme.example/verify-email',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('The email link must be an absolute URL.'), findsOneWidget);
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
  });

  testWidgets('GivenEditedLinks_WhenCancelled_ThenTheSavedOnesReturn', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_linked));
    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Verification link'),
      'https://elsewhere.example/x',
    );

    // When
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('https://acme.example/verify-email'), findsOneWidget);
    expect(find.text('https://elsewhere.example/x'), findsNothing);
  });

  // AF-31b
  testWidgets('GivenADeletedScope_WhenOpened_ThenNothingCanChange', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const Success<Scope>(
        Scope(
          id: 'scope-1',
          name: 'Acme',
          description: '',
          isDeleted: true,
        ),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.textContaining('This scope is deleted.'), findsOneWidget);
    final signUp = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Self-registration'),
    );
    expect(signUp.onChanged, isNull);
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsNothing);
  });

  // AF-31a
  testWidgets('GivenAMissingScope_WhenOpened_ThenNotFoundIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.notFound, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.text('Scope not found'), findsOneWidget);
  });

  // AF-31h
  testWidgets('GivenATransportFailure_WhenOpened_ThenRetryIsOffered', (
    tester,
  ) async {
    // Given
    answerGetWith(
      const FailureResult<Scope>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('GivenACompactWindow_WhenRendered_ThenTheSettingsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, size: _compact);

    // Then
    expect(find.text('Self-registration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenAMediumWindow_WhenRendered_ThenTheSettingsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, size: _medium);

    // Then
    expect(find.text('Self-registration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GivenTheDarkTheme_WhenRendered_ThenTheSettingsAreShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester, theme: buildDarkTheme());

    // Then
    expect(find.text('Email links'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('GivenScopeSettings_WhenSummarised_ThenEachIsNamed', () {
    // Given / When
    final summary = signInSettingsSummary(_open);

    // Then
    expect(summary, 'Google off · Self-registration on · Custom email links');
  });
```

Check the `Retry` and `Edit` labels against `CollectionFailed` and `EditableSection` (`editLabel` default) and use the real ones.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/scopes/presentation/scope_sign_in_settings_screen_test.dart`
Expected: FAIL — the screen does not exist.

- [ ] **Step 3: Write the screen**

`lib/features/scopes/presentation/scope_sign_in_settings_screen.dart`. Structure (follow `scope_detail_screen.dart`'s conventions for the shell, loading/unavailable panels, banners, the edit mode and `confirmLeave`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/forms/edit_mode.dart';
import '../../../shared/forms/form_feedback.dart';
import '../../../shared/layout/app_shell.dart';
import '../../../shared/widgets/collection_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/failure_banner.dart';
import '../../google_users/domain/google_user_repository.dart';
import '../domain/email_link.dart';
import '../domain/scope.dart';
import 'scope_sign_in_settings_controller.dart';

/// The one-line state of a scope's ways in, for the scope detail's link to
/// UI-31.
String signInSettingsSummary(Scope scope) => <String>[
  scope.googleSignInEnabled ? 'Google on' : 'Google off',
  scope.selfRegistrationEnabled
      ? 'Self-registration on'
      : 'Self-registration off',
  scope.hasCustomEmailLinks ? 'Custom email links' : 'Default email links',
].join(' · ');

/// UI-31 — how people get into one scope: Google Sign-In, self-registration,
/// and where its emails send them.
class ScopeSignInSettingsScreen extends ConsumerStatefulWidget {
  const ScopeSignInSettingsScreen({required this.scopeId, super.key});

  final String scopeId;

  @override
  ConsumerState<ScopeSignInSettingsScreen> createState() =>
      _ScopeSignInSettingsScreenState();
}

class _ScopeSignInSettingsScreenState
    extends ConsumerState<ScopeSignInSettingsScreen> {
  var _formKey = GlobalKey<FormState>();
  final _verification = TextEditingController();
  final _reset = TextEditingController();
  Scope? _seeded;
  bool _editing = false;

  ScopeSignInSettingsController get _controller => ref.read(
    scopeSignInSettingsControllerProvider(widget.scopeId).notifier,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.load());
  }

  @override
  void dispose() {
    _verification.dispose();
    _reset.dispose();
    super.dispose();
  }

  // _seed / _restore / _differsFrom / _startEditing / _cancelEditing /
  // _confirmLeave / _hasUnsavedEdit: as in scope_detail_screen.dart, over the
  // two link fields. _differsFrom compares normalizeEmailLink(field.text) with
  // the scope's link, so whitespace alone is not a change. _startEditing and
  // _cancelEditing call _controller.acknowledgeLinks(); _cancelEditing also
  // replaces _formKey so validation messages go with the edit.

  Future<void> _save() async {
    if (!validateAndReveal(_formKey)) {
      return; // AF-31e
    }

    await _controller.saveEmailLinks(
      emailVerificationUrl: _verification.text,
      passwordResetUrl: _reset.text,
    );
  }

  /// UI-15, moved here unchanged — including AF-15b's count-aware warning.
  Future<void> _toggleGoogleSignIn(bool enabled) async {
    // Body: copy ScopeDetailScreen._toggleGoogleSignIn verbatim, ending with
    // `await _controller.setGoogleSignIn(enabled);`.
  }

  /// AF-31f and AF-31g — opening without a verification link, and closing,
  /// each ask first; a cancelled dialog sends nothing.
  Future<void> _toggleSelfRegistration(Scope scope, bool enabled) async {
    if (enabled && scope.emailVerificationUrl == null) {
      final confirmed = await showConfirm(
        context: context,
        title: 'Open self-registration?',
        message:
            "Sign-up confirmation emails will link to Heimdall's default "
            "page, not your application's. Open self-registration anyway?",
        confirmLabel: 'Open',
      );

      if (!confirmed || !mounted) {
        return;
      }
    }

    if (!enabled) {
      final confirmed = await showConfirm(
        context: context,
        title: 'Close self-registration?',
        message:
            'New sign-ups will be refused. People who have signed up but '
            'have not yet followed the link in their email will not be able '
            'to finish, and will need to sign up again once it reopens.',
        confirmLabel: 'Close',
      );

      if (!confirmed || !mounted) {
        return;
      }
    }

    await _controller.setSelfRegistration(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      scopeSignInSettingsControllerProvider(widget.scopeId),
    );

    // A save that went through ends the edit, as on the scope detail.
    ref.listen<SignInSettingsState>(
      scopeSignInSettingsControllerProvider(widget.scopeId),
      (previous, next) {
        if (previous is SignInSettingsLoaded &&
            previous.inFlight == SignInSettingsAction.emailLinks &&
            next is SignInSettingsLoaded &&
            next.linksSaved) {
          setState(() => _editing = false);
        }
      },
    );

    return AppShell(
      currentRoute: '/scopes',
      backRoute: '/scopes/${widget.scopeId}',
      backTooltip: 'Back to the scope',
      title: const Text('Sign-in & sign-up'),
      confirmLeave: _confirmLeave,
      body: switch (state) {
        SignInSettingsLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        // AF-31a — the same panels the scope detail shows.
        SignInSettingsUnavailable(isNotFound: true) => CollectionEmpty(
          title: 'Scope not found',
          message:
              'There is no scope with that identifier. It may have been '
              'permanently deleted.',
          icon: Icons.search_off_outlined,
          actionLabel: 'Back to scopes',
          onAction: () => context.go('/scopes'),
        ),
        SignInSettingsUnavailable(isForbidden: true) => CollectionEmpty(
          title: 'Not available for your role',
          message:
              'This scope is not one you administer. Nothing is wrong '
              'with your session.',
          icon: Icons.lock_person_outlined,
          actionLabel: 'Back to scopes',
          onAction: () => context.go('/scopes'),
        ),
        // AF-31h
        SignInSettingsUnavailable(:final failure) => CollectionFailed(
          failure: failure,
          onRetry: _controller.load,
        ),
        final SignInSettingsLoaded loaded => _settings(loaded),
      },
    );
  }

  Widget _settings(SignInSettingsLoaded state) {
    // A SingleChildScrollView → Center → ConstrainedBox(maxWidth: 720) →
    // Column, as on the scope detail, holding in order:
    //
    // 1. When state.isReadOnly: a notice in errorContainer colours reading
    //    'This scope is deleted. Its settings are shown for reference and
    //    cannot be changed.'
    //
    // 2. Card "Ways in" (titleMedium heading 'Ways in'):
    //    - SwitchListTile 'Google Sign-In', subtitle 'People may sign in to
    //      this scope with Google.' / 'Google sign-in is off for this scope.',
    //      onChanged null when state.isBusy || state.isReadOnly, else
    //      _toggleGoogleSignIn; ErrorBanner(state.googleSignInFailure) below.
    //    - SwitchListTile 'Self-registration', subtitle 'Lets people create
    //      their own account in this scope from your application's sign-up
    //      screen. Each one confirms by email before the account exists.',
    //      onChanged null when busy or read-only, else
    //      (enabled) => _toggleSelfRegistration(state.scope, enabled);
    //      ErrorBanner(state.selfRegistrationFailure) below.
    //
    // 3. Form(key: _formKey) → EditableSection(title: 'Email links',
    //    editing: _editing && !state.isReadOnly, mayEdit: !state.isReadOnly,
    //    saving: state.inFlight == SignInSettingsAction.emailLinks,
    //    canSave: _differsFrom(state.scope) && !state.isBusy,
    //    onEdit: _startEditing, onCancel: _cancelEditing, onSave: _save):
    //    - above the section: the saved notice ('Saved.', secondaryContainer
    //      colours, as _SavedNotice on the detail) when state.linksSaved; the
    //      linksFailure as RetryBanner(onRetry: _save) when its kind is
    //      network (AF-31i), otherwise ErrorBanner (AF-31d).
    //    - TextFormField 'Verification link', controller _verification,
    //      readOnly: !editing, maxLength: emailLinkMaxLength,
    //      keyboardType: TextInputType.url, decoration
    //      recordFieldDecoration(context, label: 'Verification link',
    //      editing: editing) with helperText 'Sign-up confirmation and email
    //      verification. Leave empty to use Heimdall's default.' and
    //      helperMaxLines: 3, validator: validateEmailLink.
    //    - TextFormField 'Password-reset link', same shape, helperText
    //      'Password recovery. Leave empty to use Heimdall's default.'.
    //
    // _seed(state.scope) is called first, as on the detail, so a refused
    // save keeps what was typed (AF-31d).
  }
}
```

The comments inside `_settings` and the helper list are instructions for this step, not code to keep: write the real widgets, and keep only explanatory comments in the codebase's voice (AF references, why-notes). If `recordFieldDecoration` cannot take a `helperText`, call `.copyWith(helperText: …, helperMaxLines: 3)` on its result.

- [ ] **Step 4: Register the route**

In `lib/app/router.dart`, import the screen and add after the `/scopes/:scopeId/owners` route:

```dart
      GoRoute(
        path: '/scopes/:scopeId/sign-in-settings',
        builder: (context, state) => ScopeSignInSettingsScreen(
          scopeId: state.pathParameters['scopeId']!,
        ),
      ),
```

`roleMayReach` already admits `/scopes/…` for System and Scope Admins; add one case to `test/app/route_access_test.dart`, in its existing style: `GivenAScopeAdmin_WhenSignInSettingsAsked_ThenItIsReachable` and `GivenAUser_WhenSignInSettingsAsked_ThenItIsNot`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/scopes/presentation/scope_sign_in_settings_screen_test.dart test/app`
Expected: PASS.

- [ ] **Step 6: Gate and commit**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`

```bash
git add lib/features/scopes/presentation/scope_sign_in_settings_screen.dart lib/app/router.dart test/features/scopes/presentation/scope_sign_in_settings_screen_test.dart test/app/route_access_test.dart
git commit -m "feat: add the scope sign-in settings screen" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Move Google Sign-In off the scope detail and link the new screen

**Files:**
- Modify: `lib/features/scopes/presentation/scope_detail_screen.dart`
- Modify: `lib/features/scopes/presentation/scope_detail_controller.dart`
- Modify: `lib/features/google_users/presentation/google_user_list_screen.dart`
- Test: `test/features/scopes/presentation/scope_detail_screen_test.dart`, `test/features/scopes/presentation/scope_detail_controller_test.dart`, `test/features/google_users/presentation/google_user_list_screen_test.dart`

**Interfaces:**
- Consumes: `signInSettingsSummary(Scope)` from Task 4; route `/scopes/:scopeId/sign-in-settings`.
- Produces: `ScopeDetailLoaded` without `togglingGoogleSignIn` / `googleSignInFailure`; `ScopeDetailController` without `setGoogleSignIn`.

- [ ] **Step 1: Write the failing tests**

In `scope_detail_screen_test.dart`, add a route `/scopes/:scopeId/sign-in-settings` → `Scaffold(body: Text('sign-in settings'))` to the harness and add:

```dart
  testWidgets('GivenAScope_WhenOpened_ThenItsWaysInAreSummarised', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(find.text('Sign-in & sign-up'), findsOneWidget);
    expect(
      find.text('Google on · Self-registration off · Default email links'),
      findsOneWidget,
    );
  });

  testWidgets('GivenTheSignInLink_WhenTapped_ThenTheSettingsOpen', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));
    await pump(tester);

    // When
    await tester.tap(find.text('Sign-in & sign-up'));
    await tester.pumpAndSettle();

    // Then
    expect(find.text('sign-in settings'), findsOneWidget);
  });

  testWidgets('GivenAScope_WhenOpened_ThenNoGoogleSwitchIsShown', (
    tester,
  ) async {
    // Given
    answerGetWith(const Success<Scope>(_acme));

    // When
    await pump(tester);

    // Then
    expect(find.widgetWithText(SwitchListTile, 'Google Sign-In'), findsNothing);
  });
```

In `google_user_list_screen_test.dart`, rename the two empty-state tests' button text from `'Scope settings'` to `'Sign-in settings'`, add a route `/scopes/:scopeId/sign-in-settings` → `Scaffold(body: Text('sign-in settings'))` to its harness, rename `GivenGoogleOff_WhenScopeSettingsTapped_ThenTheScopeOpens` to `GivenGoogleOff_WhenSignInSettingsTapped_ThenTheSettingsOpen`, and expect `find.text('sign-in settings')`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/scopes/presentation/scope_detail_screen_test.dart test/features/google_users/presentation/google_user_list_screen_test.dart`
Expected: FAIL — no link, switch still present, old button label.

- [ ] **Step 3: Remove the toggle from the detail**

- `scope_detail_screen.dart`: delete `_toggleGoogleSignIn`, the `SwitchListTile` and its `ErrorBanner`, and the `googleUserRepository` import if now unused; the card keeps the Owners count only. Remove `state.togglingGoogleSignIn` from `canSave` and from `_DangerZone`'s `deleting:`. Update the class doc's UI list if it names UI-15.
- `_Links`: take the `Scope` instead of the id; add, after Owners, an entry `(label: 'Sign-in & sign-up', icon: Icons.login_outlined, path: 'sign-in-settings', subtitle: signInSettingsSummary(scope))`; the record type gains `String? subtitle`, rendered as `ListTile.subtitle` when non-null.
- `scope_detail_controller.dart`: delete `setGoogleSignIn`, the `togglingGoogleSignIn` / `googleSignInFailure` fields, their `copyWith` parameters and every guard that reads them; update doc comments that mention UI-15 to say the toggle lives on UI-31's screen.
- `google_user_list_screen.dart`: the empty state's action becomes label `'Sign-in settings'`, target `'/scopes/${widget.scopeId}/sign-in-settings'`; the doc comment's "UI-15 is where it is switched on" becomes "UI-31's screen is where it is switched on".

- [ ] **Step 4: Remove the moved tests**

Delete from `scope_detail_screen_test.dart` the Google Sign-In block Task 4 copied (tests `GivenAScope_WhenOpened_ThenTheGoogleControlReflectsIt` … `GivenADeletedScope_WhenRendered_ThenTheControlIsDisabled`) and the now-unused `_googleOff` / google-user mock if nothing else uses them. Delete from `scope_detail_controller_test.dart` the toggle tests (`GivenGoogleSignInOff_WhenTurnedOn_ThenTheApiIsAsked` through `GivenADeletedScope_WhenToggled_ThenNoRequestIsMade`) and `answerToggleWith`. Their coverage now lives in Tasks 3 and 4.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/scopes test/features/google_users`
Expected: PASS.

- [ ] **Step 6: Gate and commit**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`

```bash
git add lib/features/scopes/presentation/scope_detail_screen.dart lib/features/scopes/presentation/scope_detail_controller.dart lib/features/google_users/presentation/google_user_list_screen.dart test/features/scopes/presentation/scope_detail_screen_test.dart test/features/scopes/presentation/scope_detail_controller_test.dart test/features/google_users/presentation/google_user_list_screen_test.dart
git commit -m "refactor: move google sign-in to its own screen" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Document UI-31

**Files:**
- Modify: `docs/requirements/Use Case Specification Document.md`
- Modify: `docs/requirements/System Requirements Document.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Use Case Specification**

- §1.4 index: add `| UI-31 | Configure a scope's sign-in and sign-up | UC-24, UC-47 |` after UI-30.
- The use-case diagram near line 50 (mermaid): add a `UI31[UI-31: Sign-in & sign-up settings]` node wherever UI-15 sits, in the same style.
- UI-15's section: add a note at its top — *"Since UI-31, the switch lives on the scope's **Sign-in & sign-up** screen (`/scopes/:scopeId/sign-in-settings`) rather than on the scope detail. Its flows are unchanged."*
- New section `### UI-31: Configure a scope's sign-in and sign-up` after UI-30, in the document's section format (field table, main flow as numbered steps, alternative-flow table). Content: spec §3.1–§3.4 — actors, placement, the "Ways in" and "Email links" cards with the exact dialog copy, and AF-31a…AF-31i.
- The traceability table near line 1093: add `| UI-31 | FR-SC-12, FR-SC-13, FR-SC-14 |` in its style.

- [ ] **Step 2: System Requirements**

- FR-SC-04: change "including its owners and its Google Sign-In state" to "including its owners, and a summary of its sign-in and sign-up settings".
- FR-SC-12: use case column `UI-15, UI-31`.
- Add after FR-SC-12:

```markdown
| FR-SC-13 | The client shall show and toggle a scope's self-registration through `PUT /api/scopes/{id}/self-registration`, asking before opening it while the scope has no verification link and before closing it. | UI-31 |
| FR-SC-14 | The client shall set or clear a scope's verification and password-reset links through `PUT /api/scopes/{id}/email-links`, sending both on every save, trimmed, with an empty link sent as `null`. | UI-31 |
```

- Screen inventory: `/scopes/:scopeId` becomes `UI-12, UI-13`; add `| \`/scopes/:scopeId/sign-in-settings\` | Sign-in & sign-up | UI-31, UI-15 |` after the owners row.
- Authorization matrix: replace the `Toggle Google Sign-In` row with `| Sign-in & sign-up settings | Full | Owned scopes only | Hidden | Hidden |`.

- [ ] **Step 3: CHANGELOG**

Under `## [Unreleased]` add:

```markdown
### Added

- A **Sign-in & sign-up** screen for each scope, opened from the scope's page. It holds the Google Sign-In switch
  (moved from the scope's page), a new self-registration switch, and the links the scope's verification and
  password-reset emails point at, so a client application's own screens can receive them. Opening self-registration
  without a verification link, and closing it, each ask first and say what will happen.
```

- [ ] **Step 4: Commit**

```bash
git add "docs/requirements/Use Case Specification Document.md" "docs/requirements/System Requirements Document.md" CHANGELOG.md
git commit -m "docs: specify ui-31 scope sign-in settings" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Branch 2 — `feature/ui-02-resend-second-factor-code`

Before Task 7: `git switch develop && git switch -c feature/ui-02-resend-second-factor-code`. Copy this plan's file into the branch is not needed; the plan lives on branch 1.

### Task 7: Resend the second-factor code through the repository and the session

**Files:**
- Modify: `lib/features/auth/domain/auth_repository.dart`, `lib/features/auth/data/auth_repository_impl.dart`, `lib/features/auth/presentation/session_controller.dart`
- Test: `test/features/auth/data/auth_repository_impl_test.dart`, `test/features/auth/presentation/session_controller_test.dart`

**Interfaces:**
- Produces: `AuthRepository.resendSecondFactorCode({required String challengeToken})` → `Future<Result<void>>`; `SessionController.resendSecondFactorCode()` → `Future<Result<void>>` (a `FailureResult` of kind `unknown` with errors `['There is no sign-in to send a code for.']` when the session is not `Challenged`).

- [ ] **Step 1: Write the failing tests**

In `auth_repository_impl_test.dart` (it has a stub-adapter harness like the scope repository test), add:

```dart
  test('GivenAChallenge_WhenACodeIsResent_ThenTheTokenTravels', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{'success': true, 'errors': <String>[], 'data': <String, dynamic>{}},
      ),
    );

    // When
    final result = await repository.resendSecondFactorCode(
      challengeToken: 'challenge',
    );

    // Then
    expect(result.isSuccess, isTrue);
    expect(adapter.bodies.single, <String, dynamic>{'challengeToken': 'challenge'});
  });

  test('GivenNoConnection_WhenACodeIsResent_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.resendSecondFactorCode(
      challengeToken: 'challenge',
    );

    // Then
    expect(result.failureOrNull!.kind, FailureKind.network);
  });
```

(Adapt helper names to the ones that file actually uses.)

In `session_controller_test.dart`, add:

```dart
  test('GivenAChallenge_WhenACodeIsResent_ThenTheHeldTokenIsUsed', () async {
    // Given
    // (sign in to a TwoFactorRequired outcome with challengeToken 'challenge',
    // as the file's other challenge tests do)
    when(
      () => repository.resendSecondFactorCode(challengeToken: 'challenge'),
    ).thenAnswer((_) async => const Success<void>(null));

    // When
    final result = await controller.resendSecondFactorCode();

    // Then
    expect(result.isSuccess, isTrue);
    verify(
      () => repository.resendSecondFactorCode(challengeToken: 'challenge'),
    ).called(1);
  });

  test('GivenNoChallenge_WhenACodeIsResent_ThenNothingIsSent', () async {
    // Given
    // (a restored, unauthenticated session)

    // When
    final result = await controller.resendSecondFactorCode();

    // Then
    expect(result.isSuccess, isFalse);
    verifyNever(
      () => repository.resendSecondFactorCode(
        challengeToken: any(named: 'challengeToken'),
      ),
    );
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/auth/data/auth_repository_impl_test.dart test/features/auth/presentation/session_controller_test.dart`
Expected: FAIL — method not defined.

- [ ] **Step 3: Implement**

`auth_repository.dart`, after `verifySecondFactor`:

```dart
  /// UC-46 — asks for a fresh email code for an outstanding challenge.
  ///
  /// The API answers alike whether or not it sent one (AF-46a…AF-46e), so a
  /// success here means only that the request was taken.
  Future<Result<void>> resendSecondFactorCode({required String challengeToken});
```

`auth_repository_impl.dart`:

```dart
  @override
  Future<Result<void>> resendSecondFactorCode({
    required String challengeToken,
  }) async {
    try {
      final response = await _client.authResendTwoFactorChallengeCode(
        body: ResendTwoFactorChallengeCodeCommand(
          challengeToken: challengeToken,
        ),
      );

      if (response.success != true) {
        return FailureResult<void>(
          Failure(
            kind: FailureKind.validation,
            errors: response.errors ?? const <String>[],
          ),
        );
      }

      return const Success<void>(null);
    } on DioException catch (error) {
      return FailureResult<void>(failureFromDioException(error));
    }
  }
```

`session_controller.dart`, next to `submitSecondFactor`:

```dart
  /// UI-02 — a new email code for the challenge this session holds. The
  /// challenge is not changed: the API never extends or reissues it.
  Future<Result<void>> resendSecondFactorCode() async {
    final current = state;

    if (current is! Challenged) {
      return const FailureResult<void>(
        Failure(
          kind: FailureKind.unknown,
          errors: <String>['There is no sign-in to send a code for.'],
        ),
      );
    }

    return ref
        .read(authRepositoryProvider)
        .resendSecondFactorCode(challengeToken: current.challengeToken);
  }
```

Update any hand-written `AuthRepository` fake (`grep -rn "implements AuthRepository" test lib`).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/auth`
Expected: PASS.

- [ ] **Step 5: Gate and commit**

```bash
git add lib/features/auth/domain/auth_repository.dart lib/features/auth/data/auth_repository_impl.dart lib/features/auth/presentation/session_controller.dart test/features/auth/data/auth_repository_impl_test.dart test/features/auth/presentation/session_controller_test.dart
git commit -m "feat: resend the second-factor email code" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The "Send a new code" control

**Files:**
- Modify: `lib/features/auth/presentation/two_factor_screen.dart`
- Test: `test/features/auth/presentation/two_factor_screen_test.dart`

**Interfaces:**
- Consumes: `SessionController.resendSecondFactorCode()`, `abandonChallenge()`.
- Produces: top-level constants in `two_factor_screen.dart`: `const Duration resendCooldown = Duration(seconds: 30);`, `const int maxCodeResends = 3;`.

- [ ] **Step 1: Write the failing widget tests**

Add to `two_factor_screen_test.dart` (its `pump` takes `methods:`; add a helper):

```dart
  void answerResendWith(Result<void> result) {
    when(
      () => repository.resendSecondFactorCode(challengeToken: 'challenge'),
    ).thenAnswer((_) async => result);
  }

  Finder sendButton() => find.textContaining('Send a new code');

  testWidgets('GivenAnEmailChallenge_WhenRendered_ThenResendIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, methods: const <String>['Email']);

    // Then
    expect(sendButton(), findsOneWidget);
  });

  // AF-02f
  testWidgets('GivenAnAppChallenge_WhenRendered_ThenNoResendIsOffered', (
    tester,
  ) async {
    // Given / When
    await pump(tester, methods: const <String>['Totp']);

    // Then
    expect(sendButton(), findsNothing);
  });

  testWidgets('GivenARecoveryCode_WhenChosen_ThenNoResendIsOffered', (
    tester,
  ) async {
    // Given
    await pump(tester, methods: const <String>['Email']);

    // When
    await tester.tap(find.text('Use a recovery code instead'));
    await tester.pumpAndSettle();

    // Then
    expect(sendButton(), findsNothing);
  });

  testWidgets('GivenAnEmailChallenge_WhenResent_ThenTheOutcomeIsHedged', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    verify(
      () => repository.resendSecondFactorCode(challengeToken: 'challenge'),
    ).called(1);
    expect(
      find.text(
        'If your sign-in is still open, a new code is on its way. Codes '
        'sent before it no longer work.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenAResend_WhenWithinTheCooldown_ThenItWaits', (tester) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    await tester.tap(sendButton());
    await tester.pump();

    // When
    await tester.tap(sendButton());
    await tester.pump(const Duration(seconds: 10));

    // Then
    verify(
      () => repository.resendSecondFactorCode(challengeToken: 'challenge'),
    ).called(1);
    expect(find.text('Send a new code (20s)'), findsOneWidget);
  });

  testWidgets('GivenTheCooldown_WhenItEnds_ThenResendIsOfferedAgain', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    await tester.tap(sendButton());
    await tester.pump();

    // When
    await tester.pump(const Duration(seconds: 30));

    // Then
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Send a new code'),
    );
    expect(button.onPressed, isNotNull);
  });

  // AF-02g
  testWidgets('GivenThreeResends_WhenRendered_ThenStartOverReplacesIt', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);

    // When
    for (var send = 0; send < 3; send++) {
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
    }

    // Then
    expect(sendButton(), findsNothing);
    expect(find.text('For another code, sign in again.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Start over'), findsOneWidget);
  });

  testWidgets('GivenStartOver_WhenTapped_ThenTheChallengeIsDiscarded', (
    tester,
  ) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    for (var send = 0; send < 3; send++) {
      await tester.tap(sendButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
    }

    // When
    await tester.tap(find.widgetWithText(OutlinedButton, 'Start over'));
    await flush(tester);

    // Then
    expect(container.read(sessionControllerProvider), isA<Unauthenticated>());
  });

  // AF-02h
  testWidgets('GivenAFailedResend_WhenTapped_ThenItIsNotCounted', (
    tester,
  ) async {
    // Given
    answerResendWith(
      const FailureResult<void>(
        Failure(kind: FailureKind.network, errors: <String>[]),
      ),
    );
    await pump(tester, methods: const <String>['Email']);

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Send a new code'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.byType(ErrorBanner), findsOneWidget);
  });

  testWidgets('GivenATypedCode_WhenResent_ThenItIsKept', (tester) async {
    // Given
    answerResendWith(const Success<void>(null));
    await pump(tester, methods: const <String>['Email']);
    await tester.enterText(find.byType(TextFormField), '12');

    // When
    await tester.tap(sendButton());
    await tester.pump();

    // Then
    expect(find.text('12'), findsOneWidget);
  });
```

Add `import 'package:heimdall_ui/shared/widgets/failure_banner.dart';`. Also extend the existing breakpoint and dark-theme tests with an `Email` variant each, asserting `sendButton()` is found and `tester.takeException()` is null.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/auth/presentation/two_factor_screen_test.dart`
Expected: FAIL — no resend control.

- [ ] **Step 3: Implement the control**

In `two_factor_screen.dart`:

```dart
import 'dart:async';
```

Top level:

```dart
/// How long the resend control waits after each send.
const Duration resendCooldown = Duration(seconds: 30);

/// The API's reissue cap for one challenge (FR-2F-13). Further sends would be
/// answered alike and send nothing, so the control stops offering them.
const int maxCodeResends = 3;

/// Whether [method] is the email method, whatever the API called it.
bool _isEmail(String? method) => switch (method?.toLowerCase()) {
  'email' || 'mail' => true,
  _ => false,
};
```

State fields:

```dart
  int _sends = 0;
  int _cooldownLeft = 0;
  Timer? _cooldown;
  bool _resending = false;
  bool _resent = false;
  Failure? _resendFailure;
```

`dispose`: `_cooldown?.cancel();` before `_code.dispose()`.

Method:

```dart
  /// UI-02 — another email code for this challenge. The API answers alike
  /// whether or not it sent one, so the confirmation never claims more than
  /// that; a failure to reach it is not a send and costs nothing (AF-02h).
  Future<void> _resend() async {
    if (_resending || _cooldownLeft > 0 || _sends >= maxCodeResends) {
      return;
    }

    setState(() {
      _resending = true;
      _resendFailure = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .resendSecondFactorCode();

    if (!mounted) {
      return;
    }

    setState(() {
      _resending = false;

      if (result.failureOrNull case final Failure failure) {
        _resendFailure = failure;

        return;
      }

      _sends++;
      _resent = true;
      _cooldownLeft = resendCooldown.inSeconds;
    });

    if (result.isSuccess) {
      _cooldown?.cancel();
      _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();

          return;
        }

        setState(() => _cooldownLeft--);

        if (_cooldownLeft <= 0) {
          timer.cancel();
        }
      });
    }
  }
```

In `build`, after the code `TextFormField`'s `SizedBox(height: 24)` and before the Verify button, insert when `_isEmail(method) && !_useRecoveryCode`:

```dart
                      if (_isEmail(method) && !_useRecoveryCode) ...<Widget>[
                        if (_resent) ...<Widget>[
                          Text(
                            'If your sign-in is still open, a new code is on '
                            'its way. Codes sent before it no longer work.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_resendFailure case final Failure failure) ...<Widget>[
                          ErrorBanner(failure: failure),
                          const SizedBox(height: 8),
                        ],
                        // AF-02g: past the API's cap a send would do nothing,
                        // so the way to a new code is a new sign-in.
                        if (_sends >= maxCodeResends) ...<Widget>[
                          Text(
                            'For another code, sign in again.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _submitting ? null : _abandon,
                            child: const Text('Start over'),
                          ),
                        ] else
                          TextButton(
                            onPressed:
                                (_submitting || _resending || _cooldownLeft > 0)
                                ? null
                                : _resend,
                            child: Text(
                              _cooldownLeft > 0
                                  ? 'Send a new code (${_cooldownLeft}s)'
                                  : 'Send a new code',
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
```

The `_failure` from a verify attempt and `_resendFailure` are separate on purpose: one is about the typed code, the other about the send.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/auth/presentation/two_factor_screen_test.dart`
Expected: PASS. If a test leaves a pending timer, end it with `await tester.pump(resendCooldown)`.

- [ ] **Step 5: Gate and commit**

```bash
git add lib/features/auth/presentation/two_factor_screen.dart test/features/auth/presentation/two_factor_screen_test.dart
git commit -m "feat: offer a new email code at sign-in" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Document the UI-02 amendment

**Files:**
- Modify: `docs/requirements/Use Case Specification Document.md`, `docs/requirements/System Requirements Document.md`, `CHANGELOG.md`

- [ ] **Step 1: Use Case Specification**

- §1.4 index: UI-02's API column becomes `UC-38, UC-46`.
- UI-02's main flow: add a step, after the code is asked for, describing **Send a new code** (shown only for the email method and not with a recovery code; the hedged confirmation; the 30-second wait; three sends per challenge).
- UI-02's alternative flows: add AF-02f, AF-02g, AF-02h exactly as spec §4's table.
- Traceability row for UI-02: add FR-AU-26.

- [ ] **Step 2: System Requirements**

After FR-AU-25:

```markdown
| FR-AU-26 | The client shall request a new second-factor email code through `POST /api/auth/2fa/challenge/resend` while a challenge answered by email is outstanding, waiting 30 seconds between sends and offering at most three per challenge, after which it offers to start the sign-in again. | UI-02 |
```

- [ ] **Step 3: CHANGELOG**

Under `## [Unreleased]` → `### Added` (create the heading if absent):

```markdown
- **Send a new code** on the two-step verification screen when the code comes by email. It waits 30 seconds between
  sends and, after three, offers to start the sign-in again, matching the API's limit.
```

- [ ] **Step 4: Commit**

```bash
git add "docs/requirements/Use Case Specification Document.md" "docs/requirements/System Requirements Document.md" CHANGELOG.md
git commit -m "docs: amend ui-02 with the code resend" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Branch 3 — `feature/ui-32-erasure-requests`

Before Task 10: `git switch develop && git switch -c feature/ui-32-erasure-requests`.

### Task 10: Erasure-request domain and repository

**Files:**
- Create: `lib/features/erasure_requests/domain/outstanding_erasure.dart`
- Create: `lib/features/erasure_requests/domain/erasure_request_repository.dart`
- Create: `lib/features/erasure_requests/data/erasure_request_repository_impl.dart`
- Modify: `lib/main.dart`
- Test: `test/features/erasure_requests/domain/outstanding_erasure_test.dart`, `test/features/erasure_requests/data/erasure_request_repository_impl_test.dart`

**Interfaces:**
- Produces:
  - `class OutstandingErasure { const OutstandingErasure({required String subjectId, required bool isGoogleUser, DateTime? requestedAt, DateTime? dueAt, required bool overdue, String? blockedReason}); }` (fields of the same names).
  - `class ReconciliationOutcome { const ReconciliationOutcome({required int anonymised, required int alreadyAnonymised, required List<String> notFound}); }`
  - `class ParsedSubjectIds { const ParsedSubjectIds({required List<String> ids, required List<String> invalid}); bool get isEmpty => ids.isEmpty && invalid.isEmpty; }` and `ParsedSubjectIds parseSubjectIds(String text)`.
  - `abstract interface class ErasureRequestRepository { Future<Result<Page<OutstandingErasure>>> list({bool overdueOnly = false, int pageNumber = 1, int pageSize = 20}); Future<Result<ReconciliationOutcome>> reapply(List<String> subjectIds); }`
  - `final Provider<ErasureRequestRepository> erasureRequestRepositoryProvider` (throws until overridden, like `dataRightsRepositoryProvider`).
  - `class ApiErasureRequestRepository implements ErasureRequestRepository { const ApiErasureRequestRepository(AuthClient client); }`

- [ ] **Step 1: Write the failing parser tests**

`test/features/erasure_requests/domain/outstanding_erasure_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall_ui/features/erasure_requests/domain/outstanding_erasure.dart';

const _a = '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c';
const _b = '0a9b8c7d-6e5f-4a3b-8c2d-1e0f9a8b7c6d';

void main() {
  test('GivenIdsOnLines_WhenParsed_ThenEachIsKept', () {
    // Given / When
    final parsed = parseSubjectIds('$_a\n$_b\n');

    // Then
    expect(parsed.ids, <String>[_a, _b]);
    expect(parsed.invalid, isEmpty);
  });

  test('GivenCommasAndSpaces_WhenParsed_ThenTheyAllSeparate', () {
    // Given / When
    final parsed = parseSubjectIds(' $_a ,  $_b\t');

    // Then
    expect(parsed.ids, <String>[_a, _b]);
  });

  test('GivenRepeatsInMixedCase_WhenParsed_ThenEachIsKeptOnceLowercased', () {
    // Given / When
    final parsed = parseSubjectIds('$_a ${_a.toUpperCase()} $_a');

    // Then
    expect(parsed.ids, <String>[_a]);
  });

  test('GivenNonIdentifiers_WhenParsed_ThenTheyAreListedAsInvalid', () {
    // Given / When
    final parsed = parseSubjectIds('$_a not-an-id 1234');

    // Then
    expect(parsed.ids, <String>[_a]);
    expect(parsed.invalid, <String>['not-an-id', '1234']);
  });

  test('GivenOnlyWhitespace_WhenParsed_ThenNothingIsFound', () {
    // Given / When
    final parsed = parseSubjectIds(' \n , \t ');

    // Then
    expect(parsed.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/erasure_requests/domain`
Expected: FAIL — file missing.

- [ ] **Step 3: Write the domain**

`lib/features/erasure_requests/domain/outstanding_erasure.dart`:

```dart
/// One erasure request the anonymisation pass has not carried out yet
/// (UC-43). It names nobody: the subject asked to be erased, and the queue an
/// administrator works from is the last place to widen who sees them.
class OutstandingErasure {
  const OutstandingErasure({
    required this.subjectId,
    required this.isGoogleUser,
    required this.overdue,
    this.requestedAt,
    this.dueAt,
    this.blockedReason,
  });

  final String subjectId;
  final bool isGoogleUser;
  final DateTime? requestedAt;
  final DateTime? dueAt;
  final bool overdue;

  /// Why the pass cannot carry it out yet — usually that the subject is a
  /// scope's last owner. These are the requests that need an administrator.
  final String? blockedReason;
}

/// What re-applying erasures after a restore found.
class ReconciliationOutcome {
  const ReconciliationOutcome({
    required this.anonymised,
    required this.alreadyAnonymised,
    required this.notFound,
  });

  /// Identities the restore had brought back, now anonymised again.
  final int anonymised;
  final int alreadyAnonymised;

  /// Identifiers nothing answers to — the ordinary case for most of a ledger.
  final List<String> notFound;
}

/// A pasted ledger, split into identifiers and what is not one.
class ParsedSubjectIds {
  const ParsedSubjectIds({required this.ids, required this.invalid});

  final List<String> ids;
  final List<String> invalid;

  bool get isEmpty => ids.isEmpty && invalid.isEmpty;
}

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Splits [text] on commas and whitespace, keeps each identifier once
/// (lowercased, in first-seen order), and lists every entry that is not one.
ParsedSubjectIds parseSubjectIds(String text) {
  final ids = <String>[];
  final seen = <String>{};
  final invalid = <String>[];

  for (final entry in text.split(RegExp(r'[\s,]+'))) {
    if (entry.isEmpty) {
      continue;
    }

    if (!_uuid.hasMatch(entry)) {
      invalid.add(entry);

      continue;
    }

    final id = entry.toLowerCase();

    if (seen.add(id)) {
      ids.add(id);
    }
  }

  return ParsedSubjectIds(ids: ids, invalid: invalid);
}
```

- [ ] **Step 4: Run the parser tests**

Run: `flutter test test/features/erasure_requests/domain`
Expected: PASS.

- [ ] **Step 5: Write the failing repository tests**

`test/features/erasure_requests/data/erasure_request_repository_impl_test.dart` — copy the `_Answer` / `_StubAdapter` harness from `test/features/scopes/data/scope_repository_impl_test.dart`, building `ApiErasureRequestRepository(AuthClient(dio))`. Tests:

```dart
  test('GivenAPage_WhenListed_ThenRequestsAreMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'subjectId': '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
              'isGoogleUser': true,
              'requestedAt': '2026-09-01T10:00:00Z',
              'dueAt': '2026-10-01T10:00:00Z',
              'overdue': true,
              'blockedReason': 'The subject is the last owner of a scope.',
            },
          ],
          'pageNumber': 1,
          'pageSize': 20,
          'totalItems': 1,
          'totalPages': 1,
        },
      ),
    );

    // When
    final result = await repository.list();

    // Then
    final item = result.valueOrNull!.items.single;
    expect(item.isGoogleUser, isTrue);
    expect(item.overdue, isTrue);
    expect(item.dueAt, DateTime.utc(2026, 10, 1, 10));
    expect(item.blockedReason, 'The subject is the last owner of a scope.');
  });

  test('GivenOverdueOnly_WhenListed_ThenTheFilterTravels', () async {
    // Given
    final repository = repositoryAnswering(emptyPage);

    // When
    await repository.list(overdueOnly: true, pageNumber: 2);

    // Then
    expect(adapter.queries.single['OverdueOnly'], true);
    expect(adapter.queries.single['PageNumber'], 2);
  });

  test('GivenAScopeAdmin_WhenListed_ThenForbiddenIsReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 403,
        body: <String, dynamic>{'success': false, 'errors': <String>['Forbidden.']},
      ),
    );

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.forbidden);
    expect(result.failureOrNull!.errors, <String>['Forbidden.']);
  });

  test('GivenIds_WhenReapplied_ThenTheyTravelAndTheOutcomeIsMapped', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 200,
        body: <String, dynamic>{
          'success': true,
          'errors': <String>[],
          'data': <String, dynamic>{
            'anonymised': 1,
            'alreadyAnonymised': 2,
            'notFound': <String>['0a9b8c7d-6e5f-4a3b-8c2d-1e0f9a8b7c6d'],
          },
        },
      ),
    );

    // When
    final result = await repository.reapply(<String>[
      '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
    ]);

    // Then
    expect(adapter.bodies.single, <String, dynamic>{
      'subjectIds': <String>['6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c'],
    });
    expect(result.valueOrNull!.anonymised, 1);
    expect(result.valueOrNull!.alreadyAnonymised, 2);
    expect(result.valueOrNull!.notFound, hasLength(1));
  });

  test('GivenARefusedReconciliation_WhenReapplied_ThenApiErrorsAreReturned', () async {
    // Given
    final repository = repositoryAnswering(
      const _Answer(
        status: 400,
        body: <String, dynamic>{
          'success': false,
          'errors': <String>['At least one subject identifier is required.'],
        },
      ),
    );

    // When
    final result = await repository.reapply(const <String>['x']);

    // Then
    expect(result.failureOrNull!.errors, <String>[
      'At least one subject identifier is required.',
    ]);
  });

  test('GivenNoConnection_WhenListed_ThenNetworkFailureIsReturned', () async {
    // Given
    final repository = repositoryAnswering(const _Answer(status: 0));

    // When
    final result = await repository.list();

    // Then
    expect(result.failureOrNull!.kind, FailureKind.network);
  });
```

with `const emptyPage = _Answer(status: 200, body: <String, dynamic>{'success': true, 'errors': <String>[], 'data': <Map<String, dynamic>>[], 'pageNumber': 1, 'pageSize': 20, 'totalItems': 0, 'totalPages': 0});`.

- [ ] **Step 6: Run them to see them fail**

Run: `flutter test test/features/erasure_requests/data`
Expected: FAIL.

- [ ] **Step 7: Write the interface, the provider and the implementation**

`lib/features/erasure_requests/domain/erasure_request_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/envelope.dart';
import '../../../core/result/result.dart';
import 'outstanding_erasure.dart';

/// The erasure-request operations UI-32 depends on. System Admin only; the
/// API refuses anybody else.
abstract interface class ErasureRequestRepository {
  /// One page of outstanding requests, soonest deadline first (UC-43).
  Future<Result<Page<OutstandingErasure>>> list({
    bool overdueOnly = false,
    int pageNumber = 1,
    int pageSize = 20,
  });

  /// Re-applies erasure to [subjectIds] after a restore. Safe to repeat.
  Future<Result<ReconciliationOutcome>> reapply(List<String> subjectIds);
}

final Provider<ErasureRequestRepository> erasureRequestRepositoryProvider =
    Provider<ErasureRequestRepository>(
      (ref) => throw UnimplementedError(
        'erasureRequestRepositoryProvider must be overridden',
      ),
    );
```

`lib/features/erasure_requests/data/erasure_request_repository_impl.dart` — follows `ApiScopeRepository` exactly: `list` calls `_client.authListErasureRequests(overdueOnly: overdueOnly, pageNumber: pageNumber, pageSize: pageSize)`, maps a non-success envelope to `Failure(kind: FailureKind.validation, errors: …)`, maps each `ErasureRequestOutput` to `OutstandingErasure(subjectId: o.subjectId ?? '', isGoogleUser: o.isGoogleUser ?? false, requestedAt: o.requestedAt, dueAt: o.dueAt, overdue: o.overdue ?? false, blockedReason: (o.blockedReason?.trim().isEmpty ?? true) ? null : o.blockedReason)`, builds the `Page` from the envelope's paging (as `ApiScopeRepository.list`), and catches `DioException` with `failureFromDioException`. `reapply` calls `_client.authReapplyErasures(body: ReapplyErasuresCommand(subjectIds: subjectIds))` and maps `data` to `ReconciliationOutcome(anonymised: d.anonymised ?? 0, alreadyAnonymised: d.alreadyAnonymised ?? 0, notFound: d.notFound ?? const <String>[])`, with the same incomplete-response failure as the scope repository when `data` is null.

`lib/main.dart`: import both files and add to the overrides, after `dataRightsRepositoryProvider`:

```dart
        erasureRequestRepositoryProvider.overrideWith(
          (ref) =>
              ApiErasureRequestRepository(AuthClient(ref.watch(dioProvider))),
        ),
```

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/erasure_requests`
Expected: PASS.

- [ ] **Step 9: Gate and commit**

```bash
git add lib/features/erasure_requests lib/main.dart test/features/erasure_requests
git commit -m "feat: read and reconcile erasure requests" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: The erasure-requests screen, route and navigation

**Files:**
- Create: `lib/features/erasure_requests/presentation/erasure_request_list_controller.dart`
- Create: `lib/features/erasure_requests/presentation/erasure_request_list_screen.dart`
- Modify: `lib/app/router.dart`, `lib/app/route_access.dart`, `lib/features/home/presentation/destinations.dart`
- Test: `test/features/erasure_requests/presentation/erasure_request_list_controller_test.dart`, `test/features/erasure_requests/presentation/erasure_request_list_screen_test.dart`, `test/app/route_access_test.dart`, the destinations test (find it with `grep -rln destinationsFor test`)

**Interfaces:**
- Consumes: Task 10's repository and provider.
- Produces:
  - `class ErasureRequestQuery { const ErasureRequestQuery({bool overdueOnly = false, int pageNumber = 1}); copyWith(...) }`
  - `sealed class ErasureRequestListState { final ErasureRequestQuery query; }`; `ErasureRequestListLoading`, `ErasureRequestListLoaded(query, Page<OutstandingErasure> page, {bool busy = false})`, `ErasureRequestListFailed(query, Failure failure)`.
  - `final NotifierProvider<ErasureRequestListController, ErasureRequestListState> erasureRequestListControllerProvider`.
  - `ErasureRequestListController`: `load()`, `setOverdueOnly(bool)`, `goToPage(int)`.
  - `class ErasureRequestListScreen extends ConsumerStatefulWidget` (no arguments); route `/erasure-requests`.

- [ ] **Step 1: Write the failing controller tests**

Mirror `google_user_list_controller`'s tests (find them with `grep -rln GoogleUserListController test`) for: loads the first page; `setOverdueOnly(true)` asks with `overdueOnly: true, pageNumber: 1`; `goToPage(2)` keeps the filter; a failure keeps the query (AF-32h); a query asked while one is in flight is asked after it (not lost). Use mocktail `_MockErasureRequestRepository` overriding `erasureRequestRepositoryProvider`.

```dart
  test('GivenOverdueOnly_WhenSet_ThenTheFirstPageIsAskedForFiltered', () async {
    // Given
    answerListWith(Success<Page<OutstandingErasure>>(_page()));
    final controller = controllerUnderTest();
    await controller.load();

    // When
    await controller.setOverdueOnly(true);

    // Then
    verify(
      () => repository.list(overdueOnly: true, pageNumber: 1),
    ).called(1);
    expect(currentState().query.overdueOnly, isTrue);
  });
```

(Write the other four in the same shape; `_page({List<OutstandingErasure> items = const []})` builds a one-page `Page`.)

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/erasure_requests/presentation/erasure_request_list_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Write the controller**

`erasure_request_list_controller.dart`: the same structure as `GoogleUserListController` (`_inFlight`, `_queued`, `_fetch`), not a family, with `ErasureRequestQuery { overdueOnly, pageNumber }` and `isFiltered => overdueOnly`. `_fetch` calls `ref.read(erasureRequestRepositoryProvider).list(overdueOnly: query.overdueOnly, pageNumber: query.pageNumber)`. Provider:

```dart
final NotifierProvider<ErasureRequestListController, ErasureRequestListState>
erasureRequestListControllerProvider =
    NotifierProvider<ErasureRequestListController, ErasureRequestListState>(
      ErasureRequestListController.new,
    );
```

- [ ] **Step 4: Run the controller tests**

Expected: PASS.

- [ ] **Step 5: Write the failing screen tests**

`erasure_request_list_screen_test.dart` — harness as `google_user_list_screen_test.dart` (System Admin token, router with `/erasure-requests`), with a `_MockErasureRequestRepository`. Fixtures:

```dart
final _blocked = OutstandingErasure(
  subjectId: '6f1c2b9e-0d4a-4c1e-9a3b-2f6d8e7a1b0c',
  isGoogleUser: false,
  requestedAt: DateTime.utc(2026, 9, 1),
  dueAt: DateTime.utc(2026, 10, 1),
  overdue: true,
  blockedReason: 'The subject is the last owner of a scope.',
);
```

Tests:
- `GivenRequests_WhenOpened_ThenEachShowsItsSubjectAndDeadline` — finds the subject id, `'Person'`, `'Overdue'`, the blocked reason.
- `GivenRequests_WhenOpened_ThenTheNoNamesNoteIsShown` — finds `'Names and email addresses are not shown: these people have asked to be erased.'`.
- `GivenNoRequests_WhenOpened_ThenTheEmptyStateIsShown` (AF-32a) — `'No outstanding erasure requests.'`.
- `GivenOverdueOnly_WhenNoneAreOverdue_ThenTheFilteredEmptyStateIsShown` (AF-32b) — tap `FilterChip` `'Overdue only'`; finds `'Nothing is overdue.'`.
- `GivenARefusedListing_WhenOpened_ThenApiErrorsAreShown` (AF-32c) — a `forbidden` failure with errors `['Forbidden.']` shows `'Forbidden.'`.
- `GivenATransportFailure_WhenOpened_ThenRetryIsOffered` (AF-32h).
- `GivenACopyControl_WhenTapped_ThenTheIdIsOnTheClipboard` — as `GivenAScope_WhenCopyIdTapped_ThenTheIdIsOnTheClipboard` in `scope_detail_screen_test.dart`.
- Compact, medium, expanded and dark-theme renders, each asserting the subject id is found and `tester.takeException()` is null.

- [ ] **Step 6: Run them to see them fail**

Expected: FAIL.

- [ ] **Step 7: Write the screen**

`erasure_request_list_screen.dart`: `AppShell(currentRoute: '/erasure-requests', title: const Text('Erasure requests'), body: …)`; `initState` loads the controller post-frame. Body is a `Column`:

1. A `Padding(EdgeInsets.fromLTRB(12, 12, 12, 0))` → `Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: center)` holding `FilterChip(label: Text('Overdue only'), selected: state.query.overdueOnly, onSelected: controller.setOverdueOnly)` and `TextButton.icon(icon: Icon(Icons.restore_outlined), label: Text('Re-apply erasures'), onPressed: _reapply)` (`_reapply` opens Task 12's dialog; until Task 12, leave `onPressed: null` and remove this note when Task 12 wires it).
2. A `Padding` with `Text('Names and email addresses are not shown: these people have asked to be erased.', style: bodySmall)`.
3. `Expanded` switching on the state: `CollectionLoading()`; failed → `CollectionFailed(failure:, onRetry: controller.load)` (it shows the API's errors and a retry); loaded and empty → `CollectionEmpty(title: query.overdueOnly ? 'Nothing is overdue.' : 'No outstanding erasure requests.', message: query.overdueOnly ? 'Every outstanding request is still within its deadline.' : 'Every request made so far has been carried out.', icon: Icons.task_alt_outlined, actionLabel: query.overdueOnly ? 'Show all' : null, onAction: query.overdueOnly ? () => controller.setOverdueOnly(false) : null)`; loaded → `AdaptiveCollection<OutstandingErasure>(items:, busy:, pageNumber:, totalPages:, totalItems:, onPageChanged: controller.goToPage, title: (e) => e.subjectId, subtitle: (e) => e.isGoogleUser ? 'Google user' : 'Person', columns: …)` with columns `Kind` (`'Google user'`/`'Person'`), `Requested` and `Due` (`MaterialLocalizations.of(context).formatMediumDate(at.toLocal())`, `'—'` when null), `Status` (`Chip(label: Text('Overdue'))` coloured `errorContainer` when overdue, else `Text('Within deadline')`), `Blocked` (`blockedReason ?? '—'`), and `Copy` (`IconButton(icon: Icon(Icons.copy_outlined), tooltip: 'Copy the identifier', onPressed: …)` that writes `subjectId` to the clipboard and shows the snack bar `'Identifier copied.'`). Monospace style (`fontFamily: 'monospace'`) for the subject id where the collection renders the title, if `AdaptiveCollection` allows; otherwise leave the default.

- [ ] **Step 8: Route, access and navigation**

`lib/app/router.dart`: add `GoRoute(path: '/erasure-requests', builder: (context, state) => const ErasureRequestListScreen())` before `/health`.

`lib/app/route_access.dart`, before the `/health` case:

```dart
  // UC-43 excludes a Scope Admin on purpose: who has asked to be erased is not
  // theirs to know.
  '/erasure-requests' => role == Role.systemAdmin,
```

`lib/features/home/presentation/destinations.dart`, before Health:

```dart
  if (principal.isSystemAdmin)
    const AppDestination(
      label: 'Erasure requests',
      icon: Icons.person_remove_outlined,
      selectedIcon: Icons.person_remove,
      route: '/erasure-requests',
    ),
```

Tests: in `route_access_test.dart`, `GivenASystemAdmin_WhenErasureRequestsAsked_ThenTheyAreReachable` and `GivenAScopeAdmin_WhenErasureRequestsAsked_ThenTheyAreNot`; in the destinations test, `GivenASystemAdmin_WhenNavigationIsBuilt_ThenErasureRequestsIsOffered` and `GivenAScopeAdmin_WhenNavigationIsBuilt_ThenErasureRequestsIsNot`. If a test asserts the exact number of destinations for a System Admin, update its expectation and say so in the report. Check the compact bottom bar still fits (it has a destination limit in Material 3 — if `AdaptiveScaffold` caps or overflows at five, report it rather than changing the shell).

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/erasure_requests test/app test/features/home`
Expected: PASS.

- [ ] **Step 10: Gate and commit**

```bash
git add lib/features/erasure_requests/presentation lib/app/router.dart lib/app/route_access.dart lib/features/home/presentation/destinations.dart test/features/erasure_requests/presentation test/app test/features/home
git commit -m "feat: add the erasure requests screen" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Re-apply erasures after a restore

**Files:**
- Create: `lib/features/erasure_requests/presentation/reconciliation_controller.dart`
- Create: `lib/features/erasure_requests/presentation/reconciliation_dialog.dart`
- Modify: `lib/features/erasure_requests/presentation/erasure_request_list_screen.dart` (wire the button)
- Test: `test/features/erasure_requests/presentation/reconciliation_controller_test.dart`, `test/features/erasure_requests/presentation/reconciliation_dialog_test.dart`

**Interfaces:**
- Consumes: `parseSubjectIds`, `ErasureRequestRepository.reapply`, `erasureRequestListControllerProvider` (to refresh after a run).
- Produces:
  - `sealed class ReconciliationState`; `ReconciliationEditing({List<String> invalid = const [], bool empty = false, Failure? failure})`, `ReconciliationSending`, `ReconciliationDone(ReconciliationOutcome outcome)`.
  - `final NotifierProvider<ReconciliationController, ReconciliationState> reconciliationControllerProvider` (auto-dispose, so each dialog starts fresh: `NotifierProvider.autoDispose`).
  - `ReconciliationController`: `ParsedSubjectIds? check(String text)` (returns the parse when sendable, else sets `ReconciliationEditing` with `invalid` or `empty` and returns `null`), `Future<void> send(List<String> ids)`.
  - `Future<void> showReconciliationDialog(BuildContext context)`.

- [ ] **Step 1: Write the failing controller tests**

```dart
  // AF-32e
  test('GivenAnEmptyPaste_WhenChecked_ThenNothingIsSendable', () {
    // Given
    final controller = controllerUnderTest();

    // When
    final parsed = controller.check('  \n ');

    // Then
    expect(parsed, isNull);
    expect((currentState() as ReconciliationEditing).empty, isTrue);
  });

  // AF-32d
  test('GivenInvalidEntries_WhenChecked_ThenTheyAreListed', () {
    // Given
    final controller = controllerUnderTest();

    // When
    final parsed = controller.check('$_a not-an-id');

    // Then
    expect(parsed, isNull);
    expect((currentState() as ReconciliationEditing).invalid, <String>['not-an-id']);
  });

  test('GivenValidIds_WhenChecked_ThenTheyAreSendable', () {
    // Given
    final controller = controllerUnderTest();

    // When
    final parsed = controller.check('$_a\n${_a.toUpperCase()}');

    // Then
    expect(parsed!.ids, <String>[_a]);
  });

  test('GivenIds_WhenSent_ThenTheOutcomeIsShownAndTheListRefreshes', () async {
    // Given
    when(() => repository.reapply(<String>[_a])).thenAnswer(
      (_) async => const Success<ReconciliationOutcome>(
        ReconciliationOutcome(anonymised: 1, alreadyAnonymised: 0, notFound: <String>[]),
      ),
    );
    answerListWith(Success<Page<OutstandingErasure>>(_page()));
    final controller = controllerUnderTest();

    // When
    await controller.send(<String>[_a]);

    // Then
    expect((currentState() as ReconciliationDone).outcome.anonymised, 1);
    verify(() => repository.list(overdueOnly: false, pageNumber: 1)).called(1);
  });

  // AF-32g
  test('GivenARefusal_WhenSent_ThenTheErrorsAreKept', () async {
    // Given
    const refusal = Failure(
      kind: FailureKind.validation,
      errors: <String>['At least one subject identifier is required.'],
    );
    when(() => repository.reapply(any())).thenAnswer(
      (_) async => const FailureResult<ReconciliationOutcome>(refusal),
    );
    final controller = controllerUnderTest();

    // When
    await controller.send(<String>[_a]);

    // Then
    expect((currentState() as ReconciliationEditing).failure, same(refusal));
  });
```

(`controllerUnderTest` keeps a listener on the auto-dispose provider — `container.listen(reconciliationControllerProvider, (_, _) {})` — so it is not disposed between calls.)

- [ ] **Step 2: Run them to see them fail**

Expected: FAIL.

- [ ] **Step 3: Write the controller**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../domain/erasure_request_repository.dart';
import '../domain/outstanding_erasure.dart';
import 'erasure_request_list_controller.dart';

/// Where the re-apply dialog is.
sealed class ReconciliationState {
  const ReconciliationState();
}

/// The paste is being written or corrected.
final class ReconciliationEditing extends ReconciliationState {
  const ReconciliationEditing({
    this.invalid = const <String>[],
    this.empty = false,
    this.failure,
  });

  /// AF-32d — entries that are not identifiers. Nothing is sent while any are.
  final List<String> invalid;

  /// AF-32e — nothing was pasted. The API refuses an empty run on purpose: it
  /// almost always means the ledger was not loaded.
  final bool empty;

  /// AF-32g / AF-32h — the API refused, or could not be reached.
  final Failure? failure;
}

final class ReconciliationSending extends ReconciliationState {
  const ReconciliationSending();
}

final class ReconciliationDone extends ReconciliationState {
  const ReconciliationDone(this.outcome);

  final ReconciliationOutcome outcome;
}

final NotifierProvider<ReconciliationController, ReconciliationState>
reconciliationControllerProvider =
    NotifierProvider.autoDispose<ReconciliationController, ReconciliationState>(
      ReconciliationController.new,
    );

/// The Operations runbook step after a restore: re-apply every erasure the
/// anonymisation pass has logged since the backup was taken.
class ReconciliationController extends Notifier<ReconciliationState> {
  @override
  ReconciliationState build() => const ReconciliationEditing();

  /// The paste, when it can be sent; otherwise `null`, with the reason in the
  /// state.
  ParsedSubjectIds? check(String text) {
    final parsed = parseSubjectIds(text);

    if (parsed.ids.isEmpty && parsed.invalid.isEmpty) {
      state = const ReconciliationEditing(empty: true);

      return null;
    }

    if (parsed.invalid.isNotEmpty) {
      state = ReconciliationEditing(invalid: parsed.invalid);

      return null;
    }

    state = const ReconciliationEditing();

    return parsed;
  }

  Future<void> send(List<String> ids) async {
    if (state is ReconciliationSending) {
      return;
    }

    state = const ReconciliationSending();

    final result = await ref.read(erasureRequestRepositoryProvider).reapply(ids);

    state = result.fold(
      onSuccess: ReconciliationDone.new,
      onFailure: (failure) => ReconciliationEditing(failure: failure),
    );

    // A restored identity anonymised again leaves the queue; show it gone.
    if (result.isSuccess) {
      await ref.read(erasureRequestListControllerProvider.notifier).load();
    }
  }
}
```

If the repo's Riverpod version types `NotifierProvider.autoDispose` differently, use the type the analyzer infers and keep the auto-dispose behaviour.

- [ ] **Step 4: Run the controller tests**

Expected: PASS.

- [ ] **Step 5: Write the failing dialog tests**

`reconciliation_dialog_test.dart` — pump a `MaterialApp` whose home has a button calling `showReconciliationDialog(context)`, with the repository mock overridden. Tests:
- `GivenTheDialog_WhenOpened_ThenTheRunbookStepIsExplained` — finds `'Paste the identifiers the anonymisation pass logged since the backup was taken.'`.
- `GivenAnEmptyPaste_WhenSubmitted_ThenItIsRefused` — tap `'Re-apply'`; finds `'Paste at least one identifier.'`; `verifyNever(() => repository.reapply(any()))`.
- `GivenInvalidEntries_WhenSubmitted_ThenTheyAreListed` — finds `'These are not identifiers: not-an-id'`.
- `GivenIds_WhenSubmitted_ThenItAsksOnceMore` — after entering two valid ids (one repeated in upper case), tapping `'Re-apply'` shows `'Re-apply erasure to 1 identifier?'` (singular for 1, `'… to N identifiers?'` otherwise).
- `GivenTheConfirmation_WhenCancelled_ThenNothingIsSentAndThePasteIsKept` (AF-32f).
- `GivenTheConfirmation_WhenConfirmed_ThenTheOutcomeIsShown` — finds `'Anonymised: 1'`, `'Already anonymised: 0'`, `'Not found: 1'`, the not-found id, and `'Not found is the ordinary case for most of the ledger.'`.
- `GivenARefusal_WhenConfirmed_ThenApiErrorsAreShownAndThePasteIsKept` (AF-32g).
- Dark theme render.

- [ ] **Step 6: Run them to see them fail**

Expected: FAIL.

- [ ] **Step 7: Write the dialog and wire it**

`reconciliation_dialog.dart`: `showReconciliationDialog` opens `showDialog` with a `ConsumerStatefulWidget` `_ReconciliationDialog` (`AlertDialog(scrollable: true, title: Text('Re-apply erasures'))`). It holds a `TextEditingController` for the paste. Content by state:

- `ReconciliationEditing` / `ReconciliationSending`: the explanation `Text('Paste the identifiers the anonymisation pass logged since the backup was taken. Commas, spaces and new lines all separate them.')`; a `TextField(controller:, minLines: 6, maxLines: 12, decoration: InputDecoration(labelText: 'Identifiers', errorText: empty ? 'Paste at least one identifier.' : invalid.isNotEmpty ? 'These are not identifiers: ${invalid.join(', ')}' : null))`; `ErrorBanner(failure:)` when a failure is held (a network failure included). Actions: `TextButton('Cancel')` closes; `FilledButton('Re-apply')` (disabled while sending) runs:

```dart
  Future<void> _submit() async {
    final controller = ref.read(reconciliationControllerProvider.notifier);
    final parsed = controller.check(_paste.text);

    if (parsed == null) {
      return;
    }

    final count = parsed.ids.length;
    final confirmed = await showConfirm(
      context: context,
      title: count == 1
          ? 'Re-apply erasure to 1 identifier?'
          : 'Re-apply erasure to $count identifiers?',
      message:
          'Each identity the restore brought back is anonymised again. '
          'Running this twice anonymises nothing extra.',
      confirmLabel: 'Re-apply',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await controller.send(parsed.ids);
  }
```

- `ReconciliationDone`: `Text('Anonymised: ${o.anonymised}')`, `Text('Already anonymised: ${o.alreadyAnonymised}')`, `Text('Not found: ${o.notFound.length}')`, then when any are not found: a `SelectableText(o.notFound.join('\n'), style: monospace)`, a copy `TextButton.icon('Copy')` writing them to the clipboard, and `Text('Not found is the ordinary case for most of the ledger.')`. Action: `FilledButton('Done')` closes.

In `erasure_request_list_screen.dart`, `_reapply` becomes `showReconciliationDialog(context)` and the button's `onPressed: _reapply`.

- [ ] **Step 8: Run the tests**

Run: `flutter test test/features/erasure_requests`
Expected: PASS.

- [ ] **Step 9: Gate and commit**

```bash
git add lib/features/erasure_requests/presentation test/features/erasure_requests/presentation
git commit -m "feat: re-apply erasures after a restore" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Document UI-32

**Files:**
- Modify: `docs/requirements/Use Case Specification Document.md`, `docs/requirements/System Requirements Document.md`, `CHANGELOG.md`

- [ ] **Step 1: Use Case Specification**

- §1.4 index: `| UI-32 | Review outstanding erasure requests | UC-43 |` (the reconciliation endpoint has no API use case number; name it in the section).
- Diagram: add `UI32[UI-32: Erasure requests]` in the System Admin area, in the existing style.
- New section `### UI-32: Review outstanding erasure requests` after UI-31 (or after UI-30 on this branch): actor System Admin only, with the UC-43 reason for excluding Scope Admins; main flow per spec §5.2 and §5.3 with the exact copy; AF-32a…AF-32h per spec §5.4.
- Traceability: `| UI-32 | FR-DA-01, FR-DA-02 |`.

- [ ] **Step 2: System Requirements**

After §2.7, add:

```markdown
### 2.8 Data subject administration (`FR-DA`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-DA-01 | The client shall list outstanding erasure requests through `GET /api/auth/erasure-requests`, paginated by the API, soonest deadline first, with an overdue-only filter, showing no name or email address. | UI-32 |
| FR-DA-02 | The client shall re-apply erasures after a restore through `POST /api/auth/erasure-reconciliation`, sending only a non-empty, de-duplicated list of identifiers after confirmation, and shall show how many were anonymised, already anonymised and not found. | UI-32 |
```

- Screen inventory: `| \`/erasure-requests\` | Outstanding erasure requests; re-apply erasures after a restore | UI-32 |` before `/health`.
- Authorization matrix: `| Erasure requests | Full | Hidden | Hidden | Hidden |` before Health.
- FR-UX-04 and FR-UX-06 use-case columns: add UI-32.

- [ ] **Step 3: CHANGELOG**

Under `## [Unreleased]` → `### Added`:

```markdown
- An **Erasure requests** screen for System Admins: the erasure requests not yet carried out, soonest deadline first,
  with the overdue and blocked ones marked and an overdue-only filter. From it, **Re-apply erasures** runs the
  post-restore step: paste the identifiers from the logs, confirm, and see what was anonymised again.
```

- [ ] **Step 4: Commit**

```bash
git add "docs/requirements/Use Case Specification Document.md" "docs/requirements/System Requirements Document.md" CHANGELOG.md
git commit -m "docs: specify ui-32 erasure requests" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## After all tasks

Not part of any task; done by the controller with the user's approval, per the Development Workflow Document: a GitHub issue per branch (UI-31, the UI-02 amendment, UI-32), the README backlog rows (UI-31 and UI-32 under their sections; the four API gaps of spec §8 as new rows), pushing each branch, and a PR into `develop` for each. Then the 1.7.0 changelog PR and the release.
