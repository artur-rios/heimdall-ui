#!/usr/bin/env bash
# The CI workflow's analyze-and-test job (ci.yml): formatting, analysis and tests with coverage.
# Run from anywhere; it works from the repository's root. Coverage has no threshold, so it never fails the
# build; coverage/lcov.info is kept with the build (`archive` in yggdrasil.yml).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
