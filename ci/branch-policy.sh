#!/bin/sh
# The part of the old Branch Policy workflow that yggdrasil's common branch policy does not know: a pull
# request from release/x.y.z into main must carry that version in pubspec.yaml, because the footer shows the
# version written in the source (see CONTRIBUTING.md, Versioning). Run as `branchPolicy` in yggdrasil.yml,
# after scripts/branch-policy.sh, with HEAD_REF and BASE_REF set, from the checkout of the pull request's head.
set -eu
cd "$(dirname "$0")/.."

[ "${BASE_REF:-}" = main ] || { echo "'${HEAD_REF:-}' -> '${BASE_REF:-}': nothing more to check."; exit 0; }

version=${HEAD_REF#release/}
pubspec_version=$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' pubspec.yaml)
if [ "$pubspec_version" != "$version" ]; then
  echo "pubspec.yaml says version '$pubspec_version', but this releases $version. Set it, and appVersion in lib/app/app_version.dart, when finalizing the changelog." >&2
  exit 1
fi
echo "pubspec.yaml says $version, as the release does."
