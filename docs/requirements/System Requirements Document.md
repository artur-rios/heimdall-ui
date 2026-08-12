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
| `FR-UX` | Shell, navigation, responsiveness, and theming |
| `NFR` | Non-functional |

---

## 2. Functional requirements

### 2.1 Authentication, session, and recovery (`FR-AU`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-AU-01 | The client shall authenticate a person by email and password through `POST /api/auth/login`. | UI-01 |
| FR-AU-02 | The client shall detect a two-factor challenge in the login response and continue into the challenge flow instead of establishing a session. | UI-01, UI-02 |
| FR-AU-03 | The client shall send a challenge token to `POST /api/auth/2fa/verify` and to no other endpoint, and shall never persist it. | UI-02 |
| FR-AU-04 | The client shall accept a generated code or a recovery code as the second factor, and shall let the user choose among the methods the API reports as available. | UI-02 |
| FR-AU-05 | The client shall store the bearer token and its expiry in the platform's secure storage, and shall restore the session from it at start-up. | UI-01, UI-07 |
| FR-AU-06 | The client shall discard a stored token whose expiry has passed without contacting the API. | UI-07 |
| FR-AU-07 | The client shall attach the bearer token to every authenticated request as an `Authorization: Bearer` header. | UI-07 |
| FR-AU-08 | The client shall clear the session and route to sign-in whenever the API answers `401`. | UI-07 |
| FR-AU-09 | The client shall offer Google sign-in when a Google client id is configured, exchange the resulting ID token at `POST /api/auth/google`, and sign out through `POST /api/auth/google/sign-out`. | UI-06 |
| FR-AU-10 | The client shall request a password reset through `POST /api/auth/password-recovery` and shall show the same confirmation whether or not the address is registered. | UI-03 |
| FR-AU-11 | The client shall accept a reset token from a link and complete the reset through `POST /api/auth/password-reset`. | UI-04 |
| FR-AU-12 | The client shall accept a verification token from a link and complete verification through `POST /api/auth/verify-email`. | UI-05 |
| FR-AU-13 | The client shall offer to resend a verification email through `POST /api/auth/resend-verification`. | UI-05 |
| FR-AU-14 | The client shall show an authenticated user with an unverified address a dismissible prompt offering to resend the verification email. | UI-05 |
| FR-AU-15 | The client shall show the signed-in person their own profile, read through `GET /api/persons/{id}`. | UI-08 |
| FR-AU-16 | The client shall let the signed-in person update their own name and email through `PUT /api/persons/{id}`. | UI-08 |
| FR-AU-17 | The client shall enable two-factor authentication through `POST /api/auth/2fa/enable` and confirm it through `POST /api/auth/2fa/confirm`. | UI-09 |
| FR-AU-18 | The client shall render an `otpAuthUri` as a scannable code and shall also present the secret as selectable text. | UI-09 |
| FR-AU-19 | The client shall display recovery codes exactly once, offer to copy or download them, and require acknowledgement before navigating away. | UI-09 |
| FR-AU-20 | The client shall disable two-factor authentication through `POST /api/auth/2fa/disable` and regenerate recovery codes through `POST /api/auth/2fa/recovery-codes/regenerate`. | UI-09 |

### 2.2 Scope management (`FR-SC`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-SC-01 | The client shall list scopes through `GET /api/scopes`, paginated by the API. | UI-10 |
| FR-SC-02 | The client shall filter the scope listing by name and shall let the user include logically deleted scopes. | UI-10 |
| FR-SC-03 | The client shall create a scope through `POST /api/scopes`, with a name, a description, and at least one owner. | UI-11 |
| FR-SC-04 | The client shall show a scope through `GET /api/scopes/{id}`, including its owners and its Google Sign-In state. | UI-12 |
| FR-SC-05 | The client shall update a scope's name and description through `PUT /api/scopes/{id}`. | UI-12 |
| FR-SC-06 | The client shall logically delete a scope through `DELETE /api/scopes/{id}` after confirmation. | UI-13 |
| FR-SC-07 | The client shall permanently delete a scope through `DELETE /api/scopes/{id}/hard` after a confirmation requiring the scope's name to be typed. | UI-13 |
| FR-SC-08 | The client shall list a scope's owners through `GET /api/scopes/{scopeId}/owners`. | UI-14 |
| FR-SC-09 | The client shall add an existing Scope Admin as a co-owner through `POST /api/scopes/{scopeId}/owners/{personId}`. | UI-14 |
| FR-SC-10 | The client shall create a new Scope Admin as a co-owner through `POST /api/scopes/{scopeId}/owners`. | UI-14 |
| FR-SC-11 | The client shall promote a user of the scope to owner through `POST /api/scopes/{scopeId}/users/{personId}/promote`, and shall remove an owner through `DELETE /api/scopes/{scopeId}/owners/{personId}`, each after confirmation. | UI-14 |
| FR-SC-12 | The client shall toggle a scope's Google Sign-In through `PUT /api/scopes/{id}/google-signin`. | UI-15 |

### 2.3 Person management (`FR-PE`)

| ID | Requirement | Use case |
| --- | --- | --- |
| FR-PE-01 | The client shall list the persons of a scope through `GET /api/scopes/{scopeId}/persons`, paginated by the API. | UI-16 |
| FR-PE-02 | The client shall filter the person listing and shall let the user include logically deleted persons. | UI-16 |
| FR-PE-03 | The client shall create a person within a scope through `POST /api/scopes/{scopeId}/persons`. | UI-17 |
| FR-PE-04 | The client shall let a System Admin create a person belonging to no scope through `POST /api/persons`. | UI-17 |
| FR-PE-05 | The client shall show a person through `GET /api/persons/{id}`, including role, scope membership, owned scopes, and verification state. | UI-18 |
| FR-PE-06 | The client shall update a person's name and email through `PUT /api/persons/{id}`. | UI-18 |
| FR-PE-07 | The client shall logically delete a person through `DELETE /api/persons/{id}` after confirmation. | UI-19 |
| FR-PE-08 | The client shall permanently delete a person through `DELETE /api/persons/{id}/hard` after a confirmation requiring the person's email to be typed. | UI-19 |

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
| FR-UX-01 | The client shall present navigation appropriate to the window's breakpoint: a bottom bar when compact, a rail when medium, and an extended rail when expanded. | UI-07 |
| FR-UX-02 | The client shall show only the destinations the signed-in role can use. | UI-07 |
| FR-UX-03 | The client shall support light, dark, and system theme modes, and shall remember the choice between launches. | — |
| FR-UX-04 | The client shall render collections as cards when compact and as a paginated table when expanded, from one declaration per collection. | UI-10, UI-16, UI-20, UI-24, UI-28 |
| FR-UX-05 | The client shall render the API's `errors` array as returned, against the offending field where the error names one and in a banner otherwise. | All |
| FR-UX-06 | The client shall distinguish an empty collection from a filtered collection with no matches, and shall offer the appropriate next action for each. | UI-10, UI-16, UI-20, UI-24, UI-28 |
| FR-UX-07 | The client shall show a retryable error state when a request fails for transport reasons, preserving the user's filters and input. | All |
| FR-UX-08 | The client shall address every screen by a URL, so that a link opens the screen directly on the web target. | UI-07 |

---

## 3. Screen inventory

| Route | Screen | Use case |
| --- | --- | --- |
| `/login` | Sign in | UI-01, UI-06 |
| `/login/two-factor` | Second-factor challenge | UI-02 |
| `/password-recovery` | Request password reset | UI-03 |
| `/password-reset` | Set a new password | UI-04 |
| `/verify-email` | Verify an email address | UI-05 |
| `/` | Home | UI-07 |
| `/profile` | Own profile | UI-08 |
| `/profile/security` | Two-factor and recovery codes | UI-09 |
| `/scopes` | Scope listing | UI-10 |
| `/scopes/new` | Create a scope | UI-11 |
| `/scopes/:scopeId` | Scope detail | UI-12, UI-13, UI-15 |
| `/scopes/:scopeId/owners` | Scope owners | UI-14 |
| `/scopes/:scopeId/persons` | Person listing | UI-16 |
| `/scopes/:scopeId/persons/new` | Create a person | UI-17 |
| `/scopes/:scopeId/persons/:personId` | Person detail | UI-18, UI-19 |
| `/scopes/:scopeId/applications` | Application listing | UI-20 |
| `/scopes/:scopeId/applications/new` | Create an application | UI-21 |
| `/scopes/:scopeId/applications/:applicationId` | Application detail | UI-22, UI-23 |
| `/scopes/:scopeId/permissions` | Permission listing | UI-24 |
| `/scopes/:scopeId/permissions/new` | Create a permission | UI-25 |
| `/scopes/:scopeId/permissions/:permissionId` | Permission detail | UI-26, UI-27 |
| `/scopes/:scopeId/google-users` | Google user listing | UI-28 |
| `/scopes/:scopeId/google-users/:googleUserId` | Google user detail | UI-29 |
| `/health` | API health and diagnostics | P-04 |

---

## 4. Authorization matrix

What each role is offered. The API remains the authority: this table describes what the interface
shows, and a request the API refuses is refused regardless of what appears here.

| Screen | System Admin | Scope Admin | User | Anonymous |
| --- | --- | --- | --- | --- |
| Sign in, recovery, reset, verification | — | — | — | Full |
| Second-factor challenge | Full | Full | Full | Held challenge only |
| Home | Full | Full | Full | Hidden |
| Own profile and security | Full | Full | Full | Hidden |
| Scope listing | All scopes | Owned scopes only | Hidden | Hidden |
| Create scope | Full | Hidden | Hidden | Hidden |
| Scope detail and update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete scope | Full | Hidden | Hidden | Hidden |
| Permanent delete scope | Full | Hidden | Hidden | Hidden |
| Scope owners | Full | Owned scopes only | Hidden | Hidden |
| Toggle Google Sign-In | Full | Owned scopes only | Hidden | Hidden |
| Person listing, create, update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete person | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete person | Full | Hidden | Hidden | Hidden |
| Application listing, create, update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete application | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete application | Full | Hidden | Hidden | Hidden |
| Permission listing, create, update | Full | Owned scopes only | Hidden | Hidden |
| Logical delete permission | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete permission | Full | Hidden | Hidden | Hidden |
| Google user listing and detail | Full | Owned scopes only | Hidden | Hidden |
| Logical delete Google user | Full | Owned scopes only | Hidden | Hidden |
| Permanent delete Google user | Full | Hidden | Hidden | Hidden |
| Health and diagnostics | Full | Read-only | Hidden | Hidden |

---

## 5. Non-functional requirements

| ID | Requirement |
| --- | --- |
| NFR-01 | Every screen shall be usable at the compact (`< 600`), medium (`600 – 1024`), and expanded (`> 1024`) breakpoints, with no horizontal scrolling of the page itself. |
| NFR-02 | Every screen shall be legible in both the light and the dark theme, with no hard-coded color that ignores the active scheme. |
| NFR-03 | The same source shall build and run on web, Windows, Linux, and Android, with no behavioral difference beyond what a platform itself imposes. |
| NFR-04 | The bearer token shall be held in the platform's secure storage, and the challenge token shall never be written to storage at all. |
| NFR-05 | No secret shall be committed to the repository or embedded in a built artifact. |
| NFR-06 | Every collection shall be paginated through the API; the client shall never fetch a whole collection to page it in memory. |
| NFR-07 | Every screen shall be operable by keyboard, shall preserve a sensible focus order, and shall give every icon-only control a semantic label. |
| NFR-08 | The client shall enforce no authorization the API does not; hiding a control is a usability decision, never a security control. |
| NFR-09 | The web target shall reach interactive in under three seconds over a warm cache on a broadband connection. |

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
