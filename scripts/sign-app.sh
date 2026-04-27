#!/bin/bash
set -euo pipefail

APP_BUNDLE="${1:-dist/CiteBar.app}"
PRODUCT_NAME="${2:-CiteBar}"
SIGN_IDENTITY="${SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:-"-"}}"
ENTITLEMENTS_FILE="${ENTITLEMENTS_FILE:-CiteBar.entitlements}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: app bundle not found: $APP_BUNDLE"
    exit 1
fi

sign_path() {
    local path="$1"
    local use_entitlements="${2:-false}"

    if [ ! -e "$path" ]; then
        return 0
    fi

    if [ "$SIGN_IDENTITY" = "-" ]; then
        if [ "$use_entitlements" = "true" ] && [ -f "$ENTITLEMENTS_FILE" ]; then
            codesign --force --sign - --entitlements "$ENTITLEMENTS_FILE" "$path"
        else
            codesign --force --sign - "$path"
        fi
    else
        if [ "$use_entitlements" = "true" ] && [ -f "$ENTITLEMENTS_FILE" ]; then
            codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_FILE" "$path"
        else
            codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$path"
        fi
    fi
}

verify_path() {
    local path="$1"

    if [ ! -e "$path" ]; then
        return 0
    fi

    codesign --verify --strict --verbose=4 "$path"
}

echo "Signing $APP_BUNDLE"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "Using ad-hoc signing identity"
else
    echo "Using signing identity: $SIGN_IDENTITY"
fi

xattr -cr "$APP_BUNDLE"

SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    sign_path "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
    sign_path "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
    sign_path "$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"
    sign_path "$SPARKLE_FRAMEWORK/Versions/B/Updater.app"
    sign_path "$SPARKLE_FRAMEWORK"
    sign_path "$SPARKLE_FRAMEWORK/Versions/B/Sparkle"
fi

sign_path "$APP_BUNDLE" true
sign_path "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME" true

verify_path "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    verify_path "$SPARKLE_FRAMEWORK/Versions/B/Sparkle"
fi
codesign --verify --strict --deep --verbose=2 "$APP_BUNDLE"
codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | grep -E "Authority=|TeamIdentifier=|Runtime|Timestamp" || true
