#!/bin/bash
set -e

echo "🧹 Cleaning Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ZenMap-*

echo "⚙️ Regenerating project..."
xcodegen generate

echo "🔨 Building project for iPhone 17 Pro..."
xcodebuild -project ZenMap.xcodeproj -scheme ZenMap -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

echo "📱 Booting Simulator..."
xcrun simctl boot "iPhone 17 Pro" || true

echo "🚀 Installing and Launching App..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ZenMap-*/Build/Products/Debug-iphonesimulator -name "ZenMap.app" | head -n 1)
xcrun simctl install "iPhone 17 Pro" "$APP_PATH"
xcrun simctl launch "iPhone 17 Pro" com.adrian.ZenMap

echo "✅ Done!"
