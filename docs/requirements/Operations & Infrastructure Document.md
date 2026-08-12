---
title: "Operations & Infrastructure Document"
linkTitle: "Operations & Infrastructure Document"
weight: 70
description: "How Heimdall UI is configured, built, packaged, and released for each of its four targets."
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
| `HEIMDALL_API_BASE_URL` | Yes, in any real deployment | `http://localhost:5000` | The API root. A trailing slash is trimmed. |
| `HEIMDALL_GOOGLE_CLIENT_ID` | Only for Google Sign-In | unset | The Google client id for the target. When unset, the Google control is hidden rather than shown broken. |

Supply them per command:

```bash
flutter run --dart-define=HEIMDALL_API_BASE_URL=https://heimdall.example.com
```

Or keep them in a file that is **not committed** — `config/local.json` is git-ignored:

```json
{
  "HEIMDALL_API_BASE_URL": "https://heimdall.example.com",
  "HEIMDALL_GOOGLE_CLIENT_ID": "000000000000-example.apps.googleusercontent.com"
}
```

```bash
flutter run --dart-define-from-file=config/local.json
```

> A Google client id is not a secret, but the API base URL of a private deployment can be. Neither
> belongs in the repository.

---

## 3. Prerequisites

| Target | Requirements |
| --- | --- |
| All | Flutter 3.44.9 or newer on the stable channel |
| Web | A Chromium-based browser for `flutter run -d chrome` |
| Windows | Visual Studio with the *Desktop development with C++* workload |
| Linux | `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libstdc++-12-dev` |
| Android | The Android SDK and JDK 17 |

On Debian or Ubuntu:

```bash
sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
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
   not here.

Serve the bundle under a sub-path by building with a base href:

```bash
flutter build web --release --base-href=/heimdall/
```

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
dart run swagger_parser
```

```bash
cd packages/heimdall_api_client && dart pub get && dart run build_runner build --delete-conflicting-outputs
```

Commit the refreshed specification together with the regenerated client. CI regenerates and fails if
the committed output differs, so the two cannot drift apart.

---

## 8. Continuous integration

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | Push to `main`, and every pull request | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` |
| `build.yml` | Push to `main`, and manual dispatch | Builds web, Windows, Linux, and Android, and uploads each artifact |
| `check-api-client.yml` | Push to `main`, and every pull request | Regenerates the client and fails if the committed output differs |

CI never receives a real API base URL: the analyze-and-test job needs none, and the build jobs use
the default so that no deployment address is exposed in a public log.

---

## 9. Runtime behavior worth knowing

- **The token is the only stored state**, held in the platform's secure storage. Signing out deletes
  it. A challenge token is never stored.
- **Theme mode** is the only other persisted preference, in `shared_preferences`.
- **A `401` from any request** clears the session and returns the user to sign-in; a session cannot
  outlive the API's opinion of its token.
- **Nothing is cached across launches.** Every listing is fetched from the API, paginated by it.

---

## 10. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Every request fails on the web target while the API is reachable in a browser | The API does not permit the bundle's origin by CORS |
| Sign-in succeeds, then every subsequent request answers `401` | The API base URL points at a different deployment from the one that issued the token |
| The Google control never appears | No `HEIMDALL_GOOGLE_CLIENT_ID` was supplied at build time, or the scope has Google Sign-In switched off |
| A deep link 404s in production but works locally | The static host is not falling back to `index.html` |
| `flutter build linux` fails on a fresh machine | The apt packages in §3 are not installed |
| CI fails on `check-api-client` | The specification changed without the client being regenerated, or the reverse |

---

## 11. References

- [Technology Stack Document](Technology%20Stack%20Document.md)
- [Development Workflow Document](Development%20Workflow%20Document.md)
- [System Requirements Document](System%20Requirements%20Document.md)
- [Heimdall API Operations & Infrastructure](https://github.com/artur-rios/heimdall-api/blob/main/docs/requirements/Operations%20%26%20Infrastructure%20Document.md)
