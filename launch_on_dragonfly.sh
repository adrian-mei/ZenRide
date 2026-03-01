#!/bin/bash

# Configuration
DEVICE_ID="00008110-00062CE034A0A01E"
SCHEME="FashodaMap"
PROJECT="FashodaMap.xcodeproj"
BUNDLE_ID="com.adrian.FashodaMap"

echo "🚀 Preparing to launch $SCHEME on DragonFly ($DEVICE_ID)..."

# 1. Regenerate project
echo "⚙️  Regenerating project..."
xcodegen generate

# 2. Build for device
echo "🏗️  Building for DragonFly..."
# Note: We use -allowProvisioningUpdates to handle signing if possible
xcodebuild -project "$PROJECT" \
           -scheme "$SCHEME" \
           -destination "id=$DEVICE_ID" \
           -allowProvisioningUpdates \
           build

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

# 3. Find the built app path
# Usually in build/Build/Products/Debug-iphoneos/FashodaMap.app
# But xcodebuild might put it in DerivedData. 
# We'll try to locate it.
APP_PATH=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "id=$DEVICE_ID" -showBuildSettings | grep -m 1 "CODESIGNING_FOLDER_PATH" | awk '{print $3}')

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Could not find the built .app folder."
    exit 1
fi

echo "📦 Found app at: $APP_PATH"

# 4. Install on device
echo "📲 Installing on DragonFly..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Installation failed."
    exit 1
fi

# 5. Launch app
echo "✨ Launching $BUNDLE_ID..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "✅ Success!"
