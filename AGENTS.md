# PhotoSorter Agent Guide

## Project
PhotoSorter is a native macOS SwiftUI app for sorting image files into category folders. Open `PhotoSorter.xcodeproj` directly; this repo does not use a top-level workspace, Swift Package manifest, or external dependencies.

Current Xcode setup:
- App target: `PhotoSorter`
- Unit test target: `PhotoSorterTests`
- Scheme: `PhotoSorter`
- Configuration: `Debug`
- Destination: `platform=macOS`
- Deployment target: macOS 15.7
- Bundle identifiers: `com.bkunat.PhotoSorter` and `com.bkunat.PhotoSorterTests`

## Repo Map
- App entry point: `PhotoSorter/PhotoSorterApp.swift`
- Main shell: `PhotoSorter/ContentView.swift`
- Views: `PhotoSorter/Views/`
- Session, scanning, persistence, and file moves: `PhotoSorter/Store/`
- Models: `PhotoSorter/Models/`
- Shared support types and logging: `PhotoSorter/Support/`
- XCTest unit tests and helpers: `PhotoSorterTests/`

## Build And Test
Run build and test commands from the repo root. Use `.derivedData` in the repo so outputs are repeatable, redirect `xcodebuild` output to a log file, and inspect logs with targeted searches instead of streaming raw output into the conversation. Do not paste full `xcodebuild` commands or raw logs into user-facing messages; summarize the result.

Use these defaults when running `xcodebuild`: project `PhotoSorter.xcodeproj`, scheme `PhotoSorter`, configuration `Debug`, destination `platform=macOS`, derived data path `.derivedData`, and `set -o pipefail`.

Verification expectations:
- UI-only changes: run at least a build.
- Store, model, shortcut, scanner, move, undo, or persistence changes: run `PhotoSorterTests`.
- Target wiring, app lifecycle, or broad cross-cutting changes: run the full test action.
- Single tests use `-only-testing:PhotoSorterTests/<ClassName>/<testMethod>`.

Useful log checks:
- Build logs: `rg -n "error:|warning:|BUILD FAILED|BUILD SUCCEEDED" build.log`
- Test logs: `rg -n "error:|warning:|Test Case|-\\[[A-Z]+\\]|\\*\\* TEST" test_output.log`

Delete temporary build or test logs before finishing unless the user asks to keep them. If CLI signing or host-process issues appear, verify the scheme in Xcode and rerun with fresh `.derivedData`.

## Implementation Notes
- Inspect the relevant SwiftUI view, store, model, or support type before changing behavior.
- Follow the existing SwiftUI and XCTest style; do not add dependencies unless the user explicitly asks.
- Add or update tests only when the change warrants coverage or the user asks for it.
- For interactive debugging or UI verification, open `PhotoSorter.xcodeproj` in Xcode and run the `PhotoSorter` scheme on macOS.

## Logging
Use `PhotoSorter/Support/AppLogger.swift`; do not introduce another logging pattern.

Add pragmatic logs when changing meaningful workflows, especially:
- feature start/end
- session state transitions
- file system operations
- error presentation and recovery-relevant failures
- performance-sensitive scans or batch work

Keep logs high signal. Include useful context such as filenames, category names, counts, durations, and paths when helpful, but do not log secrets or unnecessarily sensitive payloads.
