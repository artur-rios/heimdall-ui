# UI-38: List System Admins — design

**Issue:** [#149](https://github.com/artur-rios/heimdall-ui/issues/149).
**API:** UC-07 read (e), `GET /api/persons/system-admins` (heimdall-api#176, closed).
**Approved placement:** a tile on a System Admin's Home. No new navigation destination.

## 1. Purpose

A System Admin can see who else holds full access to Heimdall. They open a list of System Admins, search it, and open each one's person page.

Today that page can't be reached: person pages exist only under a scope (`/scopes/:scopeId/persons/:personId`), and a System Admin belongs to no scope.

**Success means:**
- A System Admin finds every other System Admin from Home in one tap.
- They can search by name or email.
- They can open a System Admin's person page, with the same actions the API allows on any person.

**Out of scope:** creating or promoting System Admins, and changing roles. The API offers neither here.

## 2. What the API gives

- **Request.** `GET /api/persons/system-admins?name=&email=&pageNumber=&pageSize=`. System Admin only; anyone else gets `403`.
- **Results.** It returns System Admins that are neither logically deleted nor restricted, ordered by name.
- **Projection.** Each person is projected to `id`, `name` and `email` only. There is no role, verification state or creation date.
- **Paging.** The response is paged (`PersonSummaryOutputPaginatedOutput`).
- **Client.** The generated client already has `personListSystemAdmins`; nothing in `lib` uses it yet.

## 3. The Home tile

- **Placement.** A System Admin's Home **Overview** grid gains one tile, after **Google users** and before the API status tile.
- **Content.**
  - label **System Admins**, icon `Icons.admin_panel_settings_outlined`;
  - value: the `totalItems` of a one-row page of the listing. This follows `DashboardController`'s rule that every figure is a listing the administrator could open;
  - caption "Full access to every scope".
- **Tap.** `/system-admins`.
- **Unreadable count.** If the count can't be read, the value is "—" with the tooltip "Could not be read", like the other tiles. The tile still opens the list.
- **Who sees it.** A Scope Admin's and a User's Home are unchanged.

## 4. `/system-admins`: the list

- **Route.** Route `/system-admins`, titled **System Admins**, with a back control to Home.
- **Filters.** **Name** and **Email** text filters apply when submitted (Enter or the **Search** button, as UI-16). A filter change resets to page 1.
- **Rendering.** The list renders through `AdaptiveCollection`, as every collection does (FR-UX-04): cards on compact windows, a table on wide ones.
  - The row shows the name and, under it, the email; there is no column of its own for the email, and the API returns nothing more.
  - Each row opens `/persons/{id}`.
  - The signed-in admin's own row is marked " (you)" after the name.
- **Paging.** Page size 20, with the app's pager.
- **Explanatory line.** Above the list: "System Admins can administer every scope. Deleted and restricted accounts are not listed."
- **Empty states** (FR-UX-06):
  - With a filter: "No System Admins match." and **Clear filters**.
  - Without one, which can't happen while the viewer is one: "No System Admins."
- **Failures:**
  - `403`: the app's forbidden state ("Not available for your role", **Back to Home**).
  - Other failures: `ErrorBanner` with **Retry**, keeping the filters.
- **State.** The controller is a plain `Notifier`, not a family, and is `autoDispose`, so leaving the screen forgets it. Overlapping requests queue the newest query, as UI-16 does, building every change from the queued query.

## 5. `/persons/:personId`: a person page without a scope

- **Route.** Route `/persons/:personId` reuses `PersonDetailScreen`, with `scopeId` made optional.
- **When `scopeId` is null:**
  - The back control and its tooltip go to `/system-admins` (**Back to System Admins**) instead of the scope's persons list.
  - After a delete it goes to `/system-admins`, which loads fresh; the list is disposed while the person page is open.
  - **Everything else is unchanged:** the fields, edit, delete and hard delete, and the account emails card. Each offer rule stays as it is, and the API decides each action.
- **Scoped persons are unchanged.** Persons reached through a scope keep their current route and behaviour.
- **Why not one route for every person?** Every link into a scoped person carries the scope, which the page uses for its back control and list refresh. Keeping both routes changes nothing for scoped persons.

## 6. Access

`roleMayReach` gains two rules, each with a comment citing UC-07 read (e):
- `'/system-admins'`: System Admin only.
- `'/persons/…'`: System Admin only. Read (a) lets a Scope Admin see only some persons, and they already reach those through their scopes.

## 7. Data

- **Repository.** Add `PersonRepository.listSystemAdmins({String? name, String? email, int pageNumber, int pageSize}) → Future<Result<Page<PersonSummary>>>`. Reuse the existing `PersonSummary` (`lib/features/persons/domain/person.dart:79`), which `listScopeAdmins` already returns. Map errors as the sibling list methods do.
- **Dashboard.** The dashboard reads the count through the same repository method with `pageSize: 1`, in parallel with its other reads, and only for a System Admin.

## 8. Docs

- **Use Case Specification Document.** A new `### UI-38: List System Admins`.
  - Actor: System Admin. Traces to UC-07.
  - Placement, main flow, and AF-38a–d: empty, no matches, forbidden, and failure.
  - Plus the inventory row, a diagram node with an SA edge, the traceability row, and a note on UI-18 (view a person) about the scope-less route.
- **System Requirements Document.**
  - FR-PE-12: "A System Admin can list the system's System Admins, filtered by name or email and paged, through `GET /api/persons/system-admins`, and open each one's person page."
  - The route rows for `/system-admins` and `/persons/:personId`, and the Authorization Matrix rows.
  - Add UI-38 to FR-UX-04 and FR-UX-06.
- **README.** Move "List System Admins" out of "Needs Heimdall API work" and into the person-management table, as `UI-38 … ✅ … #149`. Update the UI range to UI-01 … UI-38, in the README and in the Development Workflow Document.
- **CHANGELOG.** Under `### Added`: "**System Admins list** — a System Admin can see and search the system's System Admins from Home, and open their person pages."

## 9. Testing

- **Repository.** The path and query (`/api/persons/system-admins`, the filters, paging), the mapping, and a 403.
- **Controller.** Load, filters reset the page, overlapping loads refused, failure, and fresh state after disposal.
- **List screen.**
  - cards at 360 px and a table at 1400 px;
  - the **(you)** marker;
  - filters applied on Enter and on the search button;
  - empty with and without a filter;
  - 403 forbidden state and Retry;
  - tapping a row opens `/persons/{id}`.
- **Home.**
  - A System Admin sees the tile with the count, and its tap opens `/system-admins`.
  - If the count fails, the tile shows "—" and still opens the list.
  - A Scope Admin doesn't see the tile.
- **Person page without a scope.**
  - The back control goes to `/system-admins`.
  - An edit refreshes the System Admins list.
  - The account emails card follows its existing rules: hidden on your own record.
- **Routing.** A Scope Admin or a User opening `/system-admins` or `/persons/x` gets the not-available screen.
- **Gate.** `dart format --set-exit-if-changed . && flutter analyze && flutter test`.

## 10. Review focus

- A System Admin opening their own record from the list: the page must keep its self-protections (AF-19d).
- A deep link to `/persons/:id` for a scoped User, from a System Admin: it works, and back goes to `/system-admins`. Acceptable, since the page is the same.
- The count tile on a slow API must not delay the rest of the dashboard: it loads in parallel.

Amended while planning: Decisions 1–3 of the plan. Amended while documenting: the email shows under the name, not in a column. Amended after review (U1): `GET /api/persons/system-admins` is not rate limited, so there is no `429` flow (no AF-38e) and UI-38 is not in FR-UX-09; the `429` line in §4, the `429` in §8's AF list and §9's `429` test are removed.
