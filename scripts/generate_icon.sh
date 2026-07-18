#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv-icon 2>/dev/null || true
# shellcheck disable=SC1091
source .venv-icon/bin/activate
pip install -q Pillow
python3 scripts/generate_icon.py
dart run flutter_launcher_icons
