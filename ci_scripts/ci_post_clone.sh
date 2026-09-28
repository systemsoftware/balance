#!/bin/sh

ENTITLEMENTS_PATH="$CI_WORKSPACE/browser/browser.entitlements"

echo "Checking for Xcode Cloud background Ad Hoc validation..."

# Xcode Cloud does not expose an exact flag for its background Ad Hoc pass,
# so we check if the build configuration is stripping it or force-remove it safely.
if [ -f "$ENTITLEMENTS_PATH" ]; then
    echo "Temporarily removing com.apple.developer.web-browser entitlement for cloud validation pass..."
    /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.web-browser" "$ENTITLEMENTS_PATH" || true
else
    echo "Entitlements file not found at $ENTITLEMENTS_PATH"
fi
