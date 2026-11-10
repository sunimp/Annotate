#!/usr/bin/env bash
set -euo pipefail
APP_NAME="Annotate"
PRODUCT_DIR="build/export"
APP_PATH="$PRODUCT_DIR/$APP_NAME.app"

# Use version from environment or default to just app name
if [ -n "${MARKETING_VERSION:-}" ]; then
    DMG_NAME="$APP_NAME-$MARKETING_VERSION.dmg"
else
    DMG_NAME="$APP_NAME.dmg"
fi
DMG_OUT="build/$DMG_NAME"

rm -f "$DMG_OUT"
command -v create-dmg >/dev/null 2>&1 || npm i -g create-dmg 1>&2

# create-dmg exits 2 when only the DMG code signing step fails; the DMG itself is complete.
status=0
create-dmg \
  --overwrite \
  --dmg-title "$APP_NAME" \
  --icon-size 128 \
  "$APP_PATH" \
  "$(dirname "$DMG_OUT")" 1>&2 || status=$?
if [ "$status" -eq 2 ]; then
    echo "warning: DMG created but not code signed" 1>&2
elif [ "$status" -ne 0 ]; then
    exit "$status"
fi

# Find the created DMG file and rename it to our desired name
# create-dmg creates files like "Annotate 1.0.8-test.dmg" but we want "Annotate-1.0.8-test.dmg"
CREATED_DMG=$(find "$(dirname "$DMG_OUT")" -name "$APP_NAME*.dmg" -type f -print -quit)
if [ -n "$CREATED_DMG" ] && [ "$CREATED_DMG" != "$DMG_OUT" ]; then
    echo "Renaming DMG from '$CREATED_DMG' to '$DMG_OUT'" 1>&2
    mv "$CREATED_DMG" "$DMG_OUT" 1>&2
fi

echo "$DMG_OUT"