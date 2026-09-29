# syntax=docker/dockerfile:1
# check=skip=FromPlatformFlagConstDisallowed
#
# Production image for the Flutter web build of Heimdall UI.
#
#   docker build -t heimdall-ui \
#     --build-arg HEIMDALL_API_BASE_URL=https://heimdall-api.example.com .
#
# Every HEIMDALL_* build argument is compiled into main.dart.js and is readable
# by anyone who loads the page. Never pass a secret as a build argument.

# ---------------------------------------------------------------------------
# Build stage: a pinned Flutter SDK compiles the web bundle.
#
# The SDK comes from Flutter's official release archive rather than
# ghcr.io/cirruslabs/flutter, because that image publishes no tag for 3.44.9
# (its newest versioned tag is 3.44.0). The archive is x64-only, and the output
# is platform-independent static files, so this stage always runs as amd64.
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 debian:trixie-slim AS build

# Keep in step with FLUTTER_VERSION in .github/workflows. FLUTTER_SHA256 is the
# archive's checksum from
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json;
# override it together with FLUTTER_VERSION, or pass it empty to skip the check.
ARG FLUTTER_VERSION=3.44.9
ARG FLUTTER_SHA256=a9120fa4a01048bdef438ddc3a2d4b7389662ea98a95db86eeaf10382bc4efcb

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /bin/bash flutter \
 && install -d -o flutter -g flutter /opt/flutter

USER flutter
ENV CI=true \
    FLUTTER_ROOT=/opt/flutter \
    PUB_CACHE=/home/flutter/.pub-cache \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH

RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && if [ -n "$FLUTTER_SHA256" ]; then echo "$FLUTTER_SHA256  /tmp/flutter.tar.xz" | sha256sum -c -; fi \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && flutter config --no-analytics --no-cli-animations \
 && dart --disable-analytics \
 && flutter precache --web \
 && flutter --version

WORKDIR /home/flutter/app

# Dependencies first, so source-only changes reuse the resolved packages.
COPY --chown=flutter:flutter pubspec.yaml pubspec.lock ./
COPY --chown=flutter:flutter packages/heimdall_api_client/pubspec.yaml packages/heimdall_api_client/
RUN flutter pub get --enforce-lockfile

COPY --chown=flutter:flutter . .

# One argument per --dart-define read by lib/core/config/app_config.dart.
#   HEIMDALL_API_BASE_URL      required - the Heimdall API root.
#   HEIMDALL_GOOGLE_CLIENT_ID  optional - empty hides Google Sign-In.
#   HEIMDALL_SCOPE_ID          optional - fallback scope when no calling
#                              application supplies one.
ARG HEIMDALL_API_BASE_URL
ARG HEIMDALL_GOOGLE_CLIENT_ID=
ARG HEIMDALL_SCOPE_ID=

# An empty HEIMDALL_API_BASE_URL would override the app's localhost default
# with "", so a production image refuses to build without one.
# --no-web-resources-cdn bundles CanvasKit and fonts into build/web so the
# running app never fetches from gstatic.com.
RUN test -n "$HEIMDALL_API_BASE_URL" \
      || { echo "HEIMDALL_API_BASE_URL build argument is required" >&2; exit 1; } \
 && flutter build web --release --no-web-resources-cdn \
      --dart-define=HEIMDALL_API_BASE_URL=${HEIMDALL_API_BASE_URL} \
      --dart-define=HEIMDALL_GOOGLE_CLIENT_ID=${HEIMDALL_GOOGLE_CLIENT_ID} \
      --dart-define=HEIMDALL_SCOPE_ID=${HEIMDALL_SCOPE_ID}

# ---------------------------------------------------------------------------
# Runtime stage: static files behind unprivileged nginx on port 8080.
# ---------------------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /home/flutter/app/build/web /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
