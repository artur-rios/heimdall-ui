# Changelog

All notable changes to Heimdall UI are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Flutter 3.44.9 → 3.47.7 (Dart 3.12.2 → 3.13.5) in CI, the container image and the SDK constraint. The Dart 3.13
  formatter reflows some existing code, and the Flutter tool now excludes the build and platform directories from
  analysis. The generated API client is unchanged.

### Fixed

- The health check calls `GET /api/healthcheck` and `GET /api/healthcheck/detailed`, where the Heimdall API now
  serves them alongside every other endpoint, instead of `/HealthCheck`. The vendored API specification and the
  generated client carry the new routes.

## [1.1.0] - 2026-10-09

### Changed

- The vendored API specification and the generated client now match the Heimdall API's `develop` branch: the
  client carries the data-export, erasure, processing-restriction and two-factor code resend endpoints and a
  scope's lawful basis and privacy notice. No screen uses the new endpoints yet.
- The vendored API specification and the generated client are synced again with the Heimdall API's `develop`
  after its review fixes: `GET /api/scopes` is documented as open to Scope Admins (their own scopes), the two-factor
  status and data-export descriptions are no longer swapped, and the data subject rights endpoints say a restricted
  subject can reach them. Only documentation comments in the client change.
- Dependency: `flutter_riverpod` 2.6.1 → 3.4.3. Family controllers take their argument through the constructor,
  `Override` and the family types come from `flutter_riverpod/misc.dart`, and `AsyncValue.valueOrNull` becomes
  `value`. Riverpod 3's automatic retry of failing providers is turned off for the whole app
  (`ProviderScope(retry: …)`), so a failure is shown once and retried by the user, as before.
- `HEIMDALL_API_BASE_URL` defaults to `http://localhost:8080`, the local heimdall-api's Docker Compose port, instead
  of `http://localhost:5000`. A build that sets it is unaffected.
- Four deployment environments: `local` (Docker Desktop on Windows, by hand), and `development`, `homologation` and
  `production`, which share one VPS and are deployed by yggdrasil — `develop` to development, `release/x.y.z` to
  homologation, the release pull request to production. Development and homologation run on demand. Every deployed
  build calls the API under its own origin; the README and the Operations & Infrastructure Document list each
  environment's API base URL, and `config/local.json.example` holds the local values for `--dart-define-from-file`.

### Fixed

- The vendored API specification (`api/heimdall.json`) names the Heimdall API's actual licence, "ArturRios.Heimdall
  — Proprietary License", instead of MIT. The generated client is unchanged: it does not carry the licence.
- Saving a scope's name or description no longer clears the lawful basis and privacy notice address set for it
  through the API. The API replaces both on every update, and the edit now sends back the values the scope holds.
- Signing in as a Scope Admin no longer leaves the app spinning, at sign-in and at every later start-up: the
  owned-scopes claim the API writes as one comma-separated string is read as such. The person's id is read from the
  API's `id` claim, so the profile screen and the "this is you" checks work for every role.
- A mistyped second-factor code at sign-in keeps the challenge open for another try, instead of ending it and sending
  the person back to sign in.
- A wrong password or code when turning two-factor authentication off or regenerating recovery codes is shown on the
  screen, instead of signing the person out as if their session had expired.
- Turning two-factor authentication off works. The dialog asks for the password and a code or recovery code, both of
  which the API requires; it used to send only one, which the API always refused.
- When the API rejects a Google session's token, the session ends once. It used to call the API's Google sign-out
  with the rejected token, which was rejected again and started another sign-out, without end.
- Start-up no longer stays on the loading screen when the platform's secure storage cannot be read (on Linux, a
  keyring that is not running or is locked), and signing in says so when the session cannot be stored.
- A User can reach their profile and two-factor settings from the home screen, which now names the signed-in
  person instead of showing an empty "Signed in as".
- An application's owner is chosen from the scope's owners only, and a Scope Admin creating one is offered only
  themselves — the only owners the API accepts.
- A Scope Admin is shown a scope's name and description, and a co-owner's record, read-only instead of being offered
  saves and deletions the API refuses. Health and diagnostics appear in a Scope Admin's navigation, matching the
  read-only access they already had.
- Forms check what the API checks before sending: passwords of at least 8 characters when creating a person or
  resetting a password, names up to 200 and descriptions up to 500 characters, and email addresses with exactly one
  `@` that has text on both sides.
- Error banners are announced by screen readers, the two-factor QR code is labelled, every back button has a
  tooltip, and the web page declares its language.

### Security

- The Android app opts out of auto backup, so the encrypted session token is never copied to a cloud backup or to a
  device that cannot decrypt it.

## [1.0.1] - 2026-09-29

### Fixed

- The web build routes on the URL path instead of the hash, so the password reset (`/password-reset?token=`) and
  email verification (`/verify-email?token=`) links the API emails open their screens instead of sending the caller
  to sign-in with the token lost.

## [1.0.0] - 2026-09-29

First release.

### Added

- One Flutter codebase for web, Windows, Linux and Android, over a client generated from the Heimdall API's OpenAPI
  specification.
- Sign-in with an optional two-factor challenge, password recovery and reset, email verification and its resend,
  and Google Sign-In and sign-out.
- Routes guarded by session and role (System Admin, Scope Admin, User), with an adaptive shell and light and dark
  themes.
- Own profile editing and two-factor authentication management.
- Administration of scopes (including their owners and Google Sign-In), persons, applications, scope permissions
  and Google users, each with logical and permanent deletion.
- An API health and diagnostics screen.
- A container image that serves the web build with nginx on port 8080, with a `/healthz` probe.

[Unreleased]: https://github.com/artur-rios/heimdall-ui/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/artur-rios/heimdall-ui/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/artur-rios/heimdall-ui/releases/tag/v1.0.0
