#!/bin/bash

# Sign ZIP file with Sparkle EdDSA signature
# Usage: ./sign_sparkle_update.sh <zip_path> <private_key_secret>

set -euo pipefail

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps+=("tar")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Missing required dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep" >&2
        done
        echo "" >&2
        echo "Install missing dependencies with your package manager" >&2
        return 1
    fi
    
    return 0
}

# Function to download Sparkle tools
download_sparkle_tools() {
    # Pinned version and checksum, so a replaced download can't sign our updates.
    local sparkle_version="2.8.0"
    local sparkle_sha256="fd5681ee92bf238aaac2d08214ceaf0cc8976e452d7f882d80bac1e61581f3b1"
    local sparkle_url="https://github.com/sparkle-project/Sparkle/releases/download/${sparkle_version}/Sparkle-${sparkle_version}.tar.xz"
    local archive
    archive=$(mktemp)

    echo "🔽 Downloading Sparkle tools from: $sparkle_url" >&2
    if ! curl -fsSL "$sparkle_url" -o "$archive"; then
        echo "❌ Failed to download Sparkle tools" >&2
        return 1
    fi
    if ! echo "${sparkle_sha256}  ${archive}" | shasum -a 256 -c - >/dev/null; then
        echo "❌ Sparkle tools checksum mismatch, refusing to use them" >&2
        return 1
    fi
    if ! tar -xJf "$archive" bin/sign_update; then
        echo "❌ Failed to extract sign_update" >&2
        return 1
    fi
    
    if [ ! -x "./bin/sign_update" ]; then
        echo "❌ sign_update binary not found or not executable" >&2
        return 1
    fi
    
    echo "✅ Sparkle tools downloaded and extracted" >&2
    return 0
}

# Function to sign the ZIP file
sign_zip_file() {
    local zip_path="$1"
    local private_key_secret="$2"
    
    # Verify ZIP file exists
    if [ ! -f "$zip_path" ]; then
        echo "❌ ZIP file not found at: $zip_path" >&2
        return 1
    fi
    
    echo "✅ ZIP file found: $zip_path ($(stat -f%z "$zip_path") bytes)" >&2
    
    # Check if private key secret is provided
    if [ -z "$private_key_secret" ]; then
        echo "❌ Private key secret is not provided" >&2
        return 1
    fi
    
    # Create secure temporary file for private key
    local private_key_file
    private_key_file=$(mktemp)
    trap "rm -f '$private_key_file'" EXIT
    
    # Write private key to secure temp file
    printf '%s' "$private_key_secret" | tr -d '\r\n' > "$private_key_file"
    chmod 600 "$private_key_file"
    
    # Verify private key file was created
    if [ ! -f "$private_key_file" ] || [ ! -s "$private_key_file" ]; then
        echo "❌ Private key file creation failed" >&2
        return 1
    fi
    echo "✅ Private key file created securely" >&2
    
    # Verify sign_update binary
    if [ ! -x "./bin/sign_update" ]; then
        echo "❌ sign_update binary not found or not executable" >&2
        return 1
    fi
    echo "✅ sign_update binary found" >&2
    
    # Sign the ZIP file with error handling
    echo "🔐 Signing ZIP file..." >&2
    local signature_output
    if signature_output=$(./bin/sign_update "$zip_path" -f "$private_key_file" 2>&1); then
        # Extract just the signature value from the output
        # The output format is: sparkle:edSignature="SIGNATURE_VALUE" length="SIZE"
        local signature_value
        signature_value=$(echo "$signature_output" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
        
        if [ -z "$signature_value" ]; then
            echo "❌ Failed to extract signature from output" >&2
            echo "Full output: $signature_output" >&2
            return 1
        fi
        
        echo "✅ Sparkle update signed successfully" >&2
        echo "Signature: $signature_value" >&2
        echo "Full output: $signature_output" >&2
        
        # Output signature to stdout for capture
        echo "$signature_value"
        return 0
    else
        echo "❌ Sparkle signing failed with error:" >&2
        echo "$signature_output" >&2
        return 1
    fi
    
    # Private key cleanup handled by trap
}

# Validate arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <zip_path> <private_key_secret>"
    echo ""
    echo "Parameters:"
    echo "  zip_path           - Path to ZIP file to sign"
    echo "  private_key_secret - Sparkle private key (EdDSA)"
    echo ""
    echo "Output:"
    echo "  Prints the Sparkle signature to stdout"
    echo "  Logs progress and errors to stderr"
    exit 1
fi

ZIP_PATH="$1"
PRIVATE_KEY_SECRET="$2"

# Validate inputs
if [ -z "$ZIP_PATH" ] || [ -z "$PRIVATE_KEY_SECRET" ]; then
    echo "❌ All parameters are required and cannot be empty" >&2
    exit 1
fi

# Check dependencies early
if ! check_dependencies; then
    exit 1
fi

echo "🚀 Starting Sparkle update signing process..." >&2
echo "  ZIP file: $ZIP_PATH" >&2

# Download Sparkle tools if not already present
if [ ! -x "./bin/sign_update" ]; then
    if ! download_sparkle_tools; then
        exit 1
    fi
fi

# Sign the ZIP file and output signature
if ! sign_zip_file "$ZIP_PATH" "$PRIVATE_KEY_SECRET"; then
    exit 1
fi

echo "✅ Sparkle signing process completed successfully" >&2