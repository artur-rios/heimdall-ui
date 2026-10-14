# Scope sign-in settings and the admin gaps — Design

Date: 2026-10-13
Status: Draft

## 1. Purpose

An administrator should be able to take a scope from nothing to open for business without leaving
Heimdall UI: create the scope, add its owners, applications, permissions and persons, point its
emails at the client application's screens, and open it to Google Sign-In and self-registration.

Heimdall API 1.4.0 added two scope settings the UI cannot reach — self-registration (UC-47 toggle,
`PUT /api/scopes/{id}/self-registration`) and the per-scope email links
(`PUT /api/scopes/{id}/email-links`) — so today the last two steps of that journey need `curl`.
A survey of the API against the UI found two more endpoints the UI never calls. This design closes
all four with UI work alone; the gaps that need new API endpoints are recorded in §8 and left to
their own designs.

| # | Gap | API | Delivered by |
| --- | --- | --- | --- |
| 1 | Self-registration switch | `PUT /api/scopes/{id}/self-registration` | UI-31 |
| 2 | Per-scope email links | `PUT /api/scopes/{id}/email-links` | UI-31 |
| 3 | Resend the second-factor email code at sign-in | `POST /api/auth/2fa/challenge/resend` (UC-46) | UI-02 amendment |
| 4 | Outstanding erasure requests and the post-restore reconciliation | `GET /api/auth/erasure-requests` (UC-43), `POST /api/auth/erasure-reconciliation` | UI-32 |

## 2. Constraints

- Heimdall UI only. No API change; the API is the authority on every rule, and the UI's own checks
  only spare a round trip.
- The committed specification `api/heimdall.json` predates API 1.4.0 (it lacks `/api/auth/register`,
  `/api/scopes/{id}/self-registration` and `/api/scopes/{id}/email-links`). It is refreshed from the
  API's `docs/openapi/heimdall.json` and the client regenerated, per Operations §7, before anything
  uses the new operations. CI's drift check stays green.
- Architecture as everywhere else: presentation depends on the domain repository interface; the data
  layer wraps the generated client; nothing in `presentation/` imports `package:heimdall_api_client`.
- Testing Specification §5 applies to every use case below: main and alternative flows, widget tests
  at the three breakpoints, the dark theme, and the API's `errors` shown as returned.

## 3. UI-31 — Configure a scope's sign-in and sign-up

**Actors:** System Admin; Scope Admin for the scopes they own. **API use cases:** UC-24, UC-47
(toggle), the email-links endpoint (FR-SR-10 in the API).

### 3.1 Placement

- Route `/scopes/:scopeId/sign-in-settings`, screen title **Sign-in & sign-up**.
- Reached from the scope detail's **In this scope** list, as a new entry beside Owners, Persons,
  Applications, Permissions and Google users. The entry's subtitle summarises the scope's state, e.g.
  `Google on · Self-registration off · Custom email links` (or `Default email links` when neither link
  is set).
- The Google Sign-In switch **moves here** from the scope detail screen, with its behaviour unchanged
  (UI-15, including AF-15b's warning before switching off). The scope detail no longer carries a
  switch; UI-15 is amended to say where it now lives.
- Route access: System Admin and Scope Admin (`roleMayReach`); a Scope Admin who does not own the
  scope is refused by the API and shown that refusal, as on the other scope screens.

### 3.2 The "Ways in" card

Two switches, each showing the confirmed state, disabled while either switch's request or the email
links' save is outstanding, with a refusal shown in an error banner beneath the switch that caused it.

**Google Sign-In** — UI-15 as it is today.

**Self-registration** — `PUT /api/scopes/{id}/self-registration {"enabled": bool}`.

- **Opening it** when the scope has **no** `emailVerificationUrl` asks first:
  *"Sign-up confirmation emails will link to Heimdall's default page, not your application's. Open
  self-registration anyway?"* — **Open** / **Cancel**. With a verification link set, it opens without
  asking.
- **Closing it** always asks first: *"New sign-ups will be refused. People who have signed up but
  have not yet followed the link in their email will not be able to finish, and will need to sign up
  again once it reopens."* — **Close** / **Cancel**. (This is what the API does: a confirmation for a
  scope whose self-registration is off is refused and the pending registration is spent.)
- **Cancel** in either dialog sends nothing.
- A card note explains the switch: *"Lets people create their own account in this scope from your
  application's sign-up screen. Each one confirms by email before the account exists."*

### 3.3 The "Email links" card

- Two optional text fields: **Verification link** and **Password-reset link**, seeded from the scope.
- Help text under each names what uses it:
  - Verification: *"Sign-up confirmation and email verification. Leave empty to use Heimdall's
    default."*
  - Password reset: *"Password recovery. Leave empty to use Heimdall's default."*
- Client-side validation mirrors the API (`SetScopeEmailLinksCommandValidator`): when non-empty after
  trimming, an absolute `http` or `https` URL with a host, at most 2048 characters. Values are sent
  trimmed. A path such as `/verify-email` is refused even though Dart's `Uri` parses
  it. Invalid input blocks the save and is shown on the field.
- **Save** sends `PUT /api/scopes/{id}/email-links` with **both** values — the API treats the body as
  the whole state, so an omitted link would be cleared. An empty field is sent as `null`.
- **Cancel** (shown while the fields differ from the scope) restores the saved values.
- On success the card shows the saved notice the other edit screens use, and the scope state (and the
  self-registration dialog's condition) reflects the new links.
- On refusal the API's `errors` are shown against the field they name, or in a banner otherwise.

### 3.4 Alternative flows

| ID | Condition | Behaviour |
| --- | --- | --- |
| AF-31a | The scope is missing | The "Scope not found" state the scope detail uses, with a way back to `/scopes` |
| AF-31b | The scope is logically deleted | Everything read-only; the deleted notice the scope detail uses |
| AF-31c | The API refuses a switch (403, 404, 400) | The switch stays at the API's state; its error banner shows the returned errors |
| AF-31d | The API refuses the links (400) | The returned errors on their fields or in a banner; the typed values are kept |
| AF-31e | A link fails the client-side check | Nothing is sent; the field says why |
| AF-31f | Opening self-registration with no verification link, dialog cancelled | Nothing is sent; the switch stays off |
| AF-31g | Closing self-registration, dialog cancelled | Nothing is sent; the switch stays on |
| AF-31h | Transport failure on load | The retryable error state (FR-UX-07) |
| AF-31i | Transport failure on a switch or save | An error banner; the switch keeps its confirmed state and the typed links are kept |

### 3.5 Code shape

- `features/scopes/domain/scope.dart`: `Scope` gains `selfRegistrationEnabled`,
  `emailVerificationUrl`, `passwordResetUrl` (mapped from every scope response that carries them).
- `ScopeRepository` gains `setSelfRegistration(scopeId, enabled)` and
  `setEmailLinks(scopeId, {emailVerificationUrl, passwordResetUrl})`, each returning the updated
  `Scope`.
- `features/scopes/presentation/scope_sign_in_settings_controller.dart` and
  `scope_sign_in_settings_screen.dart`. The Google Sign-In toggle logic moves out of
  `ScopeDetailController` into the new controller, and its tests move with it.
- A shared link validator (pure function) with its own unit tests.

## 4. UI-02 amendment — Send a new code

**API use case:** UC-46.

- Shown on the second-factor screen only while the challenge's method in use is **email** and the
  person is not entering a recovery code.
- **Send a new code** calls `POST /api/auth/2fa/challenge/resend {"challengeToken": …}` with the
  challenge the session holds.
- The API answers `200` alike whether or not it sent anything (AF-46a…AF-46e), so the screen never
  claims more than it knows. On success it says: *"If your sign-in is still open, a new code is on its
  way. Codes sent before it no longer work."*
- Pacing is the client's own:
  - After each send the button is disabled for **30 seconds**, counting down in its label.
  - The screen counts its sends for the current challenge. After the **third** — the API's reissue
    cap (FR-2F-13) — the button is replaced by **Start over**, which returns to `/login`, with the
    note *"For another code, sign in again."*
- What the person typed in the code field is kept.
- A transport or server failure shows the error banner and does **not** count as a send or start
  the countdown.
- Choosing another method, or a recovery code, hides the button; the count belongs to the challenge,
  not to the method.

| ID | Condition | Behaviour |
| --- | --- | --- |
| AF-02f | The method in use is the authenticator app, or a recovery code is being entered | No resend control |
| AF-02g | Third send made | **Start over** replaces the button |
| AF-02h | Transport or server failure | Error banner; the count and countdown are unchanged |

(UI-02 already has AF-02a…AF-02e; these continue from there.)

## 5. UI-32 — Review outstanding erasure requests

**Actor:** System Admin only. A Scope Admin is deliberately excluded (UC-43): who has asked to be
erased is not theirs to know. **API use cases:** UC-43 and the reconciliation endpoint.

### 5.1 Placement

- Route `/erasure-requests`, screen title **Erasure requests**.
- A navigation destination shown only to a System Admin (`destinationsFor`), and route access limited
  to that role (`roleMayReach`).

### 5.2 The list

- `GET /api/auth/erasure-requests` with `PageNumber`, `PageSize` and `OverdueOnly`, rendered with the
  collection pattern every listing uses (cards when compact, a paginated table when expanded,
  FR-UX-04).
- An **Overdue only** filter chip.
- Each row: the subject id (monospace, with a copy button), its kind (**Person** or **Google user**,
  from `isGoogleUser`), requested at, due at, an **Overdue** chip when `overdue`, and the
  `blockedReason` when present — those are the rows that need an administrator, usually to transfer
  a scope's ownership.
- A line above the list: *"Names and email addresses are not shown: these people have asked to be
  erased."*
- Empty: *"No outstanding erasure requests."* Filtered and empty: *"Nothing is overdue."* (FR-UX-06).

### 5.3 Re-apply erasures after a restore

A **Re-apply erasures** action on the screen opens a dialog for the Operations runbook step that
follows a database restore.

1. Explanatory text: paste the identifiers the anonymisation pass logged since the backup was taken.
2. A multi-line field. Entries are split on commas, whitespace and newlines, trimmed, de-duplicated.
3. Each entry must parse as a UUID. Invalid entries are listed and nothing is sent. An empty list is
   refused with *"Paste at least one identifier."* (the API refuses it too, deliberately).
4. **Re-apply N** asks once more — *"Re-apply erasure to N identifiers?"* — then sends
   `POST /api/auth/erasure-reconciliation {"subjectIds": […]}`.
5. The result: **Anonymised** N, **Already anonymised** N, and **Not found** with the list (copyable)
   and the note *"Not found is the ordinary case for most of the ledger."* The list refreshes.

### 5.4 Alternative flows

| ID | Condition | Behaviour |
| --- | --- | --- |
| AF-32a | No outstanding requests | The empty state |
| AF-32b | Overdue only, none overdue | The filtered-empty state |
| AF-32c | The API refuses the list (401/403) | The returned errors; the 401 path is the shell's usual session handling |
| AF-32d | Pasted entries are not UUIDs | They are listed; nothing is sent |
| AF-32e | The paste is empty | *"Paste at least one identifier."*; nothing is sent |
| AF-32f | The confirmation is cancelled | Nothing is sent; the paste is kept |
| AF-32g | The API refuses the reconciliation | The returned errors in the dialog; the paste is kept |
| AF-32h | Transport failure | The retryable error state for the list; an error banner in the dialog |

### 5.5 Code shape

- New `features/erasure_requests` with `data/erasure_request_repository_impl.dart`,
  `domain/erasure_request.dart`, `domain/erasure_request_repository.dart` and
  `presentation/` (list controller and screen, reconciliation dialog and its controller).
- A pure identifier-list parser with its own unit tests.

## 6. Documentation

Updated in the branch that delivers each item:

- **Use Case Specification:** UI-31 and UI-32 with their main and alternative flows; the UI-02
  amendment; UI-15 amended to say its switch lives on UI-31's screen; the §1.4 index rows.
- **System Requirements:**
  - FR-SC-13 — show and toggle a scope's self-registration through
    `PUT /api/scopes/{id}/self-registration`, confirming before opening without a verification link
    and before closing (UI-31).
  - FR-SC-14 — set or clear a scope's email links through `PUT /api/scopes/{id}/email-links`, sending
    both links on every save (UI-31).
  - FR-SC-12 — gains UI-31 as its use case.
  - FR-SC-04 — the Google Sign-In state moves to UI-31.
  - FR-AU-26 — resend the second-factor email code through `POST /api/auth/2fa/challenge/resend`,
    paced by the client and capped at three sends per challenge (UI-02).
  - New §2.8 *Data subject administration* (`FR-DA`): FR-DA-01 list outstanding erasure requests;
    FR-DA-02 re-apply erasures after a restore (UI-32).
  - Screen inventory: `/scopes/:scopeId/sign-in-settings` (UI-31, UI-15), `/erasure-requests` (UI-32);
    `/scopes/:scopeId` loses UI-15.
  - Authorization matrix: *Sign-in & sign-up settings* — Full / Owned scopes only / Hidden / Hidden
    (replacing *Toggle Google Sign-In*); *Erasure requests* — Full / Hidden / Hidden / Hidden.
- **README backlog:** rows for UI-31 and UI-32, the UI-02 amendment, and the four API gaps of §8.
- **CHANGELOG** `[Unreleased]` → `### Added` per branch.

## 7. Delivery

Three issues, three branches into `develop`, one release.

| Order | Branch | Contents |
| --- | --- | --- |
| 1 | `feature/ui-31-scope-sign-in-settings` | This spec; the specification refresh and client regeneration (its own commit); UI-31 |
| 2 | `feature/ui-02-resend-second-factor-code` | The UI-02 amendment |
| 3 | `feature/ui-32-erasure-requests` | UI-32 |

Branches 2 and 3 depend only on the refreshed client, and are cut from `develop` after branch 1
merges. Then Heimdall UI **1.7.0** goes out the usual way: changelog PR, `release/1.7.0` → `main`,
Jenkins.

## 8. Out of scope — gaps that need API work

Each needs a Heimdall API endpoint before a screen can exist, and gets its own design:

| Gap | Why it matters |
| --- | --- |
| Audit log viewer | Every write is audited, but nothing reads the trail back |
| Pending self-registrations — list and discard | Once a scope opens sign-up, nobody can see who is waiting to confirm |
| List System Admins | One can be created, but not listed (`GET /api/persons/scope-admins` covers Scope Admins only) |
| Admin-initiated resend verification and password reset | Only the person can trigger either today, so an administrator cannot help someone who is stuck |

Not a gap: scope permissions apply to every User of the scope (those flagged `IncludeAsJwtClaim` go
into each User's token). Assigning permissions per person would be a change to the API's model and is
not proposed here.
