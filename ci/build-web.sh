#!/usr/bin/env bash
# The CI workflow's build-web job (ci.yml): a change that breaks the web build (a new plugin, a
# conditional-import slip) is seen on the pull request, not after the release merge deploys production.
# No API base URL is supplied on purpose: the default keeps a deployment address out of a public build log.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
flutter build web --release
