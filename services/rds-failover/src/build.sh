#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build.sh [version]
# Example:
#   ./build.sh 1.0.0
#
# Output:
#   dist/rds-failover-<version>.zip

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/src"
DIST="$HERE/dist"
NAME="rds-failover"
VERSION="${1:-$(date -u +%Y%m%d%H%M%S)}"
ZIP="$DIST/${NAME}-${VERSION}.zip"

mkdir -p "$DIST"

# If you add requirements later, uncomment and build into a temp dir:
# TMPDIR="$(mktemp -d)"
# pip install -r "$HERE/requirements.txt" -t "$TMPDIR"
# (cd "$TMPDIR" && zip -r9 "$ZIP" .)
# rm -rf "$TMPDIR"

# For now, just zip the source
(cd "$SRC" && zip -r9 "$ZIP" .)

echo "Built: $ZIP"
