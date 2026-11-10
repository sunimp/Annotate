#!/bin/bash

# Generate and insert new appcast entry with GitHub release notes
# Usage: ./generate_appcast_entry.sh <tag_name> <version_number> <sparkle_version> <signature> <zip_size> <download_url> [appcast_file]

set -euo pipefail

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("gh (GitHub CLI)")
    fi
    
    if ! command -v pandoc >/dev/null 2>&1; then
        missing_deps+=("pandoc")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Missing required dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep" >&2
        done
        echo "" >&2
        echo "Install missing dependencies:" >&2
        echo "  brew install gh pandoc" >&2
        return 1
    fi
    
    return 0
}

# Function to fetch GitHub release notes
fetch_github_release_notes() {
    local tag_name="$1"
    
    echo "🔍 Fetching GitHub release notes for $tag_name..." >&2
    
    # Determine repository from environment or default
    local repo="${GITHUB_REPOSITORY:-sunimp/Annotate}"
    
    # Use GitHub CLI to fetch release notes with explicit repo context
    # The GITHUB_TOKEN environment variable is automatically used by gh CLI in GitHub Actions
    if gh release view "$tag_name" --repo "$repo" --json body --jq '.body' 2>/dev/null | sed '/^### 安装提示/,$d'; then
        return 0
    else
        echo "⚠️  Failed to fetch GitHub release notes for $tag_name" >&2
        echo "🔍 Debug: Checking authentication and release existence..." >&2
        echo "🔍 Repository: $repo" >&2
        gh auth status >&2 || echo "❌ GitHub CLI not authenticated" >&2
        gh release list --repo "$repo" --limit 5 >&2 || echo "❌ Cannot access releases" >&2
        return 1
    fi
}

# Function to convert markdown to HTML using pandoc
convert_markdown_to_html() {
    local markdown_text="$1"
    
    # If input is empty, return empty
    if [ -z "$markdown_text" ]; then
        return 0
    fi
    
    # Use pandoc with GitHub Flavored Markdown support
    echo "$markdown_text" | pandoc -f gfm -t html --wrap=none
}

# Function to format GitHub release notes as HTML
format_release_notes_html() {
    local tag_name="$1"
    local release_notes="$2"
    
    echo "<h1>Annotate $tag_name</h1>"
    echo ""
    
    if [ -n "$release_notes" ]; then
        # Convert to HTML first, then filter out New Contributors section and Full Changelog
        convert_markdown_to_html "$release_notes" | \
            sed '/New Contributors/,/<\/ul>/d' | \
            grep -v "Full Changelog"
        echo ""
    fi
    
    # Always show the full changelog link
    echo "<p>See the <a href=\"https://github.com/${GITHUB_REPOSITORY:-sunimp/Annotate}/releases/tag/$tag_name\">full changelog</a> for details.</p>"
}

if [ $# -lt 6 ] || [ $# -gt 7 ]; then
    echo "Usage: $0 <tag_name> <version_number> <sparkle_version> <signature> <zip_size> <download_url> [appcast_file]"
    echo ""
    echo "Parameters:"
    echo "  tag_name        - Git tag (e.g., v1.0.7-test)"
    echo "  version_number  - Version string (e.g., 1.0.7-test)"
    echo "  sparkle_version - Sparkle version (e.g., 107test)"
    echo "  signature       - Sparkle EdDSA signature"
    echo "  zip_size        - ZIP file size in bytes"
    echo "  download_url    - Full download URL"
    echo "  appcast_file    - Optional: appcast file path (default: appcast.xml)"
    exit 1
fi

# Check dependencies early
if ! check_dependencies; then
    exit 1
fi

TAG_NAME="$1"
VERSION_NUMBER="$2"
SPARKLE_VERSION="$3"
SIGNATURE="$4"
ZIP_SIZE="$5"
DOWNLOAD_URL="$6"
APPCAST_FILE="${7:-appcast.xml}"

# Validate inputs
if [ ! -f "$APPCAST_FILE" ]; then
    echo "❌ Appcast file not found: $APPCAST_FILE"
    exit 1
fi

if [ -z "$TAG_NAME" ] || [ -z "$VERSION_NUMBER" ] || [ -z "$SPARKLE_VERSION" ] || [ -z "$SIGNATURE" ] || [ -z "$ZIP_SIZE" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ All parameters are required and cannot be empty"
    exit 1
fi

# Generate publication date
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

echo "📝 Generating appcast entry for $TAG_NAME..."
echo "  Version: $VERSION_NUMBER"
echo "  Sparkle Version: $SPARKLE_VERSION"
echo "  File Size: $ZIP_SIZE bytes"
echo "  Download URL: $DOWNLOAD_URL"

# Fetch GitHub release notes
echo "📋 Fetching GitHub release notes..."
RELEASE_NOTES=""
if RELEASE_NOTES=$(fetch_github_release_notes "$TAG_NAME"); then
    echo "✅ Successfully fetched GitHub release notes"
else
    echo "⚠️  Using fallback description (GitHub API fetch failed)"
fi

# Format the description HTML
DESCRIPTION_HTML=$(format_release_notes_html "$TAG_NAME" "$RELEASE_NOTES")

# Generate new appcast entry
cat > new_entry.xml << EOF
        <item>
            <title>Version $TAG_NAME</title>
            <link>https://github.com/${GITHUB_REPOSITORY:-sunimp/Annotate}/releases/tag/$TAG_NAME</link>
            <description><![CDATA[
$DESCRIPTION_HTML
            ]]></description>
            <pubDate>$PUB_DATE</pubDate>
            <enclosure url="$DOWNLOAD_URL"
                       sparkle:version="$SPARKLE_VERSION"
                       sparkle:shortVersionString="$VERSION_NUMBER"
                       sparkle:edSignature="$SIGNATURE"
                       length="$ZIP_SIZE"
                       type="application/octet-stream" />
        </item>
EOF

echo "📄 Generated entry:"
cat new_entry.xml

# Backup original appcast
cp "$APPCAST_FILE" "${APPCAST_FILE}.backup"

# Insert new entry after channel language tag (or after channel description if no language tag)
echo "📝 Updating $APPCAST_FILE..."
if sed -i.tmp '/^        <language>en<\/language>$/r new_entry.xml' "$APPCAST_FILE" || \
   sed -i.tmp '/^        <description>Annotate App Updates<\/description>$/r new_entry.xml' "$APPCAST_FILE"; then
    rm "${APPCAST_FILE}.tmp" new_entry.xml
    echo "✅ Successfully updated $APPCAST_FILE"
else
    echo "❌ Failed to update $APPCAST_FILE"
    # Restore backup on failure
    mv "${APPCAST_FILE}.backup" "$APPCAST_FILE"
    rm -f new_entry.xml
    exit 1
fi

# Validate the updated XML
if command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$APPCAST_FILE" 2>/dev/null; then
        echo "✅ Updated appcast.xml is valid XML"
        rm "${APPCAST_FILE}.backup"
    else
        echo "❌ Updated appcast.xml is invalid XML, restoring backup"
        mv "${APPCAST_FILE}.backup" "$APPCAST_FILE"
        exit 1
    fi
else
    echo "⚠️  xmllint not available, skipping XML validation"
    rm "${APPCAST_FILE}.backup"
fi

echo "✅ Appcast entry generation completed successfully"