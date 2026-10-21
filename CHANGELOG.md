# Changelog

All notable changes to Heimdall UI are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- The Android release build now declares the `INTERNET` permission, which Flutter adds to debug and profile builds
  only, so an installed release APK can reach the API. The Android CI job fails if the built APK lacks it (#155).
- A request that fails without any answer, whatever Dio calls it (an unknown error or a bad certificate as well as
  a timeout), now offers **Retry** instead of a bare error (#169).
- Typing a name to confirm a permanent deletion no longer depends on leading or trailing whitespace in the stored
  name or in what was typed (#184).
- Opening a second password reset or email verification link in the same app run starts from a clean state instead
  of showing the previous link's result, which hid the reset form (#158).
- Verifying an email address no longer hides the signed-in administrator's own "verify your email" prompt unless
  their own address is now verified, as the API reports it; a link mailed to somebody else leaves the prompt (#170).
- Completing a second factor on a device whose secure storage refuses the session token now says the device could not
  store the session, instead of reporting an expired sign-in (#163).
- A user whose account needs a second factor now lands on the page they originally asked for after completing it,
  instead of on Home (#164).
- Signing in or confirming an erasure with Google now runs one flow at a time: a second token event, a click on
  Google's own web button while the password form submits, or a double tap on the erasure button no longer starts a
  second exchange or a second Google flow (#168).
- Submitting the create-owner dialog while the owners are still loading or another change is on its way now keeps
  the dialog open with what was typed and says nothing was sent, instead of closing as if the owner had been
  created (#165).
- The owner picker now opens on its loading state instead of the list it showed last time, which still held the
  owner just added and led to the API's "already an owner" refusal, and only the latest of overlapping searches
  writes its result (#166).
- The owner selector on an application's detail page now offers **Retry** after a failed read of the scope's
  people, and always shows the application's current owner, as a disabled entry when the loaded list does not
  contain them, instead of looking empty while Save would send the old owner (#167).

### Changed

- The operations document and the comment in the web image's `nginx.conf` now say that yggdrasil's edge, from
  0.7.4, leaves the image's Referrer-Policy in place, so `/password-reset` and `/verify-email` send `no-referrer`
  in deployed environments too. Behind a proxy that replaces the header, the token removed from the address at
  start-up remains the protection. The `curl -sI` check in the document now shows the headers production returns.

## [1.9.0] - 2026-10-19

### Added

- A **Scope invitations** card on Home lists the invitations to co-own a scope that the signed-in administrator has
  not answered yet (the scope, who invited them and the expiry), with **Accept** and **Decline**, each confirmed.
  After accepting, the scope appears in the scope list and on the dashboard. An invitation that was withdrawn,
  expired or already answered is reported in the API's words and the list is read again (UI-39).
- The scope owners screen lists **Pending invitations**, with each person's address and the expiry, and withdraws one
  after a confirmation (UI-14).

### Changed

- Adding an existing administrator as a co-owner while signed in as a Scope Admin now shows "Invitation sent" and
  lists the person under **Pending invitations**: the heimdall-api release that carries scope invitations invites
  them instead of adding them, and they become an owner only by accepting. The client tells the two apart by the
  answer's `invited` field. A System Admin's add is unchanged. **Deploy order:** deploy this heimdall-ui release
  **before** the heimdall-api release that carries scope invitations. Against an older API it behaves as before: the
  add is immediate, and the invitation listings, which that API does not have, show nothing.

## [1.8.0] - 2026-10-16

### Changed

- Release signing of the Android app uses the keystore from the environment when configured
  (`HEIMDALL_UI_KEYSTORE_PATH`, `HEIMDALL_UI_KEYSTORE_PASSWORD`, `HEIMDALL_UI_KEY_ALIAS` and
  `HEIMDALL_UI_KEY_PASSWORD`), or from a git-ignored `android/key.properties`. Without them the release build uses
  the debug key and prints a warning in the build output; such a build is for testing only. A partial configuration
  fails the build.
- The web image now sends an enforced Content-Security-Policy, which allows the page to load script and connect only
  to its own origin, the API's origin, Google Sign-In, Google profile pictures (`*.googleusercontent.com`), and
  Google's font service for characters the bundled font has no glyphs for, such as emoji and Chinese, Japanese or
  Arabic text. The API's origin comes from `HEIMDALL_API_BASE_URL`, which must now be an absolute `http(s)` URL.
- On the web, a calling application now hands over the target scope in the URL, as `?scope=<scope id>` on any page,
  instead of writing it into the UI's session storage, which only worked from the UI's own origin. The UI keeps it for
  the tab and removes it from the address bar; a value that is not a scope id is ignored. Callers must not be hosted
  on the UI's origin. Writing the session storage value from the same origin keeps working.
- On the web, a session now belongs to its browser tab: each tab signs in on its own, and the token is no longer kept
  where other tabs can use it. Reloading the tab keeps you signed in, and signing out clears it. A browser that
  restores a closed tab may restore its session too, so sign out on a shared computer.
- A release build of the Windows, Linux or Android app now refuses to start when its API address is not `https://`,
  instead of sending passwords and tokens in the clear, and shows a screen saying why. The local API at `localhost` or
  `127.0.0.1` is still allowed.

### Fixed

- Recovery code fields no longer let the keyboard autocorrect or complete what is typed, and type capitals, so the
  longer `XXXX-XXXX-XXXX-XXXX` codes go to the API exactly as written; codes in the older `XXXX-XXXX` form keep working.
  The security screen says that a set in the shorter form can be replaced by generating new codes, which are stronger.
- Changing your own email address while the email sign-in method is on is refused by the API; the profile now shows
  why, keeps what you typed, and offers **Open security settings** to turn the method off first.
- When the API holds back an account email (a new verification link, the code that sets up the email sign-in method,
  or an email change's notice) because one was sent recently or the day's limit is reached, its message is shown with
  how long to wait, and the button that would ask again stays disabled until then, for at most a day. The same applies
  to sending a new sign-in code when the API says to wait, whose button counts the wait down. A wait of minutes or
  hours is now named in minutes or hours instead of seconds, and an unreadable, zero or out-of-range wait no longer
  shows a nonsensical one. Creating a person or a co-owner while the API is rate limiting keeps the form as typed.
- A mistyped password or code when turning two-factor authentication on or off, confirming its setup, generating new
  recovery codes, changing your own email address or asking for erasure is shown on the form and keeps you signed in
  when the API answers "The password or code is incorrect.", which it now gives for all of these, and for a check it
  has paused after repeated failures. A wrong setup code, now answered `401`, no longer signs you out either. The
  earlier messages are still recognised.
- After saving a copy of your data, the screen now also says that the file holds your personal data and is not
  encrypted, and that it should be kept somewhere private and deleted when no longer needed.
- Choosing the System Admin role when creating a person now asks for confirmation before anything is sent, saying the
  person will be able to administer every scope. The password fields for a new person and a new scope co-owner are
  now marked as new passwords, so a password manager no longer offers, or offers to overwrite, the creating admin's
  own saved password.
- A copied credential secret, authenticator setup key or set of recovery codes is now cleared from the clipboard after
  60 seconds where the platform allows, unless something else has been copied since. When the app cannot read the
  clipboard at that moment, as in the background, the check waits and runs each time the app returns to the
  foreground until it can. It is not attempted in a browser, and it does not happen if the app is closed first. On
  Android the window is also kept out of screenshots, screen recordings and the recents thumbnail while a secret or
  recovery codes are on screen.
- On the web, the token of a password reset or email verification link is now removed from the address as the page
  opens, so it no longer stays in the address bar or the page's history entry, and later requests do not carry it;
  reloading the page afterwards needs the link again. The web image's nginx asks for no Referer from those two pages;
  in deployed environments Referrer-Policy is set by the reverse proxy.
- A session token kept in the browser's local storage by an earlier version, and the key it was encrypted with, are
  now removed when the UI opens, instead of lingering until the token expired.
- A link whose id is not a well-formed identifier now shows "Not found", and every id is sent to the API as one
  encoded part of the address.
- Requests now always act as the person the screen shows. A tab used to pick up the session of whoever signed in or
  out in another tab of the same browser, while still showing its own.
- Signing out of a Google session could leave you signed in, with the Sign out button doing nothing, when Google's
  sign-out or the API's failed unexpectedly or never answered. The session now always ends, within a few seconds, and
  the stored token is always removed. A Google sign-in that failed unexpectedly, or was refused and whose clean-up
  failed, kept its spinner turning; it now says so and offers the button again.
- A response that arrived after signing out could fill the screen the next person to sign in on the same device opened
  first: lists, records, the dashboard, the profile, two-factor and restricted-account screens. Such responses are now
  dropped. A scope's Sign-in & sign-up settings are also cleared at sign-out, as every other screen's are.

## [1.7.0] - 2026-10-15

### Added

- **System Admins list** — a System Admin can see and search the system's System Admins from Home, and open their
  person pages.
- **Application credentials** — administrators can issue an application a secret (shown once), see its credentials, and
  revoke them.
- **Account emails** — administrators can have a verification link or a password reset link sent to a person's own
  address.
- **Pending registrations** — a scope's owners and System Admins can see who signed up but has not confirmed, and
  discard a registration.
- **Audit log** — System Admins can browse the audit trail, newest first, filtered by dates, action, actor, target and
  outcome; identifiers can be copied or used as a filter.
- A **Sign-in & sign-up** screen for each scope, opened from the scope's page. It holds the Google Sign-In switch
  (moved from the scope's page), a new self-registration switch, and the links the scope's verification and
  password-reset emails point at, so a client application's own screens can receive them. Opening self-registration
  without a verification link, and closing it, each ask first and say what will happen.
- **Send a new code** on the two-step verification screen when the code comes by email. It waits 30 seconds between
  sends and, after three, offers to start the sign-in again, matching the API's limit.
- An **Erasure requests** screen for System Admins: the erasure requests not yet carried out, soonest deadline first,
  with the overdue and blocked ones marked and an overdue-only filter. From it, **Re-apply erasures** runs the
  post-restore step: paste the identifiers from the logs, confirm, and see what was anonymised again.
- **Restrict processing of my account** on the profile. It asks why, offering the four grounds the law allows in
  plain words, says that the account is suspended until the restriction is lifted, and then signs the person out.
  Signing in again opens the restricted session, from which the restriction is lifted or the person's data
  downloaded or erased. The API's answer is shown as it comes, including when processing is already restricted.

### Changed

- Changing your email or turning on 2FA now asks for your password; you sign in again afterwards. Changing your email
  also asks for a code from your authenticator app, or a recovery code, when two-factor authentication is on. Turning
  two-factor authentication off, and generating new recovery codes, sign you out too, once any new codes have been
  shown, and you sign in again. The sign-in screen says "Your sign-in details changed. Sign in again." A wrong
  password or code is shown on the form and keeps you signed in.
- On a person's page, your own email address is read-only; it is changed from your profile. Administrators changing
  somebody else's address are not asked for a password.

### Fixed

- A list screen stayed on its loading placeholder for good, with no error and no Retry, when the API answered with a
  body the app could not read. The eight lists (people, scopes, applications, permissions, Google users, erasure
  requests, pending registrations and System Admins) now show "The API returned an unexpected response." with Retry.
- The System Admins list could be left on an empty page with no pager when the last admin of the last page went
  away. It now steps back to the last page that still exists, as the other lists do.
- On a short window, or with a soft keyboard open, a System Admin's navigation rail ran off the bottom and its
  last destinations could not be reached. The rail now scrolls.
- Closing or refreshing the browser tab while a credential's secret was still to be stored lost the secret
  without a word. The browser now asks before leaving, as the app already did for Back and in-app navigation.
- The request log of a debug build printed every request's headers, the bearer token among them. It now
  writes one line per request, with the method, path, status and duration, and never headers, query strings, bodies
  or an error's text. Release builds log nothing, as before.
- When the API could not be reached, most screens showed the HTTP library's own text, such as "The connection
  errored: … This indicates an error which most likely cannot be solved by the library." Every screen now says
  "Could not reach the API. Check your connection and try again."
- Rate-limited requests now say so, and how long to wait when the API tells us.
- Password sign-in sent no scope, so a person with the User role was always told their credentials were invalid.
  It now sends the configured scope, the same one Google sign-in sends; with none configured only administrators can
  sign in, as before.
- Signing in with Google ended the session almost at once: the home screen read the account as a person, the API
  answered that no such person exists, and the interface took that to mean the account had been deleted. A Google
  session now reads its own Google user record. The profile shows the name, email and picture read-only, since they
  come from the Google account, and offers **Security** and **Restrict processing of my account**; the home screen
  shows the Google account's name and email.

## [1.6.1] - 2026-10-12

### Fixed

- Password manager extensions such as Bitwarden still could not fill the sign-in form on the web. Flutter only puts
  an input in the page while a field has focus, gives the other field no size, and removes both as soon as focus
  moves, so an extension never found a login form. On the web the email and password are now real inputs that are
  always in the page, at full size, in one sign-in form, and the form tells the extension when the credentials are
  submitted so it can offer to save them. A space can be typed in either field, and Tab and the arrow keys behave as
  in any web form.

## [1.6.0] - 2026-10-12

### Added

- A home dashboard replaces the "Your profile and security" button. Everybody sees their own account: the address
  and whether it is verified, whether two-factor authentication protects it, and their role, each one tap from where
  it is changed. A System Admin or Scope Admin also sees an overview of the scopes they administer: how many there
  are (and how many are deleted), the Users, applications, permissions and Google users in them, how many have Google
  Sign-In on, and whether the API is reachable. Below it, each scope is listed with its own counts and opens with a
  tap. The figures come from the listings the administrator could open themselves, summed over their first ten
  scopes, and the dashboard says so when there are more. A count that cannot be read shows as "—" rather than as
  zero. A refresh button and pull-to-refresh read them again.
- A **Home** destination in the navigation. A User, who was offered only Profile, now has navigation too.
- The version of the app — "Heimdall UI v1.6.0" — at the bottom of every screen, signed in or not. It is kept in
  `pubspec.yaml` and `lib/app/app_version.dart`, which are set when a release's changelog is finalized; a test and
  the Branch Policy workflow keep them in step with the release (see CONTRIBUTING.md).

### Changed

- A record's fields are read-only until **Edit** is pressed, on the scope, person, application and permission
  detail screens and on the profile. Editing offers **Cancel**, which puts back what the API holds, and **Save
  changes**; a successful save ends the edit. Somebody who may not change a record is not offered Edit at all.
- The back control sits before the title, where it is expected, instead of among the actions on the right. Scope
  detail and the create screens have one too; on a create screen it asks before discarding what was typed.
- The navigation shows the current destination with a filled icon.
- The scope detail screen counts the scope's owners instead of listing their identifiers, and the person and
  application screens put the deletion controls last.
- Form dialogs scroll instead of overflowing when a phone's keyboard is open.

### Fixed

- Signing out forgot nothing: the next person to sign in on the same device was first shown the previous one's
  scopes, filters and records, and inherited their dismissed verification prompt.
- Deleting the last item of the last page of a listing left an empty "nothing here yet" page with no pager to go
  back with. The listing now moves to the last page that exists.
- A search, filter or page change made while a listing was still loading was silently dropped. It is now asked as
  soon as the first answer arrives. Returning to a listing shows the search it is still filtered by.
- Freshly issued recovery codes were lost, with no warning, by tapping a navigation destination or signing out;
  only the back button asked first. Every way off the security screen now asks. Leaving with the system back
  gesture now leaves after confirming, instead of needing a second press.
- Pressing Enter twice on the sign-in or two-factor screen sent the attempt twice.
- The owner picker for an application said nobody could own one when the scope's owners simply could not be read,
  and kept that answer for the whole session. It now says the list could not be read and offers a retry, and it
  is read again after the scope's owners change.
- On a scope or record detail screen, starting a save, a deletion or a Google Sign-In change while another was in
  flight could leave a spinner that never stopped or a switch showing the wrong state. Each now waits for the
  other.
- A create form, or the password recovery screen, reopened showing the refusal or confirmation of an earlier
  visit. They now start clean.
- After a Scope Admin removed their own ownership, the owners screen offered a Retry that could only fail. It now
  says the scope is not theirs and goes back to the scopes.
- "Choose an owner for the application." stayed on screen after an owner was chosen.
- "Saved." stayed on a record after further edits.
- A co-owner the API refused, say for an address already taken, had to be typed again from scratch: the dialog
  closed before the answer came. It now stays open with the refusal shown above what was typed.
- An application's owner whose name could not be read once, for example over a dropped connection, was shown by
  identifier for the rest of the session, and a renamed owner kept their old name. Only a definite answer is
  remembered now, and reloading the listing reads the names again.
- Leaving an unsaved create form or an unsaved edit through the navigation, the back control or signing out
  dropped it without asking. Every way off the screen now asks first; only Cancel did before.

## [1.5.1] - 2026-10-12

### Fixed

- Browser password managers such as Bitwarden can fill the sign-in form. On the web each credential field was its own
  one-input form, so the email and password never appeared together and the form was not recognised as a login.

## [1.5.0] - 2026-10-11

### Added

- The scope detail screen shows the scope's ID, with a button to copy it. A calling application passes this ID to
  Heimdall to create and authenticate its users, and no screen showed it before.
- A Heimdall favicon and app icons — a white shield with a keyhole on the theme blue — replace Flutter's defaults. The
  web manifest is named "Heimdall" and uses the theme color.

## [1.4.0] - 2026-10-11

### Added

- A restricted session (UI-30). A person or Google User whose processing is restricted at their own request can
  sign in again, and the API answers with a token that admits only their own data-protection rights. Instead of
  landing on screens that would all fail with `403`, they reach a single screen at `/restricted` — and the privacy
  notice — that says plainly why, and offers four actions: **Lift the restriction** (they are then signed out, and
  the sign-in screen says to sign in again for full access), **Download my data** (a JSON file: a browser download
  on the web, the downloads folder elsewhere), **Request erasure** (confirmed with the password, or by signing in
  with Google again for a Google User), and **Sign out**. The session is recognised from the sign-in answer's
  `processingRestricted` flag and, when restored from storage, from the token's `subjectRightsOnly` claim.
  Requires heimdall-api 1.3.0 (artur-rios/heimdall-api#162); the vendored API specification and the generated client
  carry the new flag. Dependency: `path_provider` 2.1.6, already in the tree, is now a direct one.

## [1.3.0] - 2026-10-09

### Added

- A System Admin can own a scope. The create-scope form has an **Add me** button beside **Add owner**, and the owner
  picker lists System Admins as well as Scope Admins when a System Admin opens it, so a first scope can be created
  before any Scope Admin exists. Requires heimdall-api 1.2.0, which accepts System Admin owners; the vendored API
  specification and the generated client carry its updated descriptions.

### Changed

- Dependencies on their latest stable versions: `go_router` 17.5.0 → 18.0.2, `dio` 5.11.0 → 5.11.1,
  `shared_preferences` 2.5.5 → 2.5.6, `build_runner` 2.15.1 → 2.16.2 and `retrofit_generator` 10.2.8 → 10.2.11,
  with their transitive packages; the generated API client's own constraints follow, and its `retrofit` 4.9.2 →
  4.10.0. go_router 18 only moves onto the `material_ui` and `cupertino_ui` packages, so no application code
  changes. The regenerated client gains one `// ignore_for_file: type=lint` line in each `*_client.g.dart`. Flutter
  3.47.7 is still the latest stable release.
- Android build: Android Gradle Plugin 9.0.1 → 9.1.1, Kotlin Gradle Plugin 2.3.20 → 2.4.0 and Gradle 9.1.0 → 9.3.1,
  the newest Flutter 3.47.7's tooling supports. Newer releases (AGP 9.4, Gradle 9.8, Kotlin 2.4.21) are past its
  known range and wait for a Flutter release that supports them.
- CI: `actions/upload-artifact` v6 → v7.
- The Technology Stack Document's dependency tables match `pubspec.yaml` again; several constraints there had
  fallen behind.

### Fixed

- Submitting the create-scope form without an owner did nothing: no request, and no message. The form now says
  "Add at least one owner — a Scope Admin, or yourself." under the owners, and clears it once one is added.
- Every form says what is stopping it from being submitted. The first refused field is scrolled into view with its
  message, so an error above the fold no longer looks like a dead button. The application forms refuse a missing
  owner on screen, including when the scope has nobody who could own one. Each edit screen's disabled **Save
  changes** button now says "No changes to save yet."

## [1.2.0] - 2026-10-09

### Added

- A public privacy notice at `/privacy`, linked from the sign-in screen, for Google's consent screen to name as the
  application's privacy policy. It opens signed in or out, and shows the Heimdall API's own Privacy Notice — version
  and date included — bundled verbatim from the API repository and refreshed with
  `dart run tool/refresh_privacy_notice.dart`. Dependencies: `flutter_markdown_plus` 1.0.12 renders it, and
  `url_launcher` 6.3.3 opens its links.

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

[Unreleased]: https://github.com/artur-rios/heimdall-ui/compare/v1.9.0...HEAD
[1.9.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/artur-rios/heimdall-ui/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.5.1...v1.6.0
[1.5.1]: https://github.com/artur-rios/heimdall-ui/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/artur-rios/heimdall-ui/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/artur-rios/heimdall-ui/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/artur-rios/heimdall-ui/releases/tag/v1.0.0
