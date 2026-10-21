---
title: "Testing Specification Document"
linkTitle: "Testing Specification Document"
weight: 50
description: "How each use case is tested: the levels, the naming convention, the structure, and what coverage means here."
---

# Testing Specification Document — Heimdall UI

## 1. Purpose

This document defines **how tests are written** for Heimdall UI, so that every use case receives the
same shape of testing with the same tools, naming, and structure. The
[Development Workflow Document](Development%20Workflow%20Document.md) defines *when* testing happens
in the delivery flow; the [Technology Stack Document](Technology%20Stack%20Document.md) records the
tools themselves.

---

## 2. Levels

| Level | What it covers | Where it lives |
| --- | --- | --- |
| **Unit** | Controllers and notifiers, repository implementations, envelope unwrapping, guards, mappers, and any pure function | `test/`, mirroring `lib/` |
| **Widget** | Screens and shared widgets: what renders, what the user can do, and how the layout responds to the breakpoint | `test/`, mirroring `lib/` |
| **Flow** | Whole flows across several screens, driven through the real router against fakes — a widget test that pumps the app with `pumpApp(router: ...)` | `test/app/` and the feature's own `presentation/` tests |

`test/` mirrors `lib/` one directory at a time: `lib/features/auth/presentation/session_controller.dart`
is tested by `test/features/auth/presentation/session_controller_test.dart`. A test file that does
not correspond to a source file is a sign the source is in the wrong place.

---

## 3. The network rule

**No test reaches the network.** There is no exception, including flow tests.

- Repository and interceptor tests replace Dio's `HttpClientAdapter` with a local adapter that
  answers from memory and records what it was asked for.
- Controller and screen tests depend on a fake repository, not on Dio at all.
- Flow tests run the real router against the same fakes.

A test that would pass or fail depending on a live API is not a test of this repository.

---

## 4. Naming and structure

Every test method is named:

```
GivenSomeCondition_WhenSomeAction_ThenSomeOutput
```

and its body is divided into three commented sections, in order:

```dart
test('GivenExpiredToken_WhenSessionRestored_ThenSessionIsUnauthenticated', () async {
  // Given
  final store = InMemoryTokenStore();
  await store.write(AuthToken(value: 'jwt', expiresAt: DateTime.utc(2000)));

  // When
  final restored = await restoreSession(store);

  // Then
  expect(restored, isA<Unauthenticated>());
});
```

- **Given** builds the world: fakes, seeded state, stubbed responses.
- **When** performs exactly one action — the thing under test.
- **Then** asserts. A test asserting two unrelated outcomes is two tests.

Where a step has nothing to do, the comment stays and says so (`// Given / When`), so the three
sections are always visible.

---

## 5. What each use case must cover

A use case is not tested until every one of these holds:

1. **The main flow** has a test, at the level that flow lives at.
2. **Every alternative flow** in the use case specification has a test, named after the behavior
   rather than the identifier — the `AF-xx` identifier belongs in a comment, not in the method name.
3. **The screen** has widget tests at all three breakpoints where its layout differs.
4. **Both themes** render without a hard-coded color: verified by pumping the screen under the dark
   theme and asserting no assertion fires and the key text is present.
5. **The error path** shows the API's `errors` array as returned, asserted against a stubbed
   envelope with a known error string.

### 5.1 Worked example — UI-01

| Flow | Level | Test |
| --- | --- | --- |
| Main | Unit | `GivenValidCredentials_WhenSignedIn_ThenSessionIsAuthenticated` |
| Main | Widget | `GivenLoginScreen_WhenSubmittedWithValidInput_ThenControllerIsCalled` |
| AF-01a | Unit | `GivenInvalidCredentials_WhenSignedIn_ThenSessionStaysUnauthenticated` |
| AF-01a | Widget | `GivenRejectedLogin_WhenRendered_ThenApiErrorsAreShown` |
| AF-01b | Widget | `GivenEmptyPassword_WhenSubmitted_ThenNoRequestIsMade` |
| AF-01c | Unit | `GivenTwoFactorRequired_WhenSignedIn_ThenSessionIsChallenged` |
| AF-01d | Unit | `GivenTransportFailure_WhenSignedIn_ThenNetworkFailureIsReturned` |

---

## 6. Test doubles

| Double | Use |
| --- | --- |
| `InMemoryTokenStore` | Everywhere a `TokenStore` is needed. The secure store is never exercised in a test. |
| A `mocktail` mock of the repository interface | Controller tests: stub the `Result` the repository returns. |
| A local `HttpClientAdapter` | Repository and interceptor tests: answer with a real envelope body and status. |
| `SharedPreferences.setMockInitialValues` | Any test touching a persisted preference. |

Stub the **interface**, never the generated client. A test that mentions a generated type outside
`test/features/*/data/` is testing the wrong layer.

---

## 7. Running the tests

There is no `integration_test/` directory and no device-driven test: the whole suite is `flutter test`.
Shared helpers live in `test/support/` (`pumpApp`, `testApiJwt`, `StubAdapter`, the idle session-expiry
timer), and the accessibility checks in `test/a11y/`. CONTRIBUTING.md shows where to start for a new test.

```bash
flutter test
```

CI runs it as `flutter test --coverage` and uploads `coverage/lcov.info` as the `coverage-lcov` artifact for
reading. Coverage has no threshold, so it does not fail a pull request. To see it locally:

```bash
flutter test --coverage
```

The gate before a pull request is these three, in order, all passing:

```bash
dart format --set-exit-if-changed .
```

```bash
flutter analyze
```

```bash
flutter test
```

---

## 8. What is not tested

- **The generated client's own correctness.** It is generated from the API's specification and
  guarded by the drift check; a test asserting that a generated field deserializes is a test of the
  generator. The one exception is the smoke test proving the package is importable and constructs
  without a request.
- **The API's behavior.** Every API rule — authorization, uniqueness, token validity — is the API's
  own test suite's responsibility. Here, the API is a stub that answers as its specification says.
- **Pixel-exact appearance.** Widget tests assert structure and behavior, not layout geometry.

---

## 9. References

- [Use Case Specification Document](Use%20Case%20Specification%20Document.md) — the flows that must be covered.
- [Development Workflow Document](Development%20Workflow%20Document.md) — when the testing gate applies.
- [Technology Stack Document](Technology%20Stack%20Document.md) — the testing tools and versions.
