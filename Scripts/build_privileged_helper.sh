#!/bin/sh
set -euo pipefail

APP_BUNDLE_PATH="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
HELPER_OUTPUT_DIR="${APP_BUNDLE_PATH}/Contents/Library/HelperTools"
LAUNCHD_OUTPUT_DIR="${APP_BUNDLE_PATH}/Contents/Library/LaunchDaemons"
HELPER_OUTPUT_PATH="${HELPER_OUTPUT_DIR}/com.verygood.VeryBattery.PrivilegedHelper"
HELPER_PLIST_SOURCE="${SRCROOT}/Scripts/com.verygood.VeryBattery.PrivilegedHelper.plist"
HELPER_PLIST_OUTPUT="${LAUNCHD_OUTPUT_DIR}/com.verygood.VeryBattery.PrivilegedHelper.plist"

mkdir -p "${HELPER_OUTPUT_DIR}" "${LAUNCHD_OUTPUT_DIR}"

xcrun swiftc \
  -DHELPER_TOOL \
  "${SRCROOT}/VeryBattery/BatteryPrivilegedProtocol.swift" \
  "${SRCROOT}/Scripts/VeryBatteryPrivilegedHelper.swift" \
  -o "${HELPER_OUTPUT_PATH}"

chmod 755 "${HELPER_OUTPUT_PATH}"
cp "${HELPER_PLIST_SOURCE}" "${HELPER_PLIST_OUTPUT}"
chmod 644 "${HELPER_PLIST_OUTPUT}"

if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none "${HELPER_OUTPUT_PATH}"
fi
