#!/usr/bin/env bash
# package_tarball.sh — Package the SDDPlab built app into a versioned tarball.
#
# Usage:
#   build/package_tarball.sh [app_dir]
#
# Arguments:
#   app_dir   Path to the built app directory (default: build/SDDPLabApp)
#
# Output:
#   build/sddp-lab-v{version}-{os}-{arch}.tar.gz
#
# Prerequisites:
#   Run 'julia --project=build build/build_app.jl' first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="${1:-$SCRIPT_DIR/SDDPLabApp}"

if [ ! -d "$APP_DIR" ]; then
    echo "Error: App directory not found: $APP_DIR" >&2
    echo "Run 'julia --project=build build/build_app.jl' first." >&2
    exit 1
fi

VERSION=$(grep '^version' "$PROJECT_DIR/Project.toml" | sed 's/.*"\(.*\)"/\1/')

if [ -z "$VERSION" ]; then
    echo "Error: Could not determine version from $PROJECT_DIR/Project.toml" >&2
    exit 1
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

TARBALL="$SCRIPT_DIR/sddp-lab-v${VERSION}-${OS}-${ARCH}.tar.gz"

echo "Packaging: $(basename "$APP_DIR") -> $(basename "$TARBALL")"

tar -czf "$TARBALL" -C "$(dirname "$APP_DIR")" "$(basename "$APP_DIR")"

echo "Created: $TARBALL"
echo "Size: $(du -h "$TARBALL" | cut -f1)"
