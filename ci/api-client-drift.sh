#!/usr/bin/env bash
# The Check API client workflow's drift job (check-api-client.yml): regenerate packages/heimdall_api_client
# from api/heimdall.json and fail if that differs from what is committed. The generation is deterministic
# (generate, build, format), so a clean run reproduces the committed tree exactly.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

flutter pub get
dart run tool/generate_api_client.dart
git diff --exit-code -- packages/heimdall_api_client
