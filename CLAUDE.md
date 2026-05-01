# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Screenie is a macOS menu bar app for screen capture. It targets macOS 14.0+, uses Swift 6.0, and is built with SwiftUI. The app runs as a background agent (`LSUIElement = true`) without a Dock icon.

## Build System

This project uses **XcodeGen** — `project.yml` defines the project; there is no checked-in `.xcodeproj`. Regenerate the Xcode project after changing `project.yml`:

```bash
xcodegen generate
```

Build and run via Xcode after generating the project. There is currently no Swift Package Manager setup or command-line test runner.

## Architecture

The app uses a **SwiftUI + AppDelegate hybrid**. `ScreenieApp.swift` owns the lifecycle via `@NSApplicationDelegateAdaptor(AppDelegate.self)`, and the only SwiftUI `Scene` is a `Settings` window (`SettingsView`). All menu bar UI, hotkeys, and capture triggers are managed through `AppDelegate`.

Source is organized by layer under `Sources/`:

- `App/` — entry point and `AppDelegate`
- `Capture/` — screen recording / screenshot logic (uses `ScreenCaptureKit` or `CGWindowListCreate`)
- `Editor/` — annotation / editing after capture
- `Features/` — higher-level feature modules (e.g. history, sharing)
- `UI/` — reusable SwiftUI views and components

## Key Constraints

- **No sandbox** — `com.apple.security.app-sandbox` is `false`. Screen capture and file I/O work without entitlement prompts, but the app cannot be distributed via the Mac App Store in this configuration.
- **Hardened Runtime is on** with JIT, unsigned executable memory, and library-validation disabled — required for certain capture APIs.
- **Swift 6 strict concurrency** — all new code must satisfy Swift 6's actor-isolation and `Sendable` requirements. Prefer `@MainActor` for UI code and `async/await` over callbacks.
- The bundle ID is `com.screenie.app`.
