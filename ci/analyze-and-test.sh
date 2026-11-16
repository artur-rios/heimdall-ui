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
# The suite runs as four bundles side by side (tool/test_bundles.dart says why): `flutter test` compiles one entry
# point at a time whatever its concurrency, so one entry point per test file spent most of the step compiling and
# loading 140-odd files in a row. The concurrency is set, not left at half the agent's cores.
dart run tool/test_bundles.dart build/test-bundles 4
flutter test --coverage --concurrency 4 build/test-bundles
