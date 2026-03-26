# VeryBattery

[한국어 README](./README.ko.md)

The most elegant and practical way to preserve your Mac's battery life.

VeryBattery is a macOS menu bar utility for charge-limit control, thermal protection, and app-based battery automation. It is designed for long plugged-in sessions such as rendering, design work, and laptop desk use.

## Features

- `80% / 100%` charge limit switching
- sailing mode with `80% -> 75%` hysteresis
- forced discharge mode
- thermal protection with temperature-based charging pause
- app-based auto full-charge rules
- trip charging mode for temporary `100%` charging
- live battery percentage, power source, and temperature monitoring
- warm beige UI with deep green accents

## How it works

VeryBattery uses the `battery` CLI to control charging behavior.

For distribution builds:

- the `battery` CLI is bundled inside the app package
- a privileged helper is included for elevated battery-control operations
- the app talks to the helper through XPC

Typical runtime flow:

1. Launch `VeryBattery.app`
2. Open the menu bar popup
3. Trigger a privileged battery action such as charge maintenance or forced discharge
4. Approve the helper if macOS requests admin permission
5. Continue using the app normally after approval

## Installation

1. Copy `VeryBattery.app` to `/Applications`
2. Launch the app
3. If macOS blocks the app, allow it in `System Settings > Privacy & Security`
4. When prompted for helper approval, approve it and retry the action

## Important distribution note

This project is intended for direct distribution, not Mac App Store distribution.

Reasons:

- privileged helper registration is required
- App Sandbox is disabled
- battery-control features require elevated system access

## Development

Build in Xcode:

```bash
xcodebuild -project VeryBattery.xcodeproj -scheme VeryBattery -destination 'platform=macOS' build
```

## Deployment and QA

Detailed clean-machine test steps, approval flow, signing notes, and deployment checks are documented in [DEPLOYMENT.md](./DEPLOYMENT.md).

Release note templates are available in [RELEASE.md](./RELEASE.md) and [RELEASE.ko.md](./RELEASE.ko.md).

## Author

John (`nam9295-cmyk`)
