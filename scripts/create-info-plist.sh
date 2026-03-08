#!/bin/bash

# Extract version from AppVersion.swift
VERSION=$(grep 'static let current' Sources/CiteBar/AppVersion.swift | cut -d'"' -f2)
BUILD_VERSION=$(grep 'static let build' Sources/CiteBar/AppVersion.swift | cut -d'"' -f2)
SPARKLE_PUBLIC_ED_KEY_VALUE="${SPARKLE_PUBLIC_ED_KEY:-}"

# Optional fallback file for local release builds
if [ -z "$SPARKLE_PUBLIC_ED_KEY_VALUE" ] && [ -f ".sparkle/SUPublicEDKey.txt" ]; then
    SPARKLE_PUBLIC_ED_KEY_VALUE=$(tr -d '[:space:]' < ".sparkle/SUPublicEDKey.txt")
fi

SUPUBLIC_ED_KEY_XML=""
if [ -n "$SPARKLE_PUBLIC_ED_KEY_VALUE" ]; then
    SUPUBLIC_ED_KEY_XML="    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_ED_KEY_VALUE</string>"
else
    echo "⚠️  Warning: SUPublicEDKey is not set. Sparkle update signature verification will fail."
fi

cat > "$1" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>CiteBar</string>
    <key>CFBundleExecutable</key>
    <string>CiteBar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.png</string>
    <key>CFBundleIdentifier</key>
    <string>com.hichipli.citebar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CiteBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 CiteBar. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>scholar.google.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.0</string>
            </dict>
        </dict>
    </dict>
    <key>SUFeedURL</key>
    <string>https://github.com/hichipli/CiteBar/releases/latest/download/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUScheduledCheckInterval</key>
    <integer>86400</integer>
$SUPUBLIC_ED_KEY_XML
</dict>
</plist>
EOF
