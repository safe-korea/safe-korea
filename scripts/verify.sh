#!/bin/sh
set -eu
# Use the local SDK without modifying global PATH/configuration.
cd "$(dirname "$0")/.."
.tools/flutter/bin/dart format --output=none --set-exit-if-changed lib test integration_test
.tools/flutter/bin/flutter analyze --no-pub
.tools/flutter/bin/flutter test --no-pub
python3 -m unittest discover -s scripts -p 'test_*.py' -v
