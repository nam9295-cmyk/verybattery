# VeryBattery v1.0.0

VeryBattery is a macOS menu bar battery utility built for long plugged-in workflows.

This release includes the first distribution-ready app build with bundled battery control tooling, privileged helper support, live battery monitoring, and bilingual UI support.

## Highlights

- Charge limit control with `80%` and `100%` modes
- Sailing mode with `80% -> 75%` hysteresis
- Forced discharge mode
- Thermal protection mode
- App-based auto full-charge rules
- Trip prep mode for temporary full charging
- Live battery percentage, power source, and temperature monitoring
- Bundled `battery` CLI inside the app package
- Privileged helper + XPC flow for elevated battery control
- English and Korean UI localization

## Installation

1. Download `VeryBattery.app`
2. Move it to `/Applications`
3. Launch the app
4. Approve the app in `System Settings > Privacy & Security` if macOS asks
5. On the first privileged battery action, approve the helper if required

## Important notes

- This app is intended for direct distribution, not Mac App Store distribution
- Privileged battery actions may require administrator approval on first use
- Helper approval behavior can vary slightly depending on macOS version

## Recommended verification after install

- Open the menu bar popup and confirm the UI appears correctly
- Change the charge limit to `80%`
- Try `Force Discharge`
- If the app requests helper approval, complete the approval and retry
- Confirm battery behavior updates as expected

## Known constraints

- Battery behavior depends on the bundled `battery` CLI and the target Mac's environment
- Clamshell mode can affect force-discharge behavior
- Clean-machine testing is strongly recommended before broad distribution

For deployment and QA details, see `DEPLOYMENT.md`.
