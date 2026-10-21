# ✋ Precog

🇬🇧 **English** · 🇫🇷 [Français](README.fr.md)

**Control your Mac with your bare hands, *Minority Report* style.**

<p align="center">
  <img src="docs/demo.gif" alt="Precog demo: a neon hand swipes through the air and the Mac switches desktops" width="720">
</p>

Precog is a small macOS menu bar app. It watches your hand through the webcam and turns simple gestures into system actions: no headset, no gloves, just your Mac's camera.

| Gesture | Action |
|---|---|
| ✋ Fingers extended for ¼ s (your wrist can be out of frame) | Arms detection |
| 👋 Swipe ← → | Previous / next desktop |
| ☝️ Swipe ↑ | Mission Control |
| 👇 Swipe ↓ | App windows (off by default) |

🔒 **100% on-device**: your hand is analyzed on your Mac with Apple's Vision framework. No image is ever recorded or sent anywhere.

> ℹ️ The app's interface is currently in French. The labels quoted below are shown as they appear in the app, with a translation.

## Installation

> Requires **macOS 14 Sonoma** or later and a webcam (built-in camera, USB webcam, or an iPhone via Continuity Camera).

1. Download **`Precog.zip`** from the [latest release](../../releases/latest).
2. Unzip it and drag **Precog.app** into your **Applications** folder.
3. Open Precog: the app is signed and notarized by Apple, so it launches right away.
4. A ✋ icon appears in the menu bar, and the welcome screen walks you through granting:
   - **Camera** access, to see your hand;
   - **Accessibility** access, so your gestures can switch desktops.
5. Create at least 2 desktops (Mission Control › ＋), hold up your extended fingers, then swipe.

## Features

- Menu bar icon with a camera preview and a **neon hand skeleton** (21 points)
- **Hologram mode**: your hand in neon on a black background, with a glowing trail, never showing the camera image
- **Floating hologram window**, visible on every desktop: perfect for recording a demo
- **Confirmation bubble**, like the macOS volume overlay, on every gesture
- **Settings**: camera (including Desk View), sensitivity, swipe direction, gesture selection, launch at login
- **Kill switch**: global shortcut (⌃⌥⌘G by default) to pause everything
- **Welcome screen** that guides you through permissions
- **Liquid Glass** effect on macOS 26, blurred material on macOS 14–15

## Troubleshooting

**The gesture is detected but the desktop doesn't change**
- Make sure Precog is checked in System Settings › Privacy & Security › Accessibility.
- If it's already checked, remove it (−), relaunch Precog, then add it again. Or from the terminal:
  ```bash
  tccutil reset Accessibility com.precog.app
  ```
- Make sure the "Move left a space" / "Move right a space" shortcuts (⌃← / ⌃→) are enabled in System Settings › Keyboard › Keyboard Shortcuts › Mission Control.

**I have to raise my hand too high**: in Precog's settings, pick the **Desk View** camera if it's offered, or tilt your screen slightly toward you.

**Too many accidental triggers**: move the sensitivity slider toward « Ample » (wide gesture) in the settings.

**The camera doesn't turn on**: System Settings › Privacy & Security › Camera › enable Precog.

## Build from source

Requirements: Xcode 16 or later (Xcode 26 recommended for the Liquid Glass effect) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone <this-repo-url>
cd precog-macos
make            # generates Precog.xcodeproj and opens it in Xcode
```

In Xcode, select the **Precog** target › **Signing & Capabilities** › **Team**: choose your Apple ID ("Personal Team"), then ▶️ (⌘R).
A stable signature keeps macOS from forgetting the Accessibility permission on every build.

| Command | What it does |
|---|---|
| `make` | Generates the Xcode project and opens it |
| `make install` | Builds in Release, installs into /Applications and launches the app |
| `make release` | Creates `build/Precog.zip`, signed with Developer ID and notarized by Apple (Apple Developer account required) |
| `make clean` | Removes the generated project and build files |

### Architecture

```
Precog/
├── App/
│   ├── PrecogApp.swift           # Entry point, menu bar icon
│   └── PrecogController.swift    # Global state: wires camera, engine, actions, UI
├── Engine/
│   ├── CameraManager.swift       # Webcam (AVFoundation) + hand detection (Vision)
│   ├── GestureEngine.swift       # Arming (extended fingers) + swipe detection
│   ├── Gestures.swift            # Gestures, actions and detection settings
│   ├── ActionPerformer.swift     # Simulates ⌃← ⌃→ ⌃↑ ⌃↓ (CGEvent)
│   ├── Permissions.swift         # Camera and Accessibility
│   └── Preferences.swift         # Preferences + kill switch shortcut
└── UI/
    ├── MenuPanelView.swift       # Menu bar panel
    ├── CameraPreview.swift       # Mirrored camera preview
    ├── HandSkeletonOverlay.swift # Neon skeleton
    ├── HologramView.swift        # Hologram mode (grid, trail, scanlines)
    ├── HUDController.swift       # Floating confirmation bubble
    ├── OnboardingView.swift      # Welcome screen
    ├── SettingsView.swift        # Settings
    ├── WindowPresenter.swift     # Window management
    └── Theme.swift               # Colors, glass effect
```

## Why not on the Mac App Store?

To switch desktops, Precog simulates keyboard shortcuts through the Accessibility API, which the Mac App Store sandbox doesn't allow. Like BetterTouchTool or Rectangle, Precog is distributed directly from GitHub.

## Final word

Let's be honest: Precog won't revolutionize the way you use your Mac. A three-finger swipe on the trackpad is still faster than waving at your screen, and your arm will remind you of that pretty quickly.

It's mostly a project for fun: seeing how far you can go with a plain webcam and Apple's tools. If you're working on something that needs real-time hand tracking (an interactive installation, a touchless kiosk, a game, an accessibility tool…), feel free to use this code as a starting point and take whatever you need.

## License

MIT, see [LICENSE](LICENSE).
