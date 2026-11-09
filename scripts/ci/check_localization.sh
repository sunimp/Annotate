#!/bin/bash
#
#  check_localization.sh
#  Annotate
#
#  Created by Sun on 2026/11/9.
#

# Fail on two localization mistakes LocalizationTests cannot see (rule E in AGENTS.md):
#
#   - String(localized:) outside Annotate/AppLanguage.swift. It ignores the language picked in
#     General settings, so the text stays in the macOS language. Use L10n.string("…").
#   - An L10n.string("literal") whose key is missing from Annotate/Localizable.xcstrings. The
#     command-line build never adds it, so it ships untranslated until someone runs
#     scripts/localization/sync_strings.sh.
#
# Line-based, like check_settings_access.sh. Known limits: keys with \( interpolation are
# skipped (the catalog stores them as %@ / %lld), so are multi-line calls and keys built from
# variables. SwiftUI LocalizedStringKey literals (Text("…")) are not checked.
#
# Usage: ./scripts/ci/check_localization.sh (from the repository root)

set -euo pipefail

CATALOG="Annotate/Localizable.xcstrings"
ALLOWED="Annotate/AppLanguage.swift" # Defines L10n.string on top of String(localized:).

failed=0

raw=$(grep -rnE --include='*.swift' 'String\(localized:' Annotate | grep -v "^$ALLOWED:" |
	grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)
if [ -n "$raw" ]; then
	echo "❌ String(localized:) ignores the in-app language choice. Use L10n.string(\"…\"):" >&2
	echo "$raw" >&2
	failed=1
fi

missing=$(python3 -I - "$CATALOG" <<'EOF'
import json, pathlib, re, sys

keys = set(json.load(open(sys.argv[1]))["strings"])
literal = re.compile(r'L10n\.string\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
escapes = {'\\"': '"', "\\n": "\n", "\\t": "\t", "\\\\": "\\"}
for path in sorted(pathlib.Path("Annotate").rglob("*.swift")):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith("//"):
            continue
        for match in literal.finditer(line):
            key = match.group(1)
            if "\\(" in key:
                continue
            key = re.sub(r'\\["nt\\]', lambda m: escapes[m.group(0)], key)
            if key not in keys:
                print(f"{path}:{number}: {key}")
EOF
)
if [ -n "$missing" ]; then
	echo "❌ L10n.string keys missing from $CATALOG. Build with xcodebuild, run" >&2
	echo "   scripts/localization/sync_strings.sh, and translate every language:" >&2
	echo "$missing" >&2
	failed=1
fi

[ "$failed" -eq 0 ] || exit 1
echo "✅ Every L10n.string literal is in $CATALOG and nothing bypasses L10n"
