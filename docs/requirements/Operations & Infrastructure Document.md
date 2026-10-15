---
title: "Operations & Infrastructure Document"
linkTitle: "Operations & Infrastructure Document"
weight: 70
description: "How Heimdall UI is configured, built, packaged, and released for each of its four targets and four environments."
---

# Operations & Infrastructure Document — Heimdall UI

## 1. Purpose

This document covers everything between a checkout and a running application: how the client is
configured, how it is built for each target, what each build produces, what the host needs, and what
continuous integration does. The technologies themselves are recorded in the
[Technology Stack Document](Technology%20Stack%20Document.md).

Heimdall UI has **no server-side component of its own**. It is a client; the
[Heimdall API](https://github.com/artur-rios/heimdall-api) is the only backend, and every operational
concern about data, tokens, and email belongs there.

---

## 2. Configuration

Configuration is supplied at **build time** through Dart defines. Nothing is read from a file at
runtime, and no value is baked into source.

| Key | Required | Default | Purpose |
| --- | --- | --- | --- |
| `HEIMDALL_API_BASE_URL` | Yes, in any real deployment | `http://localhost:8080` | The API root. A trailing slash is trimmed. The default is the local heimdall-api (§2.2). A release build of the Windows, Linux or Android app refuses to start unless it is `https://`, or `http://` to `localhost` or `127.0.0.1`; it shows the reason on screen and in the log, naming the define to set. |
| `HEIMDALL_GOOGLE_CLIENT_ID` | Only for Google Sign-In | unset | The Google client id for the target. When unset, the Google control is hidden rather than shown broken. |
| `HEIMDALL_SCOPE_ID` | Only when no calling application supplies one | unset | The `PublicId` of the scope this build acts in. See §2.1 — on the web the calling application's value wins. |

### 2.1 The target scope

Heimdall UI is opened by the applications that use Heimdall's services, and **the scope being entered
is theirs to name**. There is no screen here that asks for it, and no endpoint an anonymous caller
could list scopes from, so it arrives from outside.

On the **web**, the calling application names the scope's `PublicId` as the `scope` query parameter
of the URL it sends the user to, on any route:

```text
https://heimdall.example.com/login?scope=<scope-public-id>
```

At start-up, before the router reads the address, the UI checks that the value is a GUID, copies it
into its own session storage under `heimdall.scopeId`, and replaces the address with one without it
(`history.replaceState`), so the history entry does not keep it either. A value that is not a GUID is
ignored, and removed all the same. Session storage is per origin, so a caller on another origin
could never have written the UI's; the URL is what lets the caller live elsewhere.

**The calling application must not be hosted on the UI's origin.** Script on that origin can read
everything the UI keeps in the browser, the session token included, so a flaw in a co-hosted caller
would hand over Heimdall sessions. A caller that does share the origin may still write the value
itself, as earlier versions required, and that keeps working; a stored value that is not a GUID is
ignored there too:

```js
sessionStorage.setItem('heimdall.scopeId', '<scope-public-id>');
```

Session storage rather than a cookie, deliberately:

- It is scoped to the tab, so two tabs can act in two scopes at once.
- It is never attached to a request, so the scope cannot become a header the API did not ask for,
  and cannot be replayed by a third party's form.
- It dies with the tab, so a scope does not outlive the visit on a shared machine.

The value is read on every use rather than captured at start-up, so opening the UI again with another
`scope` changes it.

On **Windows, Linux, and Android** there is no calling web application, so `HEIMDALL_SCOPE_ID` is the
whole answer. On the web it is the fallback used when the caller left nothing — a build opened
directly rather than handed off to.

When neither supplies a scope, the request is made without one and the API decides what that means.
Nothing is invented on the client's side.

Supply them per command:

```bash
flutter run --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

Or keep them in a file that is **not committed** — `config/local.json` is git-ignored. The tracked
`config/local.json.example` holds the local environment's values; copy it and fill in what applies:

```json
{
  "HEIMDALL_API_BASE_URL": "http://localhost:8080",
  "HEIMDALL_GOOGLE_CLIENT_ID": "",
  "HEIMDALL_SCOPE_ID": ""
}
```

```bash
flutter run --dart-define-from-file=config/local.json
```

> A Google client id is not a secret, but the API base URL of a private deployment can be. Neither
> belongs in the repository.

### 2.2 Environments

The UI is deployed to the same four environments as the
[Heimdall API](https://github.com/artur-rios/heimdall-api). It has no env file of its own: a deployed
build's values are build arguments, kept in [yggdrasil](https://github.com/artur-rios/yggdrasil)'s env
files on the VPS (`/etc/yggdrasil/<environment>/heimdall-ui.env`). `example.com` stands for the real
domain.

| Environment | Where | Deployed by | UI at | `HEIMDALL_API_BASE_URL` |
| --- | --- | --- | --- | --- |
| `local` | The developer's Windows machine, Docker Desktop | By hand — `flutter run`, or yggdrasil's `scripts/deploy.sh local heimdall-ui ...` | `http://localhost:8081` | `http://localhost:8080`, the local heimdall-api |
| `development` | The VPS, on demand (started only when used) | Jenkins, on every push to `develop`; a stopped environment stays stopped, and `scripts/ygg.sh env start development` on the VPS turns it on | `https://heimdall-dev.example.com` | `https://heimdall-dev.example.com` |
| `homologation` | The VPS, on demand | Jenkins, on every push of a `release/x.y.z` branch | `https://heimdall-hml.example.com` | `https://heimdall-hml.example.com` |
| `production` | The VPS, always on | Jenkins, on a green `release/x.y.z → main` pull request, which it then merges and tags | `https://heimdall.example.com` | `https://heimdall.example.com` |

**On the VPS the API base URL is the UI's own origin.** Traefik routes `/api/` on the UI's host to
the same environment's heimdall-api, and every API route begins with `/api/`, so the browser never
makes a cross-origin request and the API needs no CORS entry for the UI. **Locally they are two
origins** — the UI on `8081`, the API on `8080` — so the local heimdall-api lists
`http://localhost:8081` in `HEIMDALL_CORS_ALLOWED_ORIGINS`, and `flutter run -d chrome` takes
`--web-port 8081` to be that origin.

Because the values are compiled into the bundle, the image is built once per environment — the same
commit, a different bundle — and tagged `<environment>-<version>` by yggdrasil.

---

## 3. Prerequisites

| Target | Requirements |
| --- | --- |
| All | Flutter 3.47.7 or newer on the stable channel |
| Web | A Chromium-based browser for `flutter run -d chrome` |
| Windows | Visual Studio (or Build Tools) with the *Desktop development with C++* workload **and the C++ ATL component** |
| Linux | `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libstdc++-12-dev`, `libsecret-1-dev` |
| Android | The Android SDK including `cmdline-tools`, the **API 37 platform** (`platforms;android-37.0`), accepted SDK licences, and JDK 17 |

> **The Windows ATL component is not optional.** `flutter_secure_storage_windows`, which holds the
> session token in DPAPI, includes `atlstr.h`. Without *C++ ATL for latest v143 build tools* in the
> Visual Studio Installer, `flutter build windows` fails with
> `error C1083: Cannot open include file: 'atlstr.h'`. Install it from the Visual Studio Installer's
> *Individual components* tab.

> **Android needs more than the SDK directory.** `flutter doctor` reports `cmdline-tools component is
> missing` and `Android license status unknown` on a partial installation, and the build fails. Install
> the command-line tools and run `flutter doctor --android-licenses` once. Note that the command-line
> tools package Google's manifest lists is old enough to misread a current SDK's XML; use it to
> install `cmdline-tools;latest` and then discard it.

> **The app compiles against API 37, not Flutter's default of 36.** `flutter_secure_storage` 11
> publishes AAR metadata requiring its consumers to compile against 37, so `android/app/build.gradle.kts`
> sets `compileSdk = 37` explicitly. `minSdk` and `targetSdk` are untouched — this changes what the app
> compiles against, not which devices it runs on. Google publishes that platform as
> `platforms;android-37.0`; there is no plain `platforms;android-37` package.

On Debian or Ubuntu:

```bash
sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev
```

Confirm the toolchain before building:

```bash
flutter doctor
```

---

## 4. Building

Each command below produces a release build configured for a real API.

**Web** — a static bundle in `build/web`:

```bash
flutter build web --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

**Windows** — an executable and its DLLs in `build/windows/x64/runner/Release`:

```bash
flutter build windows --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

**Linux** — a bundle in `build/linux/x64/release/bundle`:

```bash
flutter build linux --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

**Android** — an APK in `build/app/outputs/flutter-apk`, or an App Bundle in
`build/app/outputs/bundle/release`:

```bash
flutter build apk --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

```bash
flutter build appbundle --release --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

---

## 5. Hosting the web build

`build/web` is a static bundle. Any static host serves it, with two requirements:

1. **Single-page routing.** Unknown paths must fall back to `index.html`, or a deep link such as
   `/scopes/{id}` returns a 404 from the host instead of reaching the router.
2. **CORS.** The API must permit the origin the bundle is served from. This is configured on the API,
   not here — unless, as in the VPS environments (§2.2), the API is served under the bundle's own
   origin, in which case there is nothing to permit.

Serve the bundle under a sub-path by building with a base href:

```bash
flutter build web --release --base-href=/heimdall/
```

### 5.1 Security headers

The container image's [`docker/nginx.conf`](../../docker/nginx.conf) sends these headers; another
host should send the same (NFR-10).

| Header | Value | Why |
| --- | --- | --- |
| `Content-Security-Policy` | Enforced; see below | A second line of defence against injected script |
| `Referrer-Policy` | `no-referrer` on `/password-reset` and `/verify-email`; `strict-origin-when-cross-origin` elsewhere | The reset and verification pages are opened with a token in the URL, and the page's scripts and assets are requested before start-up removes it. Elsewhere Google Identity Services asks for `strict-origin-when-cross-origin`, and a stricter policy would send it nothing. A proxy in front may replace this header; see below |
| `X-Frame-Options` | `DENY` | No framing, alongside `frame-ancestors 'none'` |
| `X-Content-Type-Options` | `nosniff` | |

**Referrer-Policy behind a proxy.** The per-route `no-referrer` only reaches the browser when nothing in
front replaces the header, as with the image served directly. Behind yggdrasil's Traefik it does not:
the `secure-headers` middleware attached to the UI's routers sets `Referrer-Policy:
strict-origin-when-cross-origin` on every response, replacing nginx's, so the reset and verification
pages get that policy too. There the protection is the application's own: it removes the token from
the address as it starts, so no request it makes afterwards carries the token in its Referer. The
page's own scripts and assets, requested before that, still send the full address to the UI's nginx,
which has already logged the same address on the request for the page itself.

> [!NOTE]
> For no Referer on those two routes behind a proxy, the edge middleware must not set
> `referrerPolicy` for the UI's routers (nginx's per-route value then reaches the browser), or must
> set a route-specific one: `no-referrer` for `/password-reset` and `/verify-email`. Confirm with
> `curl -sI https://<host>/password-reset` after deploying.

The Content-Security-Policy:

| Directive | Sources | For |
| --- | --- | --- |
| `default-src` | `'self'` | Everything not listed below |
| `script-src` | `'self' 'wasm-unsafe-eval' https://accounts.google.com/gsi/client` | The bundle; compiling CanvasKit's or skwasm's WebAssembly; Google Sign-In's library |
| `style-src` | `'self' 'unsafe-inline' https://accounts.google.com/gsi/style` | The engine and Google Sign-In inject `<style>` elements and style attributes; Google Sign-In's stylesheet |
| `connect-src` | `'self'`, the API's origin, `https://accounts.google.com/gsi/`, `https://*.googleusercontent.com`, `https://fonts.gstatic.com` | API calls; Google Sign-In's endpoints; Google profile pictures, which the engine fetches; the Noto fallback fonts the engine fetches for text the bundled Roboto has no glyphs for (emoji, CJK, Arabic and other scripts). The engine registers those bytes itself, so `font-src` needs no entry for them |
| `img-src` | `'self' data: https://*.googleusercontent.com` | Inline images; Google profile pictures shown as images |
| `font-src`, `manifest-src` | `'self'` | The bundled fonts (`--no-web-resources-cdn` bundles CanvasKit and Roboto) and the manifest |
| `frame-src` | `https://accounts.google.com/gsi/` | The Google Sign-In button and its prompts |
| `object-src`, `base-uri`, `form-action`, `frame-ancestors` | `'none'`, `'self'`, `'self'`, `'none'` | Nothing else may embed, re-base, post from or frame the page |

The API's origin is taken from `HEIMDALL_API_BASE_URL` when the image is built: the Dockerfile
replaces the `@HEIMDALL_API_ORIGIN@` placeholder in `nginx.conf`, and refuses to build when the URL is
not an absolute `http(s)` URL with a plain host name. On the VPS it is the page's own origin, and the
entry repeats `'self'`.

The policy was verified against release builds, CanvasKit and `--wasm` alike, served by the image's
nginx with headless Chromium: the sign-in screen, Google Sign-In's button, a sign-in request to an API
on another origin, an API answer in emoji, CJK and Arabic (its fallback fonts load from
`fonts.gstatic.com` and render), the reset and verification links, and the not-found screen, with no
violation. Without `https://fonts.gstatic.com` in `connect-src` such text renders as empty boxes.
`'unsafe-inline'` in `style-src` is required; without it the engine's own styles are refused. No
worker source is listed: neither renderer starts a worker on a page that is not cross-origin isolated,
which this one is not, so skwasm runs single-threaded. Google profile pictures were not exercised. Before
widening the policy, check the browser console for `Refused to …` messages, and add the narrowest
source that silences them.

`flutter run` serves without these headers, so a development session runs without the policy.

---

## 6. Desktop and Android distribution

- **Windows and Linux** builds are unsigned by default. Signing and packaging (MSIX, AppImage, deb)
  are deployment decisions and are not part of this repository.
- **Android** release builds require a signing configuration. Until one is provided, `flutter build
  apk --release` signs with the debug key, which is suitable for testing and not for distribution.
- No target auto-updates. Distribution and update are the operator's responsibility.

---

## 7. Refreshing the API client

The generated client tracks `api/heimdall.json`, a committed snapshot of the API's specification.
When the API changes:

```bash
dart run tool/refresh_openapi.dart ../heimdall-api/docs/openapi/heimdall.json
```

```bash
dart run tool/generate_api_client.dart
```

The generator also rewrites every path parameter of the generated clients to go through a small
`_pathSegment` helper, which percent-encodes it as one segment and refuses `.`, `..` and the empty
string: retrofit would otherwise interpolate an id as it is, and an id holding `/` or `?` would reach
a different endpoint.

Commit the refreshed specification together with the regenerated client. CI regenerates and fails if
the committed output differs, so the two cannot drift apart.

The privacy notice shown at `/privacy` is the API's own `docs/requirements/Privacy Notice.md`,
bundled verbatim as `assets/privacy/privacy_notice.md`. When the API publishes a new version, copy it
from the API's `main`:

```bash
dart run tool/refresh_privacy_notice.dart "https://raw.githubusercontent.com/artur-rios/heimdall-api/main/docs/requirements/Privacy%20Notice.md"
```

`https://<host>/privacy` is the **Application privacy policy link** on Google Auth Platform's
Branding page.

---

## 8. Continuous integration

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | Push to `main` or `develop`, and every pull request | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` |
| `build.yml` | Push to `main`, and manual dispatch | Builds web, Windows, Linux, and Android, and uploads each artifact |
| `check-api-client.yml` | Push to `main` or `develop`, and every pull request | Regenerates the client and fails if the committed output differs |
| `branch-policy.yml` | Every pull request into `develop` or `main` | Checks the branching model described in [CONTRIBUTING.md](../../CONTRIBUTING.md#branching-model) |

CI never receives a real API base URL: the analyze-and-test job needs none, and the build jobs use
the default so that no deployment address is exposed in a public log.

Deployment is not part of GitHub Actions. The web container image (see the README's *Container image
(web)*) is built and deployed by the self-hosted Jenkins in
[yggdrasil](https://github.com/artur-rios/yggdrasil), driven by the `Jenkinsfile`: a push to
`develop` deploys to development, a pushed `release/x.y.z` branch to homologation, and its pull
request into `main` to production once every check passes (§2.2) — see
[CONTRIBUTING.md](../../CONTRIBUTING.md#releasing).

---

## 9. Runtime behavior worth knowing

- **The token is the only stored state**, held in the platform's secure storage. Signing out deletes
  it. A challenge token is never stored.
- **On the web the token lives in the tab's session storage.** It is kept per tab and not shared:
  other tabs sign in on their own, and signing out clears it. A reload keeps the session, and so may
  a tab the browser brings back: a duplicated tab starts with a copy of the original's session
  storage, and reopening a closed tab or restoring the browser's last session can restore it too.
  On a shared machine, signing out is what ends the session; closing the tab may not. The token is
  encrypted there, but its key is kept in the same storage, so it is not protected from scripts
  running on the UI's own origin: what limits it on the web is the token's own lifetime.
- **An older build's token is removed.** Builds before per-tab sessions kept the token in local
  storage, beside the raw key it was encrypted with. Start-up on the web removes both, so it does not
  linger there until it expires.
- **Reset and verification links lose their token at start-up.** On the web the UI keeps the
  `token` of a `/password-reset` or `/verify-email` link in memory and removes it from the address,
  so neither the history entry nor the Referer of a later request carries it. Reloading the page
  afterwards drops it, and the link has to be opened again. Once used (a password set, or any answer
  to the verification) it is forgotten, so going back to the screen does not send it again.
- **Theme mode** is the only other persisted preference, in `shared_preferences`.
- **A `401` to any request made under the session** clears it and returns the user to sign-in; a
  session cannot outlive the API's opinion of its token. The exception is a `401` refusing a password
  or code typed into the request (a wrong second factor, or the password asked for to disable
  two-factor): that is the person's to correct, and the session is left alone.
- **A secure store the platform cannot use** — on Linux, a Secret Service keyring that is not
  running or is locked — means no session: start-up settles on sign-in, and signing in says the
  session could not be stored. On Android the app opts out of auto backup, so a restored device never
  holds a token it cannot decrypt.
- **Nothing is cached across launches.** Every listing is fetched from the API, paginated by it.
- **A session that ends takes what it showed with it.** Every screen's state is reset when the
  session ends, and an answer to a request made before that is dropped when it arrives, so the next
  person to sign in on the device starts from nothing.

---

## 10. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Every request fails on the web target while the API is reachable in a browser | The API does not permit the bundle's origin by CORS — locally, the page is not on `http://localhost:8081`; deployed, the base URL is not the UI's own origin (§2.2) |
| Sign-in succeeds, then every subsequent request answers `401` | The API base URL points at a different deployment from the one that issued the token |
| The Google control never appears | No `HEIMDALL_GOOGLE_CLIENT_ID` was supplied at build time, or the scope has Google Sign-In switched off |
| A deep link 404s in production but works locally | The static host is not falling back to `index.html` |
| `flutter build linux` fails on a fresh machine | The apt packages in §3 are not installed |
| `flutter build linux` fails with `required packages were not found: libsecret-1` | `libsecret-1-dev` is missing — it is a plugin dependency, not part of Flutter's generic desktop list |
| `flutter build windows` fails with `Cannot open include file: 'atlstr.h'` | The C++ ATL component is missing from Visual Studio (see §3) |
| `flutter build apk` fails after `flutter doctor` flags the Android toolchain | `cmdline-tools` is missing, or the SDK licences were never accepted (see §3) |
| `flutter build apk` fails with `Failed to find target with hash string 'android-37'` | The API 37 platform is not installed — `sdkmanager --install "platforms;android-37.0"` |
| A plugin module fails with `Could not close incremental caches in ...caches-jvm` | Kotlin incremental compilation; `kotlin.incremental=false` in `android/gradle.properties` turns it off, and is already set |
| CI fails on `check-api-client` | The specification changed without the client being regenerated, or the reverse |

---

## 11. References

- [Technology Stack Document](Technology%20Stack%20Document.md)
- [Development Workflow Document](Development%20Workflow%20Document.md)
- [System Requirements Document](System%20Requirements%20Document.md)
- [Heimdall API Operations & Infrastructure](https://github.com/artur-rios/heimdall-api/blob/main/docs/requirements/Operations%20%26%20Infrastructure%20Document.md)
