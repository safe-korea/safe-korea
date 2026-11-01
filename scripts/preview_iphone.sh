#!/bin/sh
# Capture the preview, then restore the interactive app even if tests fail.
set -eu
cd "$(dirname "$0")/.."
preview_device="${1:-E3A83EF7-8FD6-4656-AE84-EFA2E3136351}"
preview_status=0
BYPASS_PERMISSION_LOCATION_ALWAYS=1 .tools/flutter/bin/flutter drive \
  --driver=test_driver/iphone_preview.dart \
  --target=integration_test/iphone_preview_test.dart \
  -d "$preview_device" --keep-app-running || preview_status=$?
./scripts/run_app.sh "$preview_device"
exit "$preview_status"
