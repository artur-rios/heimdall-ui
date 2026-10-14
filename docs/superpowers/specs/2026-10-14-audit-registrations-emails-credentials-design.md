# Audit trail, pending registrations, account emails and application credentials — design

**Issues:** heimdall-ui #136 (audit trail), #137 (pending self-registrations), #138 (account emails),
#139 (application credentials).
**API:** heimdall-api #174/PR #181 (UC-48), #175/PR #182 (UC-49, UC-50), #177/PR #183 (UC-51,
UC-52), #178/PR #185 (UC-53…UC-55), all on heimdall-api `develop`.
**Out of scope:** see §9.

## 1. Purpose

The API now offers four administrator capabilities that Heimdall UI cannot reach. Three of them
are the gaps the admin-gaps design listed (§8 of
`2026-10-13-scope-sign-in-settings-and-admin-gaps-design.md`); the fourth is application
credentials. This design adds one use case for each:

| UI | Title | Issue | API |
| --- | --- | --- | --- |
| UI-34 | Review the audit trail | #136 | UC-48 |
| UI-35 | Manage a scope's pending registrations | #137 | UC-49, UC-50 |
| UI-36 | Send account emails to a person | #138 | UC-51, UC-52 |
| UI-37 | Manage an application's credentials | #139 | UC-53, UC-54, UC-55 |

## 2. Decisions taken with the owner

| Question | Decision |
| --- | --- |
| How the audit trail shows actors and targets | Ids, never names. Each id can be copied and used as a filter. Nothing is looked up, so cleared attributions stay cleared. |
| Where pending registrations live | On their own screen, opened from the scope page's **In this scope** links. |
| How the work is delivered | One branch and one pull request per use case. The first also carries this spec, the client refresh and the shared pieces of §3. |

## 3. Shared foundations (delivered with UI-34)

1. **Client refresh.** Run `dart run tool/refresh_openapi.dart ../heimdall-api/docs/openapi/heimdall.json`, then
   `dart run tool/generate_api_client.dart`. Commit the result on its own, as the first commit of
   the first branch: `api/heimdall.json` and `packages/heimdall_api_client` together, as P-02's drift
   check requires. Later branches use the regenerated client as it is.
2. **Rate limiting.** `failureFromDioException` (`lib/core/network/envelope.dart`) maps `429` to a
   new `FailureKind.rateLimited`. The API's `errors` are kept verbatim, as for every failure.
   - When the response carries `Retry-After` in seconds (heimdall-api #188 adds it to the rate
     limiter's answers), `Failure` carries it as `retryAfter`.
   - `displayMessage` appends "Try again in N seconds.", or "Try again later." without it.
   - A `429` that a handler returns (UI-36's cooldown) has no header, so its API message stands alone.
3. **Date and time.** A shared `formatDateTime(BuildContext, DateTime)` in `lib/shared/`. It
   formats the local date with `MaterialLocalizations.formatMediumDate` and the time with
   `formatTimeOfDay` (24-hour per locale), with no new dependency. UI-34 uses it; UI-35 and UI-37
   use it for their instants.

## 4. UI-34 — Review the audit trail

**Actor:** System Admin only. The API refuses everyone else (UC-48 AF-48b).
**Placement:**
- Route `/audit-log`, titled **Audit log**.
- A navigation destination shown only to a System Admin (`destinationsFor`).
- `roleMayReach` refuses the route to other roles, which are redirected to `/not-available`.

**Screen.** A paginated collection (`AdaptiveCollection`) modelled on UI-32, newest first. It
reads `GET /api/audit-log` with these filters:

| Filter | Control | Sent as |
| --- | --- | --- |
| Date range | a **Dates** button opening `showDateRangePicker` | `from` = start of the first day (local) and `to` = end of the last day (local), both converted to UTC; inclusive, as the API reads them |
| Action | a text field, matched exactly (e.g. `CreateScopeCommand`) | `action`; empty means no filter |
| Actor | a text field | `actorId` |
| Target | a text field | `targetId` |
| Outcome | chips **All**, **Succeeded**, **Refused** | `succeeded` omitted, `true` or `false` |

- **Applying filters.** Text filters apply on submit. The actor and target fields must hold a UUID;
  anything else shows "Enter an identifier." under the field, and nothing is sent. Every change
  returns to page 1. A **Clear filters** action resets them all.
- **Each entry shows:**
  - **When**: `recordedAt`, through `formatDateTime`.
  - **Action**: the action name.
  - **Outcome**: a **Succeeded** or **Refused** chip, with `failureReason` beneath a refusal.
  - **Actor**: the id and role, or "None" when `actorId` is `null`.
  - **Target**: the id, or "—" when `targetId` is `null`.
- **Each id** has a copy button ("Identifier copied.") and a **Filter by this** action that puts it
  in the matching filter.
- A short line above the list reads: "An entry shows no actor when the action was anonymous, such
  as a sign-in, or when its attribution was cleared — after the attribution period, or once the
  person was erased. Filtering by actor cannot find these."

**Alternative flows:**
- **AF-34a — Nothing matches.** "No entries match these filters.", with **Clear filters** when any
  filter is set; "The audit log is empty." when none is.
- **AF-34b — Refused.** `401` or `403`: the shell's usual handling (UI-07) and the forbidden state.
- **AF-34c — Invalid filters.** A `400` (e.g. a reversed range, which the picker cannot produce):
  the API's message in an error banner. The filters are kept.
- **AF-34d — Not an identifier.** The field error above; nothing is sent.
- **AF-34e — Transport failure.** The retryable error state (FR-UX-07).

**Code shape.**
- `lib/features/audit_log/`:
  - `domain/audit_entry.dart` and `audit_log_repository.dart`;
  - `data/audit_log_repository_impl.dart`, over the regenerated client's audit endpoint;
  - `presentation/audit_log_screen.dart` and `audit_log_controller.dart`.
- The controller follows `erasure_request_list_controller.dart`: a `Query` value, sealed
  states, in-flight and queued fetches, and a fallback to the last valid page.

Amended during Part A's final review: 'Cleared' became 'None' and the note was reworded, because
anonymous actions never have an actor.

## 5. UI-35 — Manage a scope's pending registrations

**Actor:** System Admin, or a Scope Admin who owns the scope (UC-49, UC-50).
**Placement:**
- A **Pending registrations** entry in the scope page's **In this scope** links. It is shown to a
  System Admin, and to a Scope Admin whose `Principal.ownedScopeIds` holds this scope. That list
  comes from the token's `ownedScopeIds` claim. The scope page's own controls are System-Admin-only,
  so this is a new check.
- It opens `/scopes/:scopeId/pending-registrations`, titled **Pending registrations**, with the
  scope's name in the subtitle.

**Screen.** A paginated collection from `GET /api/scopes/{id}/pending-registrations`, newest first.
- **Each row:** name, email, **Signed up** (`createdAt`), **Expires** (`expiresAt`), **Attempts left**
  and an **Expired** chip when `expired`.
- A line above the list explains that these people signed up but have not yet confirmed. Discarding
  a registration makes its emailed link stop working, and the person may sign up again.

**Discard.**
1. Each row has **Discard**. `showConfirm` asks "Discard the registration for {email}?" with the
   message "Its confirmation link will stop working." and the action **Discard**.
2. On confirmation, the client calls `DELETE /api/scopes/{id}/pending-registrations/{registrationId}`.
3. On success, the list reloads and a notice says "Registration discarded."

**Alternative flows:**
- **AF-35a — None pending.** "No pending registrations."
- **AF-35b — Refused.** A `403`: the forbidden state. A `401`: the shell's usual handling.
- **AF-35c — Scope not found.** A `404` on the list: the not-found state with a link back to
  **Scopes**.
- **AF-35d — Already gone.** A `404` on discard (confirmed, purged or discarded elsewhere): the list
  reloads, and a notice says "That registration no longer exists."
- **AF-35e — Discard cancelled.** Nothing is sent.
- **AF-35f — Transport failure.** The retryable error state, or an error banner for the discard.

**Code shape.**
- `lib/features/scopes/`, beside the scope screens:
  - `domain/pending_registration.dart`, plus methods on `ScopeRepository` (or a small
    `PendingRegistrationRepository` if the scope repository is already large);
  - `presentation/pending_registration_list_screen.dart` and `_controller.dart`.
- The route is added to `router.dart`.

## 6. UI-36 — Send account emails to a person

**Actor:** System Admin for anyone; a Scope Admin for a User of a scope they own (UC-51, UC-52).
**Placement:** an **Account emails** card on the person page, above the danger zone. It is shown to
a System Admin, and to a Scope Admin viewing a User. The API remains the authority, and a `403`
is shown like any refusal.

**Card.** Two actions, each confirmed through `showConfirm`, naming the address:

| Action | Shown when | Confirm | API |
| --- | --- | --- | --- |
| **Resend verification email** | the person's address is not verified | "Send a new verification link to {email}?" | `POST /api/persons/{id}/verification-email` |
| **Send password reset** | always | "Send a password reset link to {email}?" | `POST /api/persons/{id}/password-reset` |

- A line in the card says the link goes only to the person's own address and that no link or code
  is ever shown here.
- On success, the card shows "Sent to {email}." Each action is disabled while its request is in
  flight.

**Alternative flows:** each answer is shown with the API's own message, in an error banner within
the card.
- **AF-36a — Sent recently.** A `429` (the cooldown): the API's "An email of this kind was sent to
  this person recently. Try again in a few minutes."
- **AF-36b — Cannot be sent.** A `409`: deleted, restricted, or (for a reset) cannot sign in.
- **AF-36c — Already verified.** A `400` on resend. The card also reloads the person, so the action
  disappears.
- **AF-36d — Refused.** A `403` or `404`.
- **AF-36e — Cancelled.** Nothing is sent.
- **AF-36f — Transport failure.** An error banner.

**Code shape.**
- Two methods on `PersonRepository`.
- An `AccountEmailsController` (a `.family` keyed by person id) with per-action state.
- An `_AccountEmails` card widget in the person detail screen's file, or in its own file if the
  screen file would grow past its current shape.

## 7. UI-37 — Manage an application's credentials

**Actor:** System Admin, or the Scope Admin who owns the application and still owns its scope
(UC-53…UC-55).
**Placement:** a **Credentials** card on the application page, between the facts card and the danger
zone.

**Card.**
- A line explains: an application exchanges a secret for a token at
  `POST /api/applications/token`; at most two secrets may be live, so a new one can be deployed
  before the old one is revoked.
- The list comes from `GET …/credentials`, newest first. Each row shows:
  - the id, with a copy button;
  - a status chip: **Live**, **Revoked** (with its date) or **Expired** (`live` false and not revoked);
  - **Issued**;
  - **Expires** ("Never" when `null`);
  - **Last used** ("Never" when `null`).
- **Revoke** sits on every row that is not revoked.

**Issue.**
1. **Issue credential** is disabled while two credentials are live, with the hint "Revoke a
   credential before issuing another."
2. It opens a dialog with an optional **Expires on** date, chosen with `showDatePicker` from today
   onwards. The expiry is the end of that day, local time, sent as UTC. Without a date, the
   credential never expires.
3. **Issue** calls `POST …/credentials`.
4. On `201`, a **one-time secret dialog** replaces the issue dialog. It:
   - cannot be dismissed (`barrierDismissible: false` and `PopScope(canPop: false)`);
   - shows the secret in `SelectableText`, with **Copy** ("Secret copied.");
   - warns: "This is the only time the secret is shown. Store it in the application's secret store
     now."
5. The dialog closes only through **I've stored it**. The list then reloads.

**Revoke.** `showConfirm` asks "Revoke this credential?" with the message "Tokens issued from it
stop working at the next check." On confirmation, the client calls `DELETE …/credentials/{id}` and
the list reloads.

**Alternative flows:**
- **AF-37a — No credentials.** "This application has no credentials yet."
- **AF-37b — Limit reached.** A `409` on issue (another admin issued one meanwhile): the API's
  message, and the list reloads.
- **AF-37c — Expiry refused.** A `400`: the API's message in the issue dialog.
- **AF-37d — Already revoked.** A `409` on revoke: the API's message, and the list reloads.
- **AF-37e — Refused.** A `403` or `404`: the API's message.
- **AF-37f — Cancelled.** Nothing is sent, and no secret is shown.
- **AF-37g — Transport failure.** An error banner. If the issue request fails after sending, the
  secret is not known to the client. The list reloads, so an issued-but-unseen credential appears
  and can be revoked.

**Code shape.**
- `lib/features/applications/`:
  - `domain/application_credential.dart`, plus methods on `ApplicationRepository`;
  - `presentation/application_credentials_controller.dart`;
  - `presentation/credentials_card.dart`;
  - `presentation/one_time_secret_dialog.dart`.
- The one-time secret dialog stays in the applications feature, as its only consumer. It is
  modelled on `reconciliation_dialog.dart` and the recovery-codes card.
- The secret is held only in the dialog's widget state, never in a provider or a log.

## 8. Documentation

Each branch updates the documents for its own use case:
- **Use Case Specification Document.** A `### UI-NN` section in the UI-32 format (actor, traces to,
  precondition, placement, main flow, alternative flows), a row in the §1.4 inventory, a node and
  edge in the actor diagram, and the §3 traceability row.
- **System Requirements Document.**

  | Use case | Requirements |
  | --- | --- |
  | UI-34 | a new group **§2.9 Audit trail (`FR-AL`)**, FR-AL-01 to FR-AL-03 |
  | UI-35 | FR-SC-15 and FR-SC-16 |
  | UI-36 | FR-PE-10 and FR-PE-11 |
  | UI-37 | FR-AP-09 to FR-AP-11 |
  | 429 handling (UI-34's branch) | FR-UX-09 |

  Each branch also adds its screen and its authorization-matrix rows.
- **README.**
  - The "Needs Heimdall API work" rows become UI rows marked ✅, each with its issue, in the matching
    area tables.
  - UI-37 gets a new row.
  - UI-34's branch also marks UI-33 ✅, since it merged with #134.
  - "List System Admins" stays ⬜: it has no UI issue (§9).
- **CHANGELOG.** One `### Added` entry per branch, in plain language. UI-34's branch adds a
  `### Fixed` entry for the 429 messages.

## 9. Delivery

| Order | Branch | Contents | Closes |
| --- | --- | --- | --- |
| 1 | `feature/ui-34-audit-trail` | This spec, its plan, the client refresh (its own commit), §3, UI-34, docs | #136 |
| 2 | `feature/ui-35-pending-registrations` | UI-35, docs | #137 |
| 3 | `feature/ui-36-account-emails` | UI-36, docs | #138 |
| 4 | `feature/ui-37-application-credentials` | UI-37, docs | #139 |

- Each branch is cut from `develop` after the previous one merges, so the regenerated client and
  §3 arrive through `develop`.
- **Gate for each:** `dart format --set-exit-if-changed . && flutter analyze && flutter test`, with
  the Flutter 3.47.7 toolchain.
- **Tests follow the repository's patterns:**
  - repository tests with a stub `HttpClientAdapter`;
  - controller and screen tests with mocktail and `ProviderContainer` overrides;
  - route-access, router and destination tests for UI-34;
  - an envelope test for `429`;
  - a widget test proving the one-time secret dialog cannot be dismissed.

**Out of scope:**
- A screen listing System Admins. The API has it (UC-07 read e, heimdall-api #176), but no UI
  issue asks for it.
- Resolving audit ids to names (§2).
- Editing or deleting audit entries (the trail is append-only).
- Any change to the API.
