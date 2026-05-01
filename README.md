# Screenie

A fast, lightweight macOS screenshot and annotation tool. Lives in your menu bar — no Dock icon, no bloat.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)

---

## Features

**Capture**
- Area capture with drag-to-select across multiple displays
- Fullscreen capture
- Window capture — click to pick any visible window, captured cleanly without background
- Timed capture with 3, 5, or 10 second countdown

**Annotate**
- Arrow, rectangle, highlight, text, blur, and numbered callout tools
- Customizable stroke color and line width
- Undo support
- Magnifier loupe during area selection for pixel-perfect crops

**Utilities**
- OCR — extract text from any screenshot using Apple Vision
- Color picker — sample any pixel, copy hex or RGB value
- Pixel ruler — click two points to measure distance in pixels
- Pin to screen — float any screenshot above all other windows

**Workflow**
- Capture history with thumbnails (last 20 captures)
- Auto-save to Desktop or a custom folder
- Export as PNG
- Fully customizable keyboard shortcuts

---

## Requirements

- macOS 14.0 or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

---

## Building

```bash
git clone https://github.com/Bookantna/Screenie.git
cd Screenie
xcodegen generate
open Screenie.xcodeproj
```

Press **⌘R** in Xcode to build and run.

On first launch, macOS will ask for **Screen Recording** permission. Open System Settings → Privacy & Security → Screen Recording and enable Screenie, then relaunch.

---

## Default Shortcuts

| Action | Shortcut |
|---|---|
| Capture area | ⌘⇧1 |
| Capture fullscreen | ⌘⇧2 |
| Capture window | ⌘⇧W |
| Pick color | ⌥⇧C |
| Pixel ruler | ⌥⇧R |

All shortcuts are reassignable in **Settings → Hotkeys**.

---

## Tech Stack

- **Swift 6** with strict concurrency (`@MainActor`, `async/await`)
- **SwiftUI** + **AppKit** hybrid — `NSStatusItem`, `NSPanel`, `NSHostingView`
- **ScreenCaptureKit** for all capture operations
- **Vision** framework for OCR
- **Core Image** for blur/pixelate annotations
- **Carbon** for global hotkey registration
- **XcodeGen** — no checked-in `.xcodeproj`, generate with `xcodegen generate`

---

## Project Structure

```
Sources/
├── App/          # Entry point, AppDelegate, menu bar
├── Capture/      # Overlays, hotkeys, screen recording
├── Editor/       # Annotation canvas, tools, export
├── Features/     # OCR, color picker, pin window, history
└── UI/           # Settings view
```

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

This project uses XcodeGen — edit `project.yml` to change build settings, never commit `.xcodeproj` changes directly.

---

## License

MIT — see [LICENSE](LICENSE).
