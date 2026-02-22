# ZenRide

A privacy-focused iOS application designed to help you avoid speed cameras and potential fines while riding.

## Features
- **Live Routing:** Calculates safe routes that actively avoid known speed cameras using the TomTom API.
- **Cost Analysis:** Displays the potential cost of fines if you take a faster route with cameras.
- **Smart Directions:** Large, clear UI designed for quick glances while driving.
- **Simulate Mode:** Test routes and alerts from your couch before you hit the road.
- **Drive Mode:** Uses your real-time GPS location to track your progress and alert you to cameras.

## Setup

1. Open the project in Xcode:
   ```bash
   open ZenRide.xcodeproj
   ```
2. Select your development team in the **Signing & Capabilities** tab.
3. Select your device and press **Run**.

## Note on Debugging Performance
If you see the warning: `warning: libobjc.A.dylib is being read from process memory`, it means Xcode hasn't finished preparing your device for development yet.

1. This usually happens the first time you connect a device with a new iOS version to Xcode.
2. It's safe to ignore for testing the app's functionality. The app will run fine, but breakpoints and variable inspection in Xcode might be slower.
3. **To fix it permanently:** Leave the device plugged in and open the **Window -> Devices and Simulators** menu in Xcode. Wait for the yellow progress bar ("Preparing device for development...") to complete.
