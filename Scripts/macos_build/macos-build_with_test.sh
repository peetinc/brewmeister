#!/bin/bash
# brewmeister macOS Build Script
# Version: 2.0.0
# Builds, signs, and notarizes brewmeister with optional execution
#
# Features:
# - Build brewmeister using Swift Package Manager
# - Optional code signing and notarization
# - Execute brewmeister setupmeister --force after build
#
# Usage:
#   sudo -E ./Scripts/macos_build/macos-build_with_test.sh
#   sudo -E ./Scripts/macos_build/macos-build_with_test.sh --bm-exec

set -e  # Exit on error

# Get the repository root directory
# Script is in Scripts/macos_build/, repo is 2 levels up
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd "$REPO_DIR"

#==============================================================================
# DEFAULT CONFIGURATION
#==============================================================================

ARCH="universal"                    # Architecture: arm64, x86_64, or universal
BUILD_CONFIG="release"              # Build configuration: debug or release
SKIP_BUILD="no"                     # Skip build step (use existing binary)
SKIP_SIGN="no"                      # Skip signing step
SKIP_NOTARY="no"                    # Skip notarization step
SKIP_GIT_PULL="yes"                 # Skip git pull before building
BM_EXEC="no"                        # Execute brewmeister setupmeister --force after build
VERBOSE="no"                        # Enable verbose output

#==============================================================================
# PARSE COMMAND LINE ARGUMENTS
#==============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --debug)
            BUILD_CONFIG="debug"
            shift
            ;;
        --skip-build)
            SKIP_BUILD="yes"
            shift
            ;;
        --skip-sign)
            SKIP_SIGN="yes"
            shift
            ;;
        --skip-notary)
            SKIP_NOTARY="yes"
            shift
            ;;
        --git-pull)
            SKIP_GIT_PULL="no"
            shift
            ;;
        --bm-exec)
            BM_EXEC="yes"
            shift
            ;;
        --verbose)
            VERBOSE="yes"
            shift
            ;;
        --help)
            echo "Usage: sudo [-E] $0 [OPTIONS]"
            echo ""
            echo "brewmeister Build Script - Build, sign, and optionally execute brewmeister"
            echo ""
            echo "Note: Use 'sudo -E' when signing or notarizing to preserve environment variables:"
            echo "      - MACOS_SIGN_CERT (for code signing)"
            echo "      The -E flag preserves your user environment when running as root."
            echo ""
            echo "Build Options:"
            echo "  --arch <arm64|x86_64|universal> Architecture to build (default: universal)"
            echo "                                    arm64      = Apple Silicon ARM64"
            echo "                                    x86_64     = Intel x86_64"
            echo "                                    universal  = Universal binary (ARM64 + Intel)"
            echo "  --debug                         Build debug configuration (default: release)"
            echo "  --skip-build                    Skip build step, use existing binary"
            echo "  --skip-sign                     Skip signing step"
            echo "  --skip-notary                   Skip notarization step"
            echo "  --git-pull                      Pull latest changes before building"
            echo ""
            echo "Execution Options:"
            echo "  --bm-exec                       Execute 'brewmeister setupmeister --force' after build"
            echo ""
            echo "Output Options:"
            echo "  --verbose                       Enable verbose output for all steps"
            echo ""
            echo "Examples:"
            echo "  # Build, sign, and notarize (requires MACOS_SIGN_CERT and sudo -E)"
            echo "  export MACOS_SIGN_CERT=\"Developer ID Application: Your Name (TEAMID)\""
            echo "  sudo -E $0"
            echo ""
            echo "  # Build and execute setupmeister"
            echo "  sudo -E $0 --bm-exec"
            echo ""
            echo "  # Build debug version without signing"
            echo "  sudo $0 --debug --skip-sign --skip-notary"
            echo ""
            echo "  # Use existing binary and run setupmeister"
            echo "  sudo $0 --skip-build --bm-exec"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

#==============================================================================
# AUTOMATIC SKIP LOGIC
#==============================================================================

# Can't notarize unsigned binaries - automatically skip notarization if signing is skipped
if [ "$SKIP_SIGN" = "yes" ]; then
    SKIP_NOTARY="yes"
fi

#==============================================================================
# VALIDATE CONFIGURATION
#==============================================================================

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Validate ARCH
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" && "$ARCH" != "universal" ]]; then
    echo "Error: Invalid ARCH '$ARCH'. Must be arm64, x86_64, or universal"
    exit 1
fi

# Validate signing certificate if signing is enabled
if [ "$SKIP_SIGN" = "no" ]; then
    if [ -z "$MACOS_SIGN_CERT" ]; then
        echo "Error: MACOS_SIGN_CERT environment variable not set"
        echo ""
        echo "Signing is enabled (SKIP_SIGN=no) but no certificate is configured."
        echo ""
        echo "Solutions:"
        echo "  1. Set the certificate and run with sudo -E:"
        echo "     export MACOS_SIGN_CERT=\"Developer ID Application: Your Name (TEAMID)\""
        echo "     sudo -E $0"
        echo ""
        echo "     Note: The -E flag preserves your environment variables when using sudo."
        echo "           Without -E, sudo creates a new environment without MACOS_SIGN_CERT."
        echo ""
        echo "  2. Set the certificate in the sudo command:"
        echo "     sudo MACOS_SIGN_CERT=\"Developer ID Application: ...\" $0"
        echo ""
        echo "  3. Skip signing with --skip-sign flag:"
        echo "     sudo $0 --skip-sign"
        echo ""
        echo "To list available certificates:"
        echo "  security find-identity -v -p codesigning"
        exit 1
    fi

    # Verify the certificate exists in keychain
    if ! security find-identity -v -p codesigning | grep -q "$MACOS_SIGN_CERT"; then
        echo "Error: Certificate not found in keychain"
        echo ""
        echo "Certificate specified: $MACOS_SIGN_CERT"
        echo ""
        echo "Available certificates:"
        security find-identity -v -p codesigning
        echo ""
        echo "Please verify the certificate name matches exactly."
        exit 1
    fi

    echo "✓ Code signing certificate verified: $MACOS_SIGN_CERT"
fi

# Validate notarization keychain profile if notarization is enabled
if [ "$SKIP_NOTARY" = "no" ]; then
    KEYCHAIN_PROFILE="brewmeister-notary"

    if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
        echo "Error: Keychain profile '$KEYCHAIN_PROFILE' not found"
        echo ""
        echo "Notarization is enabled (SKIP_NOTARY=no) but keychain profile is not configured."
        echo ""
        echo "Solutions:"
        echo "  1. Set up the keychain profile once with:"
        echo "     xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" \\"
        echo "       --apple-id \"developer@example.com\" \\"
        echo "       --team-id \"TEAMID\" \\"
        echo "       --password \"xxxx-xxxx-xxxx-xxxx\""
        echo ""
        echo "  2. Skip notarization with --skip-notary flag:"
        echo "     sudo -E $0 --skip-notary"
        echo ""
        echo "     Note: Use sudo -E to preserve your environment variables."
        echo ""
        echo "Get credentials:"
        echo "  - Apple ID: Your Apple Developer account email"
        echo "  - Team ID: https://developer.apple.com/account (Membership section)"
        echo "  - Password: https://appleid.apple.com → Security → App-Specific Passwords"
        exit 1
    fi

    echo "✓ Notarization keychain profile verified: $KEYCHAIN_PROFILE"
fi

# Print blank line after validation checks
if [ "$SKIP_SIGN" = "no" ] || [ "$SKIP_NOTARY" = "no" ]; then
    echo ""
fi

#==============================================================================
# DETERMINE BINARY PATH AND ARCH DESCRIPTION
#==============================================================================

if [ "$ARCH" = "arm64" ]; then
    BINARY_PATH=".build/arm64-apple-macosx/$BUILD_CONFIG/brewmeister"
    ARCH_DESC="Apple Silicon ARM64"
elif [ "$ARCH" = "x86_64" ]; then
    BINARY_PATH=".build/x86_64-apple-macosx/$BUILD_CONFIG/brewmeister"
    ARCH_DESC="Intel x86_64"
elif [ "$ARCH" = "universal" ]; then
    BINARY_PATH=".build/universal/brewmeister-universal-64"
    ARCH_DESC="Universal (ARM64 + Intel)"
fi

#==============================================================================
# CONFIGURATION DISPLAY
#==============================================================================

echo "=========================================="
echo "brewmeister Build Configuration"
echo "=========================================="
echo "Start Time:       $(date '+%Y-%m-%d %H:%M:%S')"
echo "Architecture:     $ARCH_DESC"
echo "Build Config:     $BUILD_CONFIG"
echo "Skip Build:       $SKIP_BUILD"
echo "Skip Sign:        $SKIP_SIGN"
echo "Skip Notary:      $SKIP_NOTARY"
echo "Skip Git Pull:    $SKIP_GIT_PULL"
echo "Execute Setup:    $BM_EXEC"
echo "=========================================="
echo ""

#==============================================================================
# GIT PULL STEP
#==============================================================================

if [ "$SKIP_GIT_PULL" = "no" ]; then
    echo "[0/4] Updating repository..."
    echo "[$(date '+%H:%M:%S')] Git pull started"
    # Run git pull as the actual user (not root)
    sudo -u $SUDO_USER git pull
    echo "[$(date '+%H:%M:%S')] Git pull complete"
    echo "✓ Repository updated"
    echo ""
else
    echo "[0/4] Git pull - SKIPPED"
    echo ""
fi

#==============================================================================
# BUILD STEP
#==============================================================================

if [ "$SKIP_BUILD" = "no" ]; then
    echo "[1/4] Building brewmeister ($ARCH_DESC - $BUILD_CONFIG configuration)..."
    echo "[$(date '+%H:%M:%S')] Build started"

    # Update build version first
    echo "  Updating build version..."
    sudo -u $SUDO_USER ./Scripts/update-build-version.sh

    # Clean build to ensure Info.plist changes are picked up
    echo "  Cleaning build cache..."
    sudo -u $SUDO_USER swift package clean

    # Run build as the actual user (not root)
    if [ "$ARCH" = "universal" ]; then
        echo "  Building for multiple architectures..."

        # Define output paths
        ARM64_OUTPUT=".build/arm64-apple-macosx/$BUILD_CONFIG"
        X86_64_OUTPUT=".build/x86_64-apple-macosx/$BUILD_CONFIG"
        UNIVERSAL_OUTPUT=".build/universal"

        # Create universal output directory
        mkdir -p "$UNIVERSAL_OUTPUT"

        # Build ARM64 (targeting macOS 11.0)
        echo "  Building ARM64 binary (macOS 11.0+)..."
        if [ "$BUILD_CONFIG" = "release" ]; then
            sudo -u $SUDO_USER swift build --disable-sandbox -c release --arch arm64 \
                -Xswiftc "-target" -Xswiftc "arm64-apple-macos11.0"
        else
            sudo -u $SUDO_USER swift build --disable-sandbox --arch arm64 \
                -Xswiftc "-target" -Xswiftc "arm64-apple-macos11.0"
        fi
        echo "  ✓ ARM64 build complete"

        # Build x86_64 (targeting macOS 10.15.4)
        echo "  Building x86_64 binary (macOS 10.15.4+)..."
        if [ "$BUILD_CONFIG" = "release" ]; then
            sudo -u $SUDO_USER swift build --disable-sandbox -c release --arch x86_64 \
                -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.15.4"
        else
            sudo -u $SUDO_USER swift build --disable-sandbox --arch x86_64 \
                -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.15.4"
        fi
        echo "  ✓ x86_64 build complete"

        # Remove adhoc signatures before lipo (required for Swift binaries)
        echo "  Removing adhoc signatures..."
        codesign --remove-signature "$ARM64_OUTPUT/brewmeister" 2>/dev/null || true
        codesign --remove-signature "$X86_64_OUTPUT/brewmeister" 2>/dev/null || true

        # Create universal binary with lipo
        echo "  Creating universal binary with lipo..."
        lipo -create \
            "$ARM64_OUTPUT/brewmeister" \
            "$X86_64_OUTPUT/brewmeister" \
            -output "$UNIVERSAL_OUTPUT/brewmeister-universal-64"
        echo "  ✓ Universal binary created"

        # Verify the universal binary
        echo "  Verifying architectures:"
        lipo -info "$UNIVERSAL_OUTPUT/brewmeister-universal-64" | sed 's/^/    /'

        # Show file sizes
        echo "  Binary sizes:"
        ls -lh "$ARM64_OUTPUT/brewmeister" | awk '{print "    ARM64:     " $5}'
        ls -lh "$X86_64_OUTPUT/brewmeister" | awk '{print "    x86_64:    " $5}'
        ls -lh "$UNIVERSAL_OUTPUT/brewmeister-universal-64" | awk '{print "    Universal: " $5}'
    else
        # Build single architecture
        echo "  Building $ARCH binary..."
        if [ "$BUILD_CONFIG" = "release" ]; then
            sudo -u $SUDO_USER swift build --disable-sandbox -c release --arch "$ARCH"
        else
            sudo -u $SUDO_USER swift build --disable-sandbox --arch "$ARCH"
        fi
        echo "  ✓ $ARCH build complete"

        # Show file size
        if [ -f "$BINARY_PATH" ]; then
            echo "  Binary size:"
            ls -lh "$BINARY_PATH" | awk '{print "    " $5}'
        fi
    fi

    echo "[$(date '+%H:%M:%S')] Build complete"
    echo "✓ Build complete"
    echo ""
else
    echo "[1/4] Build - SKIPPED"

    # If BM_EXEC is set and build is skipped, verify binary exists
    if [ "$BM_EXEC" = "yes" ]; then
        if [ ! -f "$BINARY_PATH" ]; then
            echo ""
            echo "ERROR: Binary not found at $BINARY_PATH"
            echo "Cannot execute setupmeister without a binary."
            echo ""
            echo "Solutions:"
            echo "  1. Remove --skip-build to build the binary"
            echo "  2. Build the binary first"
            echo "  3. Ensure the binary exists at: $BINARY_PATH"
            exit 1
        fi
        echo "  ✓ Binary exists at $BINARY_PATH"
    fi
    echo ""
fi

#==============================================================================
# SIGNING STEP
#==============================================================================

if [ "$SKIP_SIGN" = "no" ]; then
    echo "[2/4] Signing binary..."
    echo "[$(date '+%H:%M:%S')] Signing started"
    # Run signing as the actual user (not root) to access user's keychain
    # Pass the specific binary path to sign and preserve MACOS_SIGN_CERT
    sudo -u $SUDO_USER MACOS_SIGN_CERT="$MACOS_SIGN_CERT" ./Scripts/macos_build/macos-sign.sh "$BINARY_PATH"
    echo "[$(date '+%H:%M:%S')] Signing complete"
    echo "✓ Signing complete"
    echo ""
else
    echo "[2/4] Signing - SKIPPED"
    echo ""
fi

#==============================================================================
# NOTARIZATION STEP
#==============================================================================

if [ "$SKIP_NOTARY" = "no" ]; then
    echo "[3/4] Notarizing binary..."
    echo "[$(date '+%H:%M:%S')] Notarization started"
    # Run notarization as the actual user (not root) to access user's keychain
    # Pass the specific binary path to notarize (with verbose output if enabled)
    if [ "$VERBOSE" = "yes" ]; then
        sudo -u $SUDO_USER ./Scripts/macos_build/macos-notarize.sh "$BINARY_PATH" --verbose
    else
        sudo -u $SUDO_USER ./Scripts/macos_build/macos-notarize.sh "$BINARY_PATH"
    fi
    echo "[$(date '+%H:%M:%S')] Notarization complete"
    echo "✓ Notarization complete"
    echo ""

    #==============================================================================
    # CREATE VERSIONED ZIP FILES (only for universal builds after notarization)
    #==============================================================================

    if [ "$ARCH" = "universal" ]; then
        echo "Creating versioned zip files..."

        # Get version from Info.plist
        VERSION=$(defaults read "$REPO_DIR/Sources/Resources/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "2.0.0")

        # Extract individual architectures from universal binary
        DIST_DIR=".build/dist"
        mkdir -p "$DIST_DIR"

        echo "  Extracting architecture slices..."

        # Extract ARM64 slice
        lipo "$BINARY_PATH" -thin arm64 -output "$DIST_DIR/brewmeister-arm-64"
        chmod 755 "$DIST_DIR/brewmeister-arm-64"

        # Extract x86_64 slice
        lipo "$BINARY_PATH" -thin x86_64 -output "$DIST_DIR/brewmeister-x86-64"
        chmod 755 "$DIST_DIR/brewmeister-x86-64"

        # Copy universal binary
        cp "$BINARY_PATH" "$DIST_DIR/brewmeister-universal-64"
        chmod 755 "$DIST_DIR/brewmeister-universal-64"

        echo "  ✓ Architecture slices extracted"

        # Create zip files with version numbers
        echo "  Creating zip files..."
        cd "$DIST_DIR"

        zip -q "brewmeister-arm-64-${VERSION}.zip" brewmeister-arm-64
        zip -q "brewmeister-x86-64-${VERSION}.zip" brewmeister-x86-64
        zip -q "brewmeister-universal-64-${VERSION}.zip" brewmeister-universal-64

        cd "$REPO_DIR"

        echo "  ✓ Zip files created in $DIST_DIR:"
        ls -lh "$DIST_DIR"/*.zip | awk '{print "    " $9 "  (" $5 ")"}'
        echo ""
    fi
else
    echo "[3/4] Notarization - SKIPPED"
    echo ""
fi

#==============================================================================
# BREWMEISTER EXECUTION
#==============================================================================

if [ "$BM_EXEC" = "yes" ]; then
    echo "[4/4] Executing brewmeister setupmeister --force..."
    echo "[$(date '+%H:%M:%S')] Execution started"
    echo "  Binary: $BINARY_PATH"
    echo "  Command: setupmeister --force"
    echo ""

    # Execute brewmeister setupmeister --force
    "$BINARY_PATH" setupmeister --force

    echo ""
    echo "[$(date '+%H:%M:%S')] Execution complete"
    echo "✓ brewmeister setupmeister --force executed successfully"
    echo ""
else
    echo "[4/4] brewmeister execution - SKIPPED (use --bm-exec to enable)"
    echo ""
fi

#==============================================================================
# SUMMARY
#==============================================================================

echo "=========================================="
echo "Script Complete!"
echo "=========================================="
echo "Architecture:     $ARCH_DESC"
echo "Build Config:     $BUILD_CONFIG"
echo "Binary:           $BINARY_PATH"

if [ "$BM_EXEC" = "yes" ]; then
    echo "Setup Executed:   yes (setupmeister --force)"
else
    echo "Setup Executed:   no"
fi

echo ""
echo "Binary available at: $BINARY_PATH"

# Show zip files if created
if [ "$ARCH" = "universal" ] && [ "$SKIP_NOTARY" = "no" ] && [ -d ".build/dist" ]; then
    echo ""
    echo "Release zip files:"
    ls -1 .build/dist/*.zip 2>/dev/null | while read zipfile; do
        echo "  $(basename "$zipfile")"
    done
fi

if [ "$BM_EXEC" = "no" ]; then
    echo ""
    echo "To execute setupmeister, run:"
    echo "  sudo $BINARY_PATH setupmeister --force"
    echo ""
    echo "Or rebuild with --bm-exec flag:"
    echo "  sudo -E $0 --bm-exec"
fi

echo ""
echo "=========================================="
echo "End Time:         $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""
echo "Press Enter to open build folder (or any other key to exit)..."

# Wait for user input with 15-second timeout
if read -t 15 -n 1 -s key; then
    # User pressed a key before timeout
    if [ -z "$key" ]; then
        # Enter key was pressed (empty string)
        OUTPUT_DIR="$(cd "$(dirname "$BINARY_PATH")" && pwd)"
        echo ""
        echo "Opening $OUTPUT_DIR..."
        open "$OUTPUT_DIR"
    fi
else
    # Timeout occurred (15 seconds elapsed with no input)
    echo ""
fi
