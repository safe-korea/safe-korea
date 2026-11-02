#!/bin/sh
# Restore the interactive app, using the ignored local map key when available.
set -eu
cd "$(dirname "$0")/.."
app_device="${1:?Usage: scripts/run_app.sh DEVICE_ID [flutter run options]}"
shift
if [ -f config/kakao.local.json ]; then
  set -- --dart-define-from-file=config/kakao.local.json "$@"
fi
app_jdk=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
if [ -z "${JAVA_HOME:-}" ] && [ -d "$app_jdk" ]; then
  export JAVA_HOME="$app_jdk"
fi
export BYPASS_PERMISSION_LOCATION_ALWAYS=1
exec .tools/flutter/bin/flutter run --target=lib/main.dart --no-resident \
  -d "$app_device" "$@"
