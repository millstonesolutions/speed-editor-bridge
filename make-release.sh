#!/bin/bash
# Build the app and package it as a zip in dist/ for distribution.
set -euo pipefail
cd "$(dirname "$0")"
./make-app.sh release
VERSION="$(cat VERSION)"
mkdir -p dist
ZIP="dist/Speed-Editor-Bridge-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/Speed Editor Bridge.app" "$ZIP"
echo "Packaged $ZIP ($(du -h "$ZIP" | cut -f1))"
