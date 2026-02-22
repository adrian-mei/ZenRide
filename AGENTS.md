# Agent Instructions: ZenRide (iOS SwiftUI Project)

Welcome! This document provides instructions for AI coding agents operating within the ZenRide repository. Please adhere strictly to these guidelines to maintain code quality, consistency, and a functional build pipeline.

## 1. Project Overview & Setup

*   **Tech Stack:** ZenRide is an iOS application built entirely with **SwiftUI** and Swift.
*   **Project Management:** It uses `XcodeGen` to manage the Xcode project file. 
*   **Source Control Rules:** The `ZenRide.xcodeproj` directory is typically generated and should not be manually edited.
*   **Adding Files:** If you add new source files, place them inside the `Sources/` directory. If you add assets, place them in `Resources/`. Because `project.yml` includes these entire directories, you usually just need to regenerate the project.

### Core Commands

*   **Regenerate Xcode Project (Run this if you add/remove files or modify project.yml):**
    ```bash
    xcodegen generate
    ```

## 2. Build, Lint, and Test Commands

As an agent, you must verify your work. Use the following `xcodebuild` commands. Note the specific destination device (`iPhone 17 Pro`); adjust if a different simulator is booted, but this is a safe default.

*   **Build the App:**
    ```bash
    xcodebuild -project ZenRide.xcodeproj -scheme ZenRide -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
    ```

*   **Run All Tests:**
    ```bash
    xcodebuild -project ZenRide.xcodeproj -scheme ZenRide -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
    ```

*   **Run a Single Test Class or Method (Crucial for TDD and targeted fixes):**
    ```bash
    xcodebuild -project ZenRide.xcodeproj -scheme ZenRide -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:ZenRideTests/YourTestClassName/testYourSpecificMethodName
    ```

*   **Linting (if SwiftLint is available):**
    ```bash
    swiftlint lint --strict
    ```
    To auto-correct formatting issues:
    ```bash
    swiftlint --fix
    ```

## 3. Code Style & Architectural Guidelines

### Architecture & State Management
*   **SwiftUI App Lifecycle:** The app uses `@main` and the `App` protocol. Avoid introducing `AppDelegate` unless required by legacy third-party SDKs or specific push notification setups.
*   **State Management:**
    *   Use `@State` for simple, view-local transient UI state.
    *   Use `@StateObject` (in the parent/root) and `@EnvironmentObject` / `@ObservedObject` (in child views) for shared data (e.g., `CameraStore`, `OwlPolice`).
    *   Keep Views declarative and thin. Complex business logic, location tracking (`CLLocationManager`), and audio synthesis should reside in dedicated `ObservableObject` controllers/services.
*   **Separation of Concerns:** Keep UI code completely separate from networking and heavy business logic. Use ViewModels or service classes to perform heavy lifting, updating `@Published` properties that the views react to.

### Formatting & Syntax
*   **Indentation:** Use 4 spaces for indentation.
*   **Line Length:** Keep lines under 120 characters. Break long method signatures or modifier chains onto multiple lines.
*   **Implicit Returns:** Use implicit returns for single-line closures and simple computed properties.
*   **Trailing Closures:** Always use trailing closure syntax when a closure is the final argument of a function call.
    ```swift
    // Good
    Button("Start Patrol") { 
        owlPolice.start() 
    }
    
    // Bad
    Button("Start Patrol", action: { owlPolice.start() })
    ```
*   **Property Wrappers:** Stack property wrappers on top of the property, not inline, unless it's a very short declaration.
    ```swift
    @StateObject 
    private var cameraStore = CameraStore()
    ```

### Naming Conventions
*   **Types (Structs, Classes, Enums, Protocols):** `PascalCase` (e.g., `SpeedCamera`, `ZoneStatus`).
*   **Variables, Properties, and Functions:** `camelCase` (e.g., `currentSpeedMPH`, `nearestCamera`, `startPatrol()`).
*   **Enum Cases:** `lowerCamelCase` (e.g., `.safe`, `.approach`).
*   **Booleans:** Prefix with `is`, `has`, or `should` (e.g., `isPatrolling`, `hasActiveAlert`).
*   **Acronyms:** Treat acronyms consistently. Either `url` and `id` (if used as a word) or `URL` and `ID`. Apple's convention often uses full caps for acronyms if they form the start of a PascalCase word (e.g., `URLSession`), but lowercase in camelCase if they are at the start (e.g., `urlSession`).

### Optionals and Error Handling
*   **No Force Unwrapping:** **NEVER** use `!` to force unwrap optionals (`variable!`) or implicitly unwrapped optionals (`var name: String!`) unless crashing is the explicitly desired behavior for an unrecoverable developer error.
*   **Safe Unwrapping:** Always use `if let` or `guard let` to unwrap.
*   **Early Returns:** Prefer `guard` statements to validate conditions early. The "golden path" (the main logic of the function) should not be deeply indented.
    ```swift
    guard let camera = nearestCamera else {
        return
    }
    // Proceed with camera...
    ```
*   **Error Handling:** Use `do-catch` blocks for throwing functions. Log errors explicitly and handle them gracefully in the UI instead of failing silently. Use custom Error enums adhering to `LocalizedError` for user-facing messaging.

### Imports
*   Group imports logically: Apple frameworks first (`import SwiftUI`, `import CoreLocation`), followed by third-party dependencies.
*   Keep imports alphabetical within their respective groups.

### UI / UX Guidelines
*   **Declarative Modifiers:** Chain modifiers cleanly. Place each modifier on a new line for readability.
    ```swift
    Text("Alert!")
        .font(.title)
        .foregroundColor(.red)
        .padding()
    ```
*   **Accessibility:** Always consider VoiceOver. Add `.accessibilityLabel()` and `.accessibilityValue()` when the visual representation (like an icon or color change) isn't inherently readable by assistive technologies.

## 4. Agent Operational Rules

1.  **Read Before Writing:** Use `cat`, `grep`, or `find` to read existing files and understand the current implementation context before modifying code. Never guess function signatures or property names.
2.  **No Extraneous Files:** Do not create random scripts or configuration files outside of the established `Sources/`, `Resources/`, and `project.yml` structure unless instructed.
3.  **Atomic Edits:** When fixing a bug, keep changes localized to the bug. Do not refactor unrelated code in the same pass.
4.  **Verification:** Whenever you change business logic or SwiftUI views, attempt to compile the project using the build command provided above to ensure you haven't introduced syntax errors.

## 5. Git and Commit Conventions

*   **Commit Messages:** If asked to commit changes, use conventional commits (e.g., `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
*   **Scope:** Include the scope when applicable (e.g., `feat(map): add custom map annotations`).
*   **Descriptions:** Keep the summary line under 50 characters. Provide a more detailed body if the commit logic is complex.
