#!/usr/bin/env bash
# Merges the strings the last Xcode build found in code into Annotate/Localizable.xcstrings.
# xcodebuild on the command line emits .stringsdata but, unlike the Xcode IDE, never writes
# them back to the catalog. Run after an xcodebuild build that used the same derived data.
#
#   scripts/localization/sync_strings.sh [derived-data-path]   # default: build/dd
set -euo pipefail

cd "$(dirname "$0")/../.."

derived_data=${1:-build/dd}
args=()
while IFS= read -r file; do
	args+=(--stringsdata "$file")
done < <(find "$derived_data/Build/Intermediates.noindex/Annotate.build" -name '*.stringsdata')

if [ ${#args[@]} -eq 0 ]; then
	echo "error: no .stringsdata under $derived_data. Build with xcodebuild first." >&2
	exit 1
fi
xcrun xcstringstool sync Annotate/Localizable.xcstrings "${args[@]}"
