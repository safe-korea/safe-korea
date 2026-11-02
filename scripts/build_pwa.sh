#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# No native map key is included in this web preview.
.tools/flutter/bin/flutter build web --release --target lib/pwa_main.dart --no-web-resources-cdn "$@"
python3 scripts/prepare_app_entry.py
python3 -c "from pathlib import Path; from scripts.prepare_pwa import prepare; prepare(Path('build/web/app')); prepare(Path('build/web'))"

# Public map packs are downloaded only when a facility is saved, never precached.
if [ -d .tools/saved-map-packs/v1 ]; then
  mkdir -p build/web/offline-packs
  cp -R .tools/saved-map-packs/v1/. build/web/offline-packs/
fi
