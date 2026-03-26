# VeryBattery Deployment Notes

## Runtime flow

1. User installs `VeryBattery.app`.
2. App launches normally as a menu bar app.
3. On the first privileged battery action, the app attempts to register the privileged helper.
4. macOS may request admin approval or require the helper to be allowed in system settings.
5. After approval, battery commands are executed through the helper over XPC.

## Clean Mac test procedure

Use a Mac that has never launched `VeryBattery` before.

1. Copy `VeryBattery.app` into `/Applications`.
2. Launch the app once and confirm the menu bar icon appears.
3. Open the popup and verify the initial UI renders correctly.
4. Change `충전 한도` to `80%`.
5. Turn on `강제 방전 모드`.
6. Confirm one of these appears:
   - macOS admin password prompt
   - a system approval requirement for the helper
   - the in-app alert saying helper approval is required
7. If the alert appears, open `System Settings > General > Login Items` and check the bottom `Allow in the Background` section for the VeryBattery helper. Approve it if shown.
8. Retry `강제 방전 모드`.
9. Confirm the top status changes to `강제 방전 중`.
10. Run `/usr/bin/pmset -g batt` in Terminal and confirm battery percentage begins to drop while the adapter is still connected.
11. Turn `강제 방전 모드` off and confirm the app returns to the configured maintenance level.
12. Quit the app, relaunch it, and verify saved toggles and charge limit restore correctly.
13. Reboot the Mac and verify:
   - the app launches normally
   - saved settings restore
   - privileged actions still work after approval

## Failure checks

If privileged actions do not work on a clean Mac, check these in order.

1. Open the popup and look for `helper 승인 필요` in the status area.
2. Inspect `System Settings > General > Login Items`.
3. Verify the helper exists inside the app bundle:
   - `VeryBattery.app/Contents/Library/HelperTools/com.verygood.VeryBattery.PrivilegedHelper`
   - `VeryBattery.app/Contents/Library/LaunchDaemons/com.verygood.VeryBattery.PrivilegedHelper.plist`
4. In Terminal, confirm the bundled CLI exists:
   - `VeryBattery.app/Contents/Resources/battery`
5. Check helper and CLI signatures:
   - `codesign -dv --verbose=4 /Applications/VeryBattery.app`
   - `codesign -dv --verbose=4 /Applications/VeryBattery.app/Contents/Library/HelperTools/com.verygood.VeryBattery.PrivilegedHelper`
6. Check app notarization result if distributing outside development.

## Build output to verify

- `VeryBattery.app/Contents/Resources/battery`
- `VeryBattery.app/Contents/Library/HelperTools/com.verygood.VeryBattery.PrivilegedHelper`
- `VeryBattery.app/Contents/Library/LaunchDaemons/com.verygood.VeryBattery.PrivilegedHelper.plist`

## Signing and notarization

- Sign the main app and helper with the same Developer ID team.
- Keep the helper inside `Contents/Library/HelperTools`.
- Keep the launchd plist inside `Contents/Library/LaunchDaemons`.
- Notarize the final `.app` or installer package before distribution.
- Test on a clean Mac that has never run the app before.
- Prefer shipping a signed `.pkg` or a notarized `.dmg` rather than a raw zip.

## Manual test checklist

- Launch the app and confirm the menu bar window opens.
- Toggle charge limit and verify helper approval prompt behavior on first privileged action.
- Confirm `강제 방전 모드` changes status to `강제 방전 중`.
- Reboot and verify saved settings restore correctly.
- Confirm the helper still works after relaunch.

## Known constraints

- This setup is for direct distribution, not Mac App Store.
- App Sandbox is disabled because the helper registration flow requires it.
- Helper approval UX differs slightly across macOS versions.
- `battery` CLI behavior can vary by version; test using the bundled binary that ships with the app.
