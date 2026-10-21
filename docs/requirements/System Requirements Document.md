---
title: "System Requirements Document"
linkTitle: "System Requirements Document"
weight: 20
description: "Functional and non-functional requirements, the screen inventory, and the authorization matrix."
---

# System Requirements Document — Heimdall UI

## 1. Introduction

### 1.1 Purpose

This document states **what Heimdall UI must do**, as numbered requirements, and **what qualities it
must have** while doing it. The [Use Case Specification Document](Use%20Case%20Specification%20Document.md)
describes the flows that satisfy these requirements; the
[Technology Stack Document](Technology%20Stack%20Document.md) records what they are built with.

### 1.2 Requirement identifiers

| Prefix | Area |
| --- | --- |
| `FR-AU` | Authentication, session, and account recovery |
| `FR-SC` | Scope management |
| `FR-PE` | Person management |
| `FR-AP` | Application management |
| `FR-PM` | Scope permission management |
| `FR-GU` | Google user management |
| `FR-AL` | Audit trail |
| `FR-UX` | Shell, navigation, responsiveness, and theming |
| `NFR` | Non-functional |

---

## 2. Functional requirements

### 2.1 Authentication, session, and recovery (`FR-AU`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-AU-01 | The client shall authenticate a person by email and password through `POST /api/auth/login`, sending the configured scope as Google sign-in does. | UI-01 |
| FR-AU-02 | The client shall detect a two-factor challenge in the login response and continue into the challenge flow instead of establishing a session. | UI-01, UI-02 |
| FR-AU-03 | The client shall send a challenge token to `POST /api/auth/2fa/verify` and to no other endpoint, and shall never persist it. | UI-02 |
| FR-AU-04 | The client shall accept a generated code or a recovery code as the second factor, and shall let the user choose among the methods the API reports as available. Every field that takes a recovery code (sign-in, disabling, regenerating, an own email change) accepts the sixteen-character `XXXX-XXXX-XXXX-XXXX` form and the older `XXXX-XXXX` one, in any case and with or without hyphens or spaces, sets no length limit, and sends the code as typed, trimmed; the keyboard neither corrects nor completes it. | UI-02, UI-08, UI-09 |
| FR-AU-05 | The client shall store the bearer token and its expiry in the platform's secure storage, and shall restore the session from it at start-up. On the web the session is restored only in the tab that signed in: across a reload of that tab, and wherever the browser restores that tab's session storage. | UI-01, UI-07 |
| FR-AU-06 | The client shall discard a stored token whose expiry has passed without contacting the API. | UI-07 |
| FR-AU-07 | The client shall attach the bearer token to every authenticated request as an `Authorization: Bearer` header. The token attached is the one held by the session the client is showing, never one read back from storage, so a request always acts as the identity on screen. | UI-07 |
| FR-AU-08 | The client shall clear the session and route to sign-in whenever the API answers `401` to a request made under the session, except a `401` refusing a password or code typed into that request, which the screen shows instead. Such a refusal is recognised by its message: "The password or code is incorrect." (every re-authentication under a token, including a paused one and `POST /api/auth/2fa/confirm`), and, from older APIs, "The current password is incorrect.", "The code or recovery code is missing, incorrect, or already used." and "The credential presented was not accepted.". A `401` to a request made under an earlier session, one that has since ended or been replaced, leaves the current session alone. | UI-07 |
| FR-AU-09 | The client shall offer Google sign-in when a Google client id is configured, exchange the resulting ID token at `POST /api/auth/google`, and sign out through `POST /api/auth/google/sign-out`. | UI-06 |
| FR-AU-10 | The client shall request a password reset through `POST /api/auth/password-recovery` and shall show the same confirmation whether or not the address is registered. | UI-03 |
| FR-AU-11 | The client shall accept a reset token from a link and complete the reset through `POST /api/auth/password-reset`. On the web it shall remove the token from the address once read. | UI-04 |
| FR-AU-12 | The client shall accept a verification token from a link and complete verification through `POST /api/auth/verify-email`. On the web it shall remove the token from the address once read. | UI-05 |
| FR-AU-13 | The client shall offer to resend a verification email through `POST /api/auth/resend-verification`. | UI-05 |
| FR-AU-14 | The client shall show an authenticated user with an unverified address a dismissible prompt offering to resend the verification email. | UI-05 |
| FR-AU-15 | The client shall show the signed-in person their own profile, read through `GET /api/persons/{id}` — or, for a Google User, through `GET /api/scopes/{scopeId}/google-users/{id}`, read-only. | UI-08 |
| FR-AU-16 | The client shall let the signed-in person update their own name and email through `PUT /api/persons/{id}`. A change of email address (the trimmed values compared exactly, so case counts) shall be confirmed with `currentPassword`, and with `twoFactorCode` — an authenticator code or a recovery code — when the person's two-factor authentication is on; a name-only change sends neither. | UI-08 |
| FR-AU-17 | The client shall enable two-factor authentication through `POST /api/auth/2fa/enable`, sending the person's `currentPassword`, and confirm it through `POST /api/auth/2fa/confirm`. | UI-09 |
| FR-AU-18 | The client shall render an `otpAuthUri` as a scannable code and shall also present the secret as selectable text. | UI-09 |
| FR-AU-19 | The client shall display recovery codes exactly once, offer to copy or download them, and require acknowledgement before navigating away — a browser Back, Forward or typed address included — and ask the browser to confirm closing or reloading the tab while they wait. | UI-09 |
| FR-AU-19a | A copied credential secret, setup key or set of recovery codes shall, where the platform allows, be removed from the clipboard after 60 seconds, unless the clipboard has since changed. Where the platform does not let the application read the clipboard at that moment (an application in the background), the check stays pending and runs again each time the application returns to the foreground past the 60 seconds, until the clipboard can be read; it is never attempted on the web, and not done if the application is closed first. On Android the window shall be excluded from screenshots and the recents thumbnail while one is on screen. | UI-09, UI-37 |
| FR-AU-20 | The client shall disable two-factor authentication through `POST /api/auth/2fa/disable` and regenerate recovery codes through `POST /api/auth/2fa/recovery-codes/regenerate`. | UI-09 |
| FR-AU-21 | The client shall recognise a subject-rights-only session — one whose processing is restricted — from `processingRestricted` in the answers of `POST /api/auth/login`, `POST /api/auth/2fa/verify` and `POST /api/auth/google`, and from the token's `subjectRightsOnly` claim when a session is restored. | UI-30 |
| FR-AU-22 | The client shall confine a subject-rights-only session, whatever its role, to the restricted session screen and the privacy notice. | UI-07, UI-30 |
| FR-AU-23 | The client shall lift the caller's own restriction on processing through `POST /api/auth/processing-restriction/lift`, then end the session, since the token that lifted it stays confined to the rights endpoints. | UI-30 |
| FR-AU-24 | The client shall obtain the caller's own data through `POST /api/auth/data-export` and save it as a JSON file: a browser download on the web, the downloads folder on every other target. | UI-30 |
| FR-AU-25 | The client shall request erasure of the caller's own identity through `POST /api/auth/erasure-request`, confirmed with the password for a person and with a freshly issued Google ID token for a Google User. | UI-30 |
| FR-AU-26 | The client shall request a new second-factor email code through `POST /api/auth/2fa/challenge/resend` while a challenge answered by email is outstanding, waiting 30 seconds between sends and offering at most three per challenge, after which it offers to start the sign-in again. | UI-02 |
| FR-AU-27 | The client shall let a signed-in person restrict processing of their own identity through `POST /api/auth/processing-restriction`, sending one of the four GDPR Art. 18(1) grounds the person chose (none preselected) after a confirmation that says the account is suspended until the restriction is lifted, and shall then end the session and say on the sign-in screen that signing in again opens the restricted session. | UI-33 |
| FR-AU-28 | After the signed-in person changes their own email address, confirms or disables two-factor authentication, or regenerates their recovery codes, the client shall send nothing more under the session's token and shall end the session — after the recovery codes have been shown, when there are any — saying on the sign-in screen "Your sign-in details changed. Sign in again." | UI-08, UI-09 |

### 2.2 Scope management (`FR-SC`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-SC-01 | The client shall list scopes through `GET /api/scopes`, paginated by the API. | UI-10 |
| FR-SC-02 | The client shall filter the scope listing by name and shall let the user include logically deleted scopes. | UI-10 |
| FR-SC-03 | The client shall create a scope through `POST /api/scopes`, with a name, a description, and at least one owner. | UI-11 |
| FR-SC-04 | The client shall show a scope through `GET /api/scopes/{id}`, including its owners, and a summary of its sign-in and sign-up settings. | UI-12 |
| FR-SC-05 | The client shall update a scope's name and description through `PUT /api/scopes/{id}`. | UI-12 |
| FR-SC-06 | The client shall logically delete a scope through `DELETE /api/scopes/{id}` after confirmation. | UI-13 |
| FR-SC-07 | The client shall permanently delete a scope through `DELETE /api/scopes/{id}/hard` after a confirmation requiring the scope's name to be typed. | UI-13 |
| FR-SC-08 | The client shall list a scope's owners through `GET /api/scopes/{scopeId}/owners`. | UI-14 |
| FR-SC-09 | The client shall add an existing Scope Admin as a co-owner through `POST /api/scopes/{scopeId}/owners/{personId}`, and shall say "Invitation sent" and list the person as pending when the answer says the API invited them. | UI-14 |
| FR-SC-10 | The client shall create a new Scope Admin as a co-owner through `POST /api/scopes/{scopeId}/owners`. | UI-14 |
| FR-SC-11 | The client shall promote a user of the scope to owner through `POST /api/scopes/{scopeId}/users/{personId}/promote`, and shall remove an owner through `DELETE /api/scopes/{scopeId}/owners/{personId}`, each after confirmation. The lists of owners and of promotable users shall be paged, and the users searched, so that every owner and user is reachable. | UI-14 |
| FR-SC-12 | The client shall toggle a scope's Google Sign-In through `PUT /api/scopes/{id}/google-signin`. | UI-15, UI-31 |
| FR-SC-13 | The client shall show and toggle a scope's self-registration through `PUT /api/scopes/{id}/self-registration`, asking before opening it while the scope has no verification link and before closing it. | UI-31 |
| FR-SC-14 | The client shall set or clear a scope's verification and password-reset links through `PUT /api/scopes/{id}/email-links`, sending both on every save, trimmed, with an empty link sent as `null`. | UI-31 |
| FR-SC-15 | A System Admin or an owning Scope Admin can list a scope's pending self-registrations, newest first and paginated, with name, address, sign-up and expiry instants, attempts left and whether each has expired. No secret is shown. | UI-35 |
| FR-SC-16 | They can discard one after confirming. A registration already gone is reported as such and the list refreshed. | UI-35 |
| FR-SC-17 | The client shall list a scope's pending owner invitations through `GET /api/scopes/{scopeId}/owner-invitations`, with each invitee's name, address and expiry, and shall withdraw one through `DELETE /api/scopes/{scopeId}/owner-invitations/{invitationId}` after confirmation, reading the lists again when the API answers `404`. | UI-14 |
| FR-SC-18 | The client shall tell an invitation from an added owner by the `invited` field of the answer to `POST /api/scopes/{scopeId}/owners/{personId}`, not by its status code. | UI-14 |
| FR-SC-19 | The client shall show the signed-in administrator's open invitations on Home through `GET /api/persons/me/scope-invitations`, and accept or decline one through `POST /api/scope-invitations/{invitationId}/accept` or `…/decline` after confirmation; after accepting it shall refresh the scopes it shows, and on a `404` it shall read the invitations again and show the API's message. | UI-39 |

### 2.3 Person management (`FR-PE`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-PE-01 | The client shall list the persons of a scope through `GET /api/scopes/{scopeId}/persons`, paginated by the API. | UI-16 |
| FR-PE-02 | The client shall filter the person listing and shall let the user include logically deleted persons. | UI-16 |
| FR-PE-03 | The client shall create a person within a scope through `POST /api/scopes/{scopeId}/persons`. | UI-17 |
| FR-PE-04 | The client shall let a System Admin create a person belonging to no scope through `POST /api/persons`. | UI-17 |
| FR-PE-05 | The client shall show a person through `GET /api/persons/{id}`, including role, scope membership, owned scopes, verification state, and whether a second factor is configured. | UI-18 |
| FR-PE-06 | The client shall update a person's name and email through `PUT /api/persons/{id}`, asking for no password. On the signed-in person's own record the email address is read-only, since it is changed from the profile (FR-AU-16). | UI-18 |
| FR-PE-07 | The client shall logically delete a person through `DELETE /api/persons/{id}` after confirmation. | UI-19 |
| FR-PE-08 | The client shall permanently delete a person through `DELETE /api/persons/{id}/hard` after a confirmation requiring the person's email to be typed. | UI-19 |
| FR-PE-09 | The client shall offer the owners a scope may be given from `GET /api/persons/scope-admins`, leaving out the persons who already own the scope being managed. | UI-11, UI-14 |
| FR-PE-10 | A System Admin, or a Scope Admin viewing a User of a scope they own, can have a fresh verification link sent to a person whose address is unverified, after confirming. | UI-36 |
| FR-PE-11 | They can have a password reset link sent, after confirming. Neither action shows a link or code; the API's refusals — including its cooldown — are shown as returned. | UI-36 |
| FR-PE-12 | A System Admin can list the system's System Admins, filtered by name or email and paged, through `GET /api/persons/system-admins`, and open each one's person page. | UI-38 |

### 2.4 Application management (`FR-AP`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-AP-01 | The client shall list a scope's applications through `GET /api/scopes/{scopeId}/applications`, paginated by the API. | UI-20 |
| FR-AP-02 | The client shall filter the application listing and shall let the user include logically deleted applications. | UI-20 |
| FR-AP-03 | The client shall create an application through `POST /api/scopes/{scopeId}/applications`, with a name and an owner drawn from the persons of that scope. | UI-21 |
| FR-AP-04 | The client shall show an application through `GET /api/scopes/{scopeId}/applications/{id}`. | UI-22 |
| FR-AP-05 | The client shall update an application's name and owner through `PUT /api/scopes/{scopeId}/applications/{id}`. | UI-22 |
| FR-AP-06 | The client shall logically delete an application through `DELETE /api/scopes/{scopeId}/applications/{id}` after confirmation. | UI-23 |
| FR-AP-07 | The client shall permanently delete an application through `DELETE /api/scopes/{scopeId}/applications/{id}/hard` after a confirmation requiring the application's name to be typed. | UI-23 |
| FR-AP-08 | The client shall resolve each application's owner to a person, and shall fall back to the identifier when it cannot. | UI-20, UI-22 |
| FR-AP-09 | A System Admin or the owning Scope Admin can list an application's credentials, newest first, with status, issue, expiry and last-use instants. No secret or hash is shown. | UI-37 |
| FR-AP-10 | They can issue a credential with an optional expiry date; its secret is shown once, in a dialog that only closes when the user says it is stored. Issuing is not offered while two credentials are live. | UI-37 |
| FR-AP-11 | They can revoke a credential after confirming. | UI-37 |

### 2.5 Scope permission management (`FR-PM`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-PM-01 | The client shall list a scope's permissions through `GET /api/scopes/{scopeId}/permissions`, paginated by the API. | UI-24 |
| FR-PM-02 | The client shall filter the permission listing and shall let the user include logically deleted permissions. | UI-24 |
| FR-PM-03 | The client shall create a permission through `POST /api/scopes/{scopeId}/permissions`. | UI-25 |
| FR-PM-04 | The client shall state, where the claim flag is set, that the permission is issued in the scope's tokens. | UI-25, UI-26 |
| FR-PM-05 | The client shall show a permission through `GET /api/scopes/{scopeId}/permissions/{id}`. | UI-26 |
| FR-PM-06 | The client shall update a permission's name, description, and claim flag through `PUT /api/scopes/{scopeId}/permissions/{id}`. | UI-26 |
| FR-PM-07 | The client shall logically delete a permission through `DELETE /api/scopes/{scopeId}/permissions/{id}` after confirmation. | UI-27 |
| FR-PM-08 | The client shall permanently delete a permission through `DELETE /api/scopes/{scopeId}/permissions/{id}/hard` after a confirmation requiring the permission's name to be typed. | UI-27 |

### 2.6 Google user management (`FR-GU`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-GU-01 | The client shall list a scope's Google users through `GET /api/scopes/{scopeId}/google-users`, paginated by the API. | UI-28 |
| FR-GU-02 | The client shall show a Google user through `GET /api/scopes/{scopeId}/google-users/{id}`, read-only. | UI-28 |
| FR-GU-03 | The client shall fall back to an initials avatar when a profile picture is missing or unreachable. | UI-28 |
| FR-GU-04 | The client shall logically delete a Google user through `DELETE /api/scopes/{scopeId}/google-users/{id}` after confirmation. | UI-29 |
| FR-GU-05 | The client shall permanently delete a Google user through `DELETE /api/scopes/{scopeId}/google-users/{id}/hard` after a confirmation requiring the Google user's email to be typed. | UI-29 |

### 2.7 Shell, navigation, and presentation (`FR-UX`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-UX-01 | The client shall present navigation appropriate to the window's breakpoint: a bottom bar when compact, a rail when medium, and an extended rail when expanded. A rail scrolls when the window, or what a soft keyboard leaves of it, is too short for its destinations, so every destination stays reachable. | UI-07 |
| FR-UX-02 | The client shall show only the destinations the signed-in role can use. | UI-07 |
| FR-UX-03 | The client shall support light, dark, and system theme modes, and shall remember the choice between launches. | — |
| FR-UX-04 | The client shall render collections as cards when compact and as a paginated table when expanded, from one declaration per collection. | UI-10, UI-16, UI-20, UI-24, UI-28, UI-32, UI-34, UI-35, UI-38 |
| FR-UX-05 | The client shall render the API's `errors` array as returned, against the offending field where the error names one and in a banner otherwise. | All |
| FR-UX-06 | The client shall distinguish an empty collection from a filtered collection with no matches, and shall offer the appropriate next action for each. | UI-10, UI-16, UI-20, UI-24, UI-28, UI-32, UI-34, UI-35, UI-38 |
| FR-UX-07 | The client shall show a retryable error state when a request fails for transport reasons, preserving the user's filters and input. Wherever a transport failure is shown, it reads "Could not reach the API. Check your connection and try again.", never the HTTP library's own text. An answer the client cannot read, such as a success response whose body is not the expected shape, shows "The API returned an unexpected response." with Retry, never an endless placeholder. | All |
| FR-UX-08 | The client shall address every screen by a URL, so that a link opens the screen directly on the web target. | UI-07 |
| FR-UX-09 | A `429` shows the API's message, and never ends the session. When the response carries `Retry-After`, it adds "Try again in N seconds.", in minutes from a minute and in hours from an hour, rounded up; a control that would send the same email again (the verification resend, the second-factor code resend, starting the email method) stays disabled for that long. `Retry-After` is read as whole non-negative seconds and held to a day (86400); zero, a sign, a fraction, an HTTP-date or anything else unreadable pauses nothing and adds no hint. | UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-09, UI-30, UI-36 |

### 2.8 Data subject administration (`FR-DA`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-DA-01 | The client shall list outstanding erasure requests through `GET /api/auth/erasure-requests`, paginated by the API, soonest deadline first, with an overdue-only filter, showing no name or email address. | UI-32 |
| FR-DA-02 | The client shall re-apply erasures after a restore through `POST /api/auth/erasure-reconciliation`, sending only a non-empty, de-duplicated list of identifiers after confirmation, and shall show how many were anonymised, already anonymised and not found. | UI-32 |

### 2.9 Audit trail (`FR-AL`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-AL-01 | A System Admin can list the audit trail, newest first and paginated, filtered by an inclusive range of local days, by exact action, actor identifier, target identifier and outcome. | UI-34 |
| FR-AL-02 | Each entry shows the instant in local date and time, the action, the outcome with its reason, and the actor (identifier and role) and target identifiers as returned. An entry with no actor — an anonymous action, or an attribution cleared after the attribution period or once the person was erased — reads "None"; nothing is resolved to a name. | UI-34 |
| FR-AL-03 | Actor and target filters accept only identifiers, trimmed and lowercased before they are sent. | UI-34 |

---

## 3. Screen inventory

| Route | Screen | Use case |
| --- | --- | --- |
| `/login` | Sign in | UI-01, UI-06 |
| `/login/two-factor` | Second-factor challenge | UI-02 |
| `/password-recovery` | Request password reset | UI-03 |
| `/password-reset` | Set a new password | UI-04 |
| `/verify-email` | Verify an email address | UI-05 |
| `/restricted` | Restricted session — lift the restriction, download one's data, request erasure | UI-30 |
| `/` | Home | UI-07 |
| `/profile` | Own profile; restrict processing of one's own account | UI-08, UI-33 |
| `/profile/security` | Two-factor and recovery codes | UI-09 |
| `/scopes` | Scope listing | UI-10 |
| `/scopes/new` | Create a scope | UI-11 |
| `/scopes/:scopeId` | Scope detail | UI-12, UI-13 |
| `/scopes/:scopeId/owners` | Scope owners | UI-14 |
| `/scopes/:scopeId/sign-in-settings` | Sign-in & sign-up | UI-31, UI-15 |
| `/scopes/:scopeId/pending-registrations` | Pending registrations — list and discard | UI-35 |
| `/scopes/:scopeId/persons` | Person listing | UI-16 |
| `/scopes/:scopeId/persons/new` | Create a person | UI-17 |
| `/scopes/:scopeId/persons/:personId` | Person detail, with the account emails card | UI-18, UI-19, UI-36 |
| `/scopes/:scopeId/applications` | Application listing | UI-20 |
| `/scopes/:scopeId/applications/new` | Create an application | UI-21 |
| `/scopes/:scopeId/applications/:applicationId` | Application detail, with the credentials card | UI-22, UI-23, UI-37 |
| `/scopes/:scopeId/permissions` | Permission listing | UI-24 |
| `/scopes/:scopeId/permissions/new` | Create a permission | UI-25 |
| `/scopes/:scopeId/permissions/:permissionId` | Permission detail | UI-26, UI-27 |
| `/scopes/:scopeId/google-users` | Google user listing | UI-28 |
| `/scopes/:scopeId/google-users/:googleUserId` | Google user detail | UI-29 |
| `/system-admins` | System Admins — list, search and page; rows open the person page | UI-38 |
| `/persons/:personId` | Person detail without a scope, opened from the System Admins list; back returns to it | UI-38, UI-18, UI-19 |
| `/erasure-requests` | Outstanding erasure requests; re-apply erasures after a restore | UI-32 |
| `/audit-log` | Audit trail — filter by dates, action, actor, target and outcome | UI-34 |
| `/health` | API health and diagnostics | P-04 |
| `/privacy` | Privacy notice — the Heimdall API's own, shown verbatim; the privacy policy link on Google's consent screen | [#73](https://github.com/artur-rios/heimdall-ui/issues/73) |
| `/not-found` | Not found — where a route whose id is not a `PublicId` lands | UI-07 |

---

## 4. Authorization matrix

What each role is offered. The API remains the authority: this table describes what the interface
shows, and a request the API refuses is refused regardless of what appears here.

| Screen | System Admin | Scope Admin | User | Anonymous |
| --- | --- | --- | --- | --- |
| Sign in, recovery, reset, verification | — | — | — | Full |
| Privacy notice | Full | Full | Full | Full |
| Not found | Full | Full | Full | Full |
| Second-factor challenge | Full | Full | Full | Held challenge only |
| Restricted session | Restricted session only | Restricted session only | Restricted session only | Hidden |
| Home | Full | Full | Full | Hidden |
| Own profile and security | Full | Full | Full | Hidden |
| Scope listing | All scopes | Owned scopes only | Hidden | Hidden |
| Create scope | Full | Hidden | Hidden | Hidden |
| Scope detail | Full | Owned scopes only | Hidden | Hidden |
| Scope update (name, description) | Full | Read-only | Hidden | Hidden |
| Logical delete scope | Full | Hidden | Hidden | Hidden |
| Permanent delete scope | Full | Hidden | Hidden | Hidden |
| Scope owners | Full | Owned scopes only | Hidden | Hidden |
| Sign-in & sign-up settings | Full | Owned scopes only | Hidden | Hidden |
| Pending registrations: list, discard | Full | Owned scopes only | Hidden | Hidden |
| Person listing, create, update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete person | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete person | Full | Hidden | Hidden | Hidden |
| Account emails: resend verification, send password reset | Full | Users of owned scopes only | Hidden | Hidden |
| System Admins: list | Full | Hidden | Hidden | Hidden |
| Person detail without a scope (`/persons/:personId`) | Full | Hidden | Hidden | Hidden |
| Application listing, create, update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete application | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete application | Full | Hidden | Hidden | Hidden |
| Application credentials: list, issue, revoke | Full | Owned scopes only | Hidden | Hidden |
| Permission listing, create, update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete permission | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete permission | Full | Hidden | Hidden | Hidden |
| Google user listing and detail | Full | Owned scopes only | Hidden | Hidden |
| Logical delete Google user | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete Google user | Full | Hidden | Hidden | Hidden |
| Erasure requests | Full | Hidden | Hidden | Hidden |
| Audit log | Full | Hidden | Hidden | Hidden |
| Health and diagnostics | Full | Read-only | Hidden | Hidden |

A **restricted session** — one holding the subject-rights-only token the API issues to an identity
whose processing is restricted (UI-30) — is offered the restricted session screen and the privacy
notice, whatever its role, and nothing else: the API refuses that token everywhere but the data
export, erasure, restriction and lift endpoints. A full session is not offered the restricted
session screen.

---

## 5. Non-functional requirements

| ID | Requirement |
| --- | --- |
| NFR-01 | Every screen shall be usable at the compact (`< 600`), medium (`600 – 1024`), and expanded (`> 1024`) breakpoints, with no horizontal scrolling of the page itself. |
| NFR-02 | Every screen shall be legible in both the light and the dark theme, with no hard-coded color that ignores the active scheme. |
| NFR-03 | The same source shall build and run on web, Windows, Linux, and Android, with no behavioral difference beyond what a platform itself imposes. |
| NFR-04 | The bearer token shall be held in the platform's secure storage, and the challenge token shall never be written to storage at all. On the web the bearer token shall be held in the tab's session storage, so that it is kept per tab and not shared with other tabs, and signing out shall clear it. A browser that restores a closed tab, or a whole browsing session, may restore its session storage and the session with it, so on a shared machine signing out is what ends the session. Browser storage is readable by any script on the page, so this limits how widely the token is kept rather than protecting it at rest. |
| NFR-05 | No secret shall be committed to the repository or embedded in a built artifact. |
| NFR-06 | Every collection shall be paginated through the API; the client shall never fetch a whole collection to page it in memory. |
| NFR-07 | Every screen shall be operable by keyboard, shall preserve a sensible focus order, and shall give every icon-only control a semantic label. |
| NFR-08 | The client shall enforce no authorization the API does not; hiding a control is a usability decision, never a security control. |
| NFR-09 | The web target shall reach interactive in under three seconds over a warm cache on a broadband connection. |
| NFR-10 | The web build shall be served with an enforced Content-Security-Policy that allows script only from its own origin and Google Sign-In's library, and connections only to its own origin, the configured API's origin, Google Sign-In's endpoints, Google profile pictures (`*.googleusercontent.com`) and the fallback fonts the renderer fetches. The token of a password reset or verification link shall be removed from the address as the application starts, so that no request the application makes carries it in its Referer; where the server's own headers reach the browser, the pages such a link opens shall also send no Referer at all. |

---

## 6. Assumptions and dependencies

- The Heimdall API is reachable over HTTPS and permits the client's origin by CORS on the web target.
- The API's OpenAPI specification at `docs/openapi/heimdall.json` describes the deployed API; the
  vendored copy in `api/heimdall.json` is refreshed whenever it changes.
- Google Sign-In requires a client id issued for each target, and the target scope must have the
  feature enabled by its owner.
- Email delivery, token issuance, hashing, and every authorization decision belong to the API.

---

## 7. References

- [Vision Document](Vision%20Document.md)
- [Use Case Specification Document](Use%20Case%20Specification%20Document.md)
- [Technology Stack Document](Technology%20Stack%20Document.md)
- [Testing Specification Document](Testing%20Specification%20Document.md)
- [Operations & Infrastructure Document](Operations%20%26%20Infrastructure%20Document.md)
- [Heimdall API System Requirements](https://github.com/artur-rios/heimdall-api/blob/main/docs/requirements/System%20Requirements%20Document.md)
