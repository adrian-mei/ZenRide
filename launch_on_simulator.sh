#!/bin/bash
set -e

# Configuration
DEVICE_NAME="iPhone 17 Pro"
SCHEME="ZenMap"
PROJECT="ZenMap.xcodeproj"
BUNDLE_ID="com.adrian.ZenMap"

echo "🚀 Launching $SCHEME on Simulator ($DEVICE_NAME)..."

# 1. Regenerate project
echo "⚙️  Regenerating project..."
xcodegen generate

# 2. Build for simulator
echo "🏗️  Building for Simulator..."
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -derivedDataPath "./DerivedData" \
           -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
           build

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

# 3. Find built app path
APP_PATH=$(find ./DerivedData/Build/Products/Debug-iphonesimulator -name "$SCHEME.app" | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Could not find the built .app folder."
    exit 1
fi

echo "📦 Found app at: $APP_PATH"

# 4. Boot simulator if needed
echo "📱 Preparing Simulator..."
xcrun simctl boot "$DEVICE_NAME" || true
open -a Simulator

# 5. Install and Launch
echo "📲 Installing on $DEVICE_NAME..."
xcrun simctl install "$DEVICE_NAME" "$APP_PATH"

echo "✨ Launching $BUNDLE_ID..."
xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"

echo "✅ Done!"
