#!/usr/bin/env bash
# The release files (`release.build` in yggdrasil.yml), run on the release agent from the checkout of the
# release's tag. It ports the Linux jobs of the old build.yml (web, linux, android); the Windows build is
# the release-windows.yml workflow. Everything lands in dist/, one file per platform, named with the version:
#
#   dist/heimdall-ui-web-<version>.zip
#   dist/heimdall-ui-linux-x64-<version>.tar.gz
#   dist/heimdall-ui-android-<version>.apk
#
# RELEASE_VERSION is the tag without its v (set by the pipeline; "dev" when this is run by hand).
# The Android signing values come from the Jenkins credentials of releaseCredentials:
#   KEYSTORE_BASE64                 the keystore, base64-encoded (it was HEIMDALL_UI_KEYSTORE_BASE64)
#   HEIMDALL_UI_KEYSTORE_PASSWORD   its password
#   HEIMDALL_UI_KEY_ALIAS           the key's alias
#   HEIMDALL_UI_KEY_PASSWORD        the key's password (defaults to the keystore's)
# Without KEYSTORE_BASE64 the APK is signed with the debug key and named -debug-signed, as the workflow did,
# so a build with no credentials (by hand, a fork) still works. Do not distribute that file.
#
# The Linux build needs desktop packages the Flutter image does not carry; they are installed with apt when
# this runs as root, as it does on the release agent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
root=$PWD

# shellcheck source=ci/flutter-env.sh
source ci/flutter-env.sh

version=${RELEASE_VERSION:-dev}
rm -rf dist
mkdir dist

flutter pub get

# ---- Web ----
# No API base URL is supplied on purpose: the default keeps a deployment address out of a public build log.
flutter build web --release
(cd build/web && zip -qr "$root/dist/heimdall-ui-web-$version.zip" .)

# ---- Linux ----
# libsecret-1-dev is not part of Flutter's generic desktop list: it is flutter_secure_storage_linux's own
# dependency, and the session token lives in libsecret, so it is not optional here.
packages=(clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libsecret-1-dev)
missing=()
for package in "${packages[@]}"; do
  dpkg -s "$package" >/dev/null 2>&1 || missing+=("$package")
done
if [ "${#missing[@]}" -gt 0 ]; then
  if [ "$(id -u)" -ne 0 ]; then
    echo "ci/release-build.sh: ${missing[*]} must be installed to build for Linux, and this is not run as root" >&2
    exit 1
  fi
  apt-get update
  apt-get install -y --no-install-recommends "${missing[@]}"
fi
flutter build linux --release
tar -czf "dist/heimdall-ui-linux-x64-$version.tar.gz" -C build/linux/x64/release/bundle .

# ---- Android ----
# Unset credentials are empty strings, which the Gradle build treats as unset: the debug key signs.
suffix=''
if [ -n "${KEYSTORE_BASE64:-}" ]; then
  keystore_dir=$(mktemp -d)
  trap 'rm -rf "$keystore_dir"' EXIT
  printf '%s' "$KEYSTORE_BASE64" | base64 -d >"$keystore_dir/heimdall-ui-release.jks"
  export HEIMDALL_UI_KEYSTORE_PATH="$keystore_dir/heimdall-ui-release.jks"
else
  echo "WARNING: no release keystore is set, so the Android APK is signed with the debug key. Do not distribute it." >&2
  suffix='-debug-signed'
fi
unset KEYSTORE_BASE64

flutter build apk --release
apk=build/app/outputs/flutter-apk/app-release.apk

# Flutter grants INTERNET to debug and profile builds only, so a release APK can lose it unnoticed: it
# installs, and then every request fails.
aapt2=$(find "$ANDROID_HOME/build-tools" -name aapt2 | sort -V | tail -n 1)
permissions=$("$aapt2" dump permissions "$apk")
echo "$permissions"
if ! grep -q 'android.permission.INTERNET' <<<"$permissions"; then
  echo "ci/release-build.sh: the release APK does not declare android.permission.INTERNET" >&2
  exit 1
fi
cp "$apk" "dist/heimdall-ui-android-$version$suffix.apk"

ls -l dist
