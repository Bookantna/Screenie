# Screenie — User Manual

## Table of Contents

- [Installation](#installation)
- [Menu Bar](#menu-bar)
- [Capturing Screenshots](#capturing-screenshots)
- [Editor & Annotations](#editor--annotations)
- [OCR — Extract Text](#ocr--extract-text)
- [Pin to Screen](#pin-to-screen)
- [Timed Capture](#timed-capture)
- [Color Picker](#color-picker)
- [Pixel Ruler](#pixel-ruler)
- [Capture History](#capture-history)
- [Settings](#settings)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Troubleshooting](#troubleshooting)

---

## Installation

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Clone the repo and generate the Xcode project:
   ```bash
   git clone https://github.com/Bookantna/Screenie.git
   cd Screenie
   xcodegen generate
   open Screenie.xcodeproj
   ```
3. Press **⌘R** in Xcode to build and run.
4. On first launch, macOS will prompt for **Screen Recording** permission. Click **Open System Settings**, toggle Screenie on, then relaunch the app.

Screenie runs as a menu bar app — no Dock icon. Look for the **⊡** camera icon in your menu bar.

---

## Menu Bar

Click the **⊡** icon to open the menu:

| Item | Description |
|---|---|
| Capture Area | Drag-select a region on any display |
| Capture Fullscreen | Capture the entire primary display |
| Capture Window | Click to pick a specific window |
| Timed Capture | Countdown then capture (3 / 5 / 10 s) |
| Pixel Ruler | Measure distance between two points |
| Pick Color | Sample any pixel on screen |
| Recent Captures | Browse and reopen last 20 screenshots |
| Settings… | Shortcuts, save destination |
| Quit Screenie | Exit the app |

---

## Capturing Screenshots

### Area Capture — ⌘⇧1

1. Press **⌘⇧1** or click **Capture Area** in the menu.
2. All displays dim. Your cursor becomes a crosshair.
3. A **magnifier loupe** appears near your cursor showing a zoomed pixel preview — useful for snapping to exact edges.
4. **Click and drag** to draw a selection. The live pixel dimensions appear above the selection.
5. **Release** to capture and open the editor.
6. Press **Esc** at any time to cancel.

### Fullscreen Capture — ⌘⇧2

Press **⌘⇧2** or click **Capture Fullscreen**. The primary display is captured and opens in the editor immediately.

### Window Capture — ⌘⇧W

1. Press **⌘⇧W** or click **Capture Window**.
2. Hover over any open window — a **blue outline** and the window title appear.
3. **Click** to capture that window cleanly (no background, no overlapping windows).
4. Press **Esc** to cancel.

---

## Editor & Annotations

Every capture opens in the **Editor**. Annotate the image, then copy, save, or pin it.

### Toolbar

| Tool | Icon | How to use |
|---|---|---|
| Arrow | ↗ | Drag from tail to tip |
| Rectangle | ▭ | Drag to size |
| Highlight | Marker | Drag to cover an area (yellow, semi-transparent) |
| Text | T | Click to place, type your text, press **Enter** to commit |
| Blur | 🚫 | Drag to pixelate a region (good for hiding sensitive info) |
| Callout | ① | Click to drop a numbered circle — auto-increments with each click |

**Color well** — click to change the stroke / fill color for the active tool.  
**Line width stepper** — adjust stroke thickness (1–8 px).  
**Undo** — ⌘Z or the Undo button in the action bar.

### Action Bar

| Button | Shortcut | What it does |
|---|---|---|
| Copy | ⌘C | Flattens annotations onto the image and copies to clipboard |
| Save… | — | Exports as PNG via a save dialog |
| Pin | — | Floats the image above all other windows |
| OCR | — | Extracts text from the screenshot |
| Undo | ⌘Z | Removes the last annotation |
| Close | Esc | Discards changes and closes the editor |

---

## OCR — Extract Text

1. Open any screenshot in the editor.
2. Click **OCR** in the action bar.
3. Screenie scans the image using Apple's Vision framework. A sheet appears with all recognised text.
4. Click **Copy All** to copy every line to your clipboard, or select individual lines manually.

Best results with printed horizontal text. Handwriting and very small text may not be detected.

---

## Pin to Screen

Click **Pin** in the editor action bar. The annotated screenshot becomes a small floating panel that stays above every other window.

- **Drag** the panel anywhere on screen.
- **Hover** over it to reveal the **✕** close button.

Useful for keeping a reference image visible while you work in another app.

---

## Timed Capture

1. Click the menu bar icon → **Timed Capture** → choose **3**, **5**, or **10** seconds.
2. A countdown window appears in the corner of your screen.
3. When it hits zero, the area selection overlay opens — drag to capture.

Use this to capture menus or tooltips that disappear when you click away.

---

## Color Picker — ⌥⇧C

1. Press **⌥⇧C** or click **Pick Color** in the menu.
2. Your cursor becomes an eyedropper. Click any pixel on screen.
3. A panel appears showing:
   - A colour swatch
   - Hex value (e.g. `#1A2B3C`)
   - RGB value (e.g. `rgb(26, 43, 60)`)
   - **Copy Hex** button

---

## Pixel Ruler — ⌥⇧R

1. Press **⌥⇧R** or click **Pixel Ruler** in the menu.
2. **Click the first point**.
3. **Click the second point**.
4. A dashed line with tick marks shows the distance. The pixel count is automatically copied to your clipboard.

Press **Esc** to cancel at any time.

---

## Capture History

Click the menu bar icon → **Recent Captures** to browse the last 20 screenshots.

- Each entry shows a **thumbnail** and **timestamp**.
- Click any entry to reopen it in the editor.
- Click **Clear History** to remove all entries.

History is stored in memory and UserDefaults — it resets if you reinstall the app.

---

## Settings

Click the menu bar icon → **Settings…**

### After Capture

Choose where captures go automatically:

| Option | Behaviour |
|---|---|
| Clipboard | Image goes to the editor; Copy puts it on the clipboard |
| Desktop | Auto-saved as PNG to `~/Desktop` and opened in the editor |
| Custom Folder | Auto-saved to a folder you choose |

Files are named `Screenshot YYYY-MM-DD HH-MM-SS.png`.

### Hotkeys

Every action has a customizable shortcut:

1. Click the shortcut label next to an action.
2. Press your new key combination (must include at least one modifier: ⌘ ⌃ ⌥ ⇧).
3. The binding is saved and takes effect immediately — no restart needed.

> Avoid **⌘⇧3** and **⌘⇧4** — macOS reserves those for its own screenshot shortcuts.

---

## Keyboard Shortcuts

| Action | Default |
|---|---|
| Capture area | ⌘⇧1 |
| Capture fullscreen | ⌘⇧2 |
| Capture window | ⌘⇧W |
| Pick color | ⌥⇧C |
| Pixel ruler | ⌥⇧R |
| Undo (in editor) | ⌘Z |
| Copy (in editor) | ⌘C |
| Close editor | Esc |
| Cancel any overlay | Esc |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Permission prompt appears on every build | Run `./tools/reset-screen-permission.sh` in Terminal, relaunch, and grant permission once |
| Screen stays black or capture fails | System Settings → Privacy & Security → Screen Recording → enable Screenie |
| Hotkeys don't respond | Another app may have claimed the shortcut — reassign it in Settings → Hotkeys |
| Color picker / ruler shortcuts conflict | Avoid ⌘⇧3 and ⌘⇧4; the defaults (⌥⇧C, ⌥⇧R) are safe |
| OCR returns no text | Vision works best on clear, horizontal, printed text |
| Blur annotation doesn't appear in exported PNG | Known limitation — blur renders in the live editor; export support coming in a future update |
| Menu bar icon missing | The app may have crashed — relaunch from Xcode |
| `xcodegen generate` fails | Make sure XcodeGen is installed: `brew install xcodegen` |
