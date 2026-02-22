# ZenRide

ZenRide is a SwiftUI-based iOS application that simulates a turn-by-turn navigation driving experience with speed camera alerts and Apple Maps-style routing overlays.

## Features
- **3D Navigation Routing**: Authentic MapKit rendering with `.aboveRoads` polylines that hug terrain and respect 3D building occlusion.
- **Dynamic Route Trimming**: Real-time trimming of the route trail behind the user using exact segment-based calculations to prevent visual gaps.
- **Classic iOS UI**: Features standard navigation chevrons, rounded ETA bottom panels, and high-visibility speed camera and speed limit signs.
- **Simulation Engine**: Includes an `OwlPolice` service to mock driving the route for testing and demonstrations.
- **Speed Camera Warnings**: Visual and audio alerts when approaching known speed cameras.

## Getting Started

This project relies on [XcodeGen](https://github.com/yonaskolb/XcodeGen) to manage the Xcode project file.

### Prerequisites
- macOS with Xcode 14+ installed.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

### Setup & Build

1. Clone this repository.
2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
3. Open the generated `ZenRide.xcodeproj` or build directly from the command line:
   ```bash
   xcodebuild -project ZenRide.xcodeproj -scheme ZenRide -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
   ```

## Architecture
- **Views**: 100% SwiftUI interface.
- **Map Rendering**: Built using `UIViewRepresentable` to bridge modern `MKMapView` and MapKit annotations/overlays to SwiftUI.
- **Services**: Heavy logic such as routing (`RoutingService`), simulation (`OwlPolice`), and camera handling (`CameraStore`) are extracted into `ObservableObject` classes.

