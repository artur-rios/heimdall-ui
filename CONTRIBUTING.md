# Contributing

## Prerequisites

The toolchain for each target is listed under [Prerequisites](./README.md#prerequisites) in the README; check it
with `flutter doctor`. After cloning, run `flutter pub get`.

## Project structure

| Path | Responsibility |
| --- | --- |
| `lib/app/` | Application root, router and its guard, themes |
| `lib/core/` | Configuration, HTTP and interceptors, envelope unwrapping, result model, token storage |
| `lib/features/<feature>/data/` | Repository implementations over the generated client |
| `lib/features/<feature>/domain/` | Entities and repository interfaces |
| `lib/features/<feature>/presentation/` | Screens, widgets, and controllers |
| `lib/shared/` | Widgets with no feature knowledge — the adaptive shell, breakpoints |
| `packages/heimdall_api_client/` | The generated API client (never hand-edited) |
| `api/heimdall.json` | Vendored snapshot of the API's OpenAPI specification |
| `tool/` | Specification refresh and client generation |
| `test/` | Mirrors `lib/` one directory at a time |
| `docs/requirements/` | The specification documents |

Presentation code never imports `package:heimdall_api_client`; it depends on the domain repository
interfaces, and only `data/` knows the generated types exist.

## Generated API client

The generated API client is committed, so no generation step is needed for a normal checkout. To
regenerate it after the API's specification changes:

```bash
dart run tool/refresh_openapi.dart ../heimdall-api/docs/openapi/heimdall.json
```

```bash
dart run tool/generate_api_client.dart
```

Commit the refreshed specification and the regenerated client together — CI fails when they
disagree.

## Test

```bash
flutter test
```

```bash
flutter test integration_test
```

```bash
flutter test --coverage
```

The gate before every pull request is all three of these, passing:

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
```

Tests are named `GivenSomeCondition_WhenSomeAction_ThenSomeOutput`, and each body is divided by
`// Given`, `// When`, and `// Then` comments. No test reaches the network: HTTP is stubbed through a
local Dio adapter, and controllers are tested against fake repositories. See the
[Testing Specification Document](docs/requirements/Testing%20Specification%20Document.md).

## Branching model

```
feature/<name> ─┐
fix/<name> ─────┴─▶ develop ──▶ release/x.y.z ──▶ main  (tag vx.y.z)
```

| Branch | Cut from | Merges into | How |
|---|---|---|---|
| `feature/<name>`, `fix/<name>` | `develop` | `develop` | Pull request, squash or merge. The branch is deleted on merge. |
| `release/x.y.z` | `develop` | `main` | Pull request. **Never merged by hand** — see below. |
| `develop`, `main` | — | — | Protected: no direct pushes, no force pushes, no deletion. |

Names are lowercase: letters, digits, `.`, `_` and `-`. A `release/` branch is a snapshot of
`develop` and carries no commits of its own: a fix for a release lands on `develop` through a
`fix/` branch and a new release branch is cut.

The **Branch Policy** workflow checks all of this on every pull request and is a required check
on `develop` and `main`.

Each use case ships on its own `feature/` branch, issue and pull request into `develop` — see the
[Development Workflow Document](docs/requirements/Development%20Workflow%20Document.md) for the
issue status and testing gate it follows.

## Commits and the changelog

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) with a lowercase subject, e.g.
`feat(ui-09): manage two-factor authentication` or `fix: route the web build on the path, not the hash`.

Record every change a user of the app would notice under `## [Unreleased]` in [CHANGELOG.md](./CHANGELOG.md), in
the same pull request that makes it.

## Versioning

Heimdall UI follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). For an application, what a version
number promises is about the people who use it and the people who build and deploy it: the screens and flows users
rely on, the data the app keeps on a device, the configuration it is built with, and the Heimdall API it works
against.

- **Major** — a release that breaks something users or operators rely on. A screen or flow is removed, or works so
  differently that people have to relearn it; the session or other state stored on a device is no longer read, so
  everyone is signed out or loses settings; a build argument or `--dart-define` value is renamed, removed or
  becomes required; the app stops working against a Heimdall API release the previous version supported, or drops
  a target platform. Its entry in [CHANGELOG.md](./CHANGELOG.md) carries an `### Upgrading from <X>.x to <Y>.0`
  section saying what to change.
- **Minor** — new capabilities that leave existing ones working as before: a new screen or use case, a new
  optional configuration value whose default keeps the previous behaviour, support for something the API added.
- **Patch** — fixes with no new capability: a defect, a layout or wording correction, a dependency update.

The release version is not stored in the source. It is the name of the release branch: `release/1.4.0` is deployed
as the image tag `1.4.0-<short commit>`, which is what the yggdrasil console shows, and when it reaches
production Jenkins tags the merge `v1.4.0` and creates the GitHub release of that name. The Branch Policy workflow
refuses a release branch whose version already has a tag.

The `version:` in `pubspec.yaml` is **not** the release version. It is still Flutter's template value,
`1.0.0+1`, and is not bumped for a release — `v1.0.1` was built with it unchanged. Flutter compiles it into
every build as the build name and build number (the Android `versionName` / `versionCode`, the Windows file
version, the web build's `version.json`), so those fields say `1.0.0` whatever the release. To identify a deployed
web build, use the image tag the console shows; for a desktop or Android artifact, the commit or workflow run it
was built from.

## Releasing

Before cutting the release, finalize [CHANGELOG.md](./CHANGELOG.md) on `develop` through a normal `feature/` or
`fix/` pull request, since the release branch can carry no commits of its own: rename `## [Unreleased]` to
`## [1.4.0] - <yyyy-mm-dd>` above a fresh, empty `## [Unreleased]`, and update the compare links at the bottom.

1. `git switch develop && git pull && git switch -c release/1.4.0 && git push -u origin release/1.4.0`
   — Jenkins deploys the branch to **homologation**.
2. Open a pull request `release/1.4.0 → main`.
3. When every GitHub check on the pull request passes, Jenkins deploys to **production**. On
   success it sets the `deploy/production` status, merges the pull request with a merge commit,
   creates the tag and GitHub release `v1.4.0`, and deletes the release branch.
4. If the production deploy fails, Jenkins rolls back to the previous image and the pull request
   stays open. Fix on `develop`, then cut a new release.

The GitHub release's notes are generated from the pull requests merged since the previous tag;
CHANGELOG.md is the curated record.

Follow a release in the **yggdrasil console** (`https://yggdrasil.<domain>`, or the Android app).
The system card shows this application's version, commit, deploy time and health in each
environment.

The repository owner can bypass these rules. That is for emergencies, not for routine work.

## Where this is deployed from

Deployment is managed by [yggdrasil](https://github.com/artur-rios/yggdrasil). This repository is
the application `heimdall-ui` in its `catalog.yaml`, which is what gives it:
- its Jenkins deploy job
- its GitHub rulesets and required checks (the catalog's `checks`)
- its health probe (`/healthz`) and its place in the console

It exposes no metrics, so the catalog gives it no Prometheus scrape target.

If a required check is renamed or added here, update the catalog entry, then run
`python github/rulesets.py heimdall-ui` in yggdrasil.
