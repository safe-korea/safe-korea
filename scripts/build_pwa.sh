#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# No native map key is included in this web preview.
.tools/flutter/bin/flutter build web --release --target lib/pwa_main.dart --no-web-resources-cdn "$@"
python3 scripts/prepare_pwa.py
