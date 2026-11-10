#!/bin/sh
#
#  install.sh
#  Annotate
#
#  Created by Sun on 2026/11/10.
#
# Installs or updates Annotate:
#
#   curl -fsSL https://raw.githubusercontent.com/sunimp/Annotate/main/install.sh | sh
#
# Release builds are ad-hoc signed and not notarized. A browser download gets macOS's quarantine
# flag, which makes Gatekeeper block the first launch. curl doesn't add that flag, so Annotate
# installed this way just opens, with no `xattr` step. Run it again to update.
# Set ANNOTATE_DEST to install somewhere other than /Applications.
set -eu

fail() {
    printf 'annotate: %s\n' "$1" >&2
    exit 1
}

# Everything runs from main, called on the last line, so a half-downloaded script does nothing.
main() {
    [ "$(uname -s)" = Darwin ] || fail "Annotate is a macOS app."
    [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || fail "Annotate needs macOS 14 (Sonoma) or later."

    # Standard (non-admin) accounts can't write to /Applications; use ~/Applications instead.
    dest=${ANNOTATE_DEST:-/Applications}
    if [ -z "${ANNOTATE_DEST:-}" ] && [ ! -w /Applications ]; then
        dest="$HOME/Applications"
    fi
    mkdir -p "$dest"
    [ -w "$dest" ] || fail "can't write to $dest."
    app="$dest/Annotate.app"

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    echo "Downloading Annotate…"
    base=https://github.com/sunimp/Annotate/releases/latest/download
    curl -fsSL "$base/Annotate.zip" -o "$tmp/Annotate.zip"
    curl -fsSL "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt"
    grep ' Annotate\.zip$' "$tmp/SHA256SUMS.txt" > "$tmp/Annotate.zip.sha256" || fail "the checksum file has no entry for Annotate.zip."
    (cd "$tmp" && shasum -a 256 -c Annotate.zip.sha256 >/dev/null 2>&1) || fail "the download didn't match its checksum."
    ditto -x -k "$tmp/Annotate.zip" "$tmp/new"
    [ -d "$tmp/new/Annotate.app" ] || fail "the download didn't contain Annotate.app."

    # Quit only the copy being replaced.
    running="^$app/Contents/MacOS/Annotate\$"
    if pgrep -f "$running" >/dev/null; then
        echo "Quitting Annotate…"
        pkill -f "$running" || true
        i=0
        while pgrep -f "$running" >/dev/null && [ "$i" -lt 50 ]; do
            sleep 0.2
            i=$((i + 1))
        done
    fi

    # Swap: the old copy goes into the temp folder (removed on exit), restored if the move fails.
    [ -e "$app" ] && mv "$app" "$tmp/old.app"
    if ! mv "$tmp/new/Annotate.app" "$app"; then
        [ -e "$tmp/old.app" ] && mv "$tmp/old.app" "$app"
        fail "couldn't move Annotate.app into $dest."
    fi

    version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist" 2>/dev/null || true)
    echo "Installed Annotate ${version:+v$version }to $dest"
    open "$app"
}

main "$@"
