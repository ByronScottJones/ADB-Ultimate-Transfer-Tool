#!/usr/bin/env bash
set -euo pipefail

TITLE="ADB Ultimate Transfer Tool V1.0"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear
printf '%bStarting ADB Server...%b\n' "$GREEN" "$NC"

if ! command -v adb >/dev/null 2>&1; then
  printf '%b[!] adb was not found in PATH.%b\n' "$RED" "$NC"
  printf 'Install Android platform-tools or add adb to PATH, then try again.\n'
  exit 1
fi

adb start-server >/dev/null 2>&1 || true

check_connection() {
  adb get-state >/dev/null 2>&1 || return 1
  adb devices | awk 'NR>1 && $2=="device" {found=1} END {exit found?0:1}'
}

device_not_found() {
  printf '%b====================================================%b\n' "$RED" "$NC"
  printf '%b[!] NO ACTIVE DEVICE DETECTED%b\n' "$RED" "$NC"
  printf '%b====================================================%b\n' "$RED" "$NC"
  printf '\nSTATUS: Waiting for connection...\n\n'
  printf 'TROUBLESHOOTING:\n'
  printf '1. Unplug and replug USB cable.\n'
  printf '2. Check phone screen for "Allow USB Debugging?" popup.\n'
  printf '3. Ensure the device is authorized and set to a supported USB mode.\n\n'
  printf 'Press Ctrl+C to quit or wait 3 seconds to retry...\n'
  sleep 3
}

menu() {
  while true; do
    if ! check_connection; then
      device_not_found
      continue
    fi

    clear
    printf '%b====================================================%b\n' "$GREEN" "$NC"
    printf '     ADB TRANSFER TOOL V1.0 (CONNECTED)\n'
    printf '%b====================================================%b\n' "$GREEN" "$NC"
    printf 'Device ID:\n'
    adb devices -l | awk 'NR>1 && $2=="device" {print}'
    printf '%b====================================================%b\n' "$GREEN" "$NC"
    printf '\n[1] List Files/Folders (Explore Phone)\n\n'
    printf '--- EXPORT (Phone -to- PC) ---\n'
    printf '[2] Phone Internal -to- PC\n'
    printf '[3] Phone SD Card  -to- PC\n\n'
    printf '--- IMPORT (PC -to- Phone) ---\n'
    printf '[4] PC -to- Phone Internal\n'
    printf '[5] PC -to- Phone SD Card\n\n'
    printf '[0] EXIT\n'
    printf '%b====================================================%b\n' "$GREEN" "$NC"
    read -r -p 'Select Option: ' opt || true

    case "${opt:-}" in
      1) explore ;;
      2) pull_int ;;
      3) pull_sd ;;
      4) push_int ;;
      5) push_sd ;;
      0) exit 0 ;;
      *) : ;;
    esac
  done
}

explore() {
  while true; do
    clear
    printf '--- FILE EXPLORER ---\n'
    printf '[1] Internal Storage (/sdcard/)\n'
    printf '[2] SD Card (/storage/...)\n'
    printf '[0] Back to Menu\n\n'
    read -r -p 'Select: ' exopt || true
    case "${exopt:-}" in
      0) return ;;
      1)
        printf 'Listing /sdcard/...\n'
        adb shell ls -F /sdcard/ || true
        printf '\n'
        read -r -p 'Press Enter to continue...' _
        ;;
      2)
        printf 'Listing /storage/...\n'
        adb shell ls /storage/ || true
        printf '\nNote your SD Card ID (e.g., 1234-5678)\n'
        read -r -p 'Press Enter to continue...' _
        ;;
      *) ;;
    esac
  done
}

pull_int() {
  while true; do
    clear
    printf '==========================================\n'
    printf '  MODE: PHONE INTERNAL -TO- PC\n'
    printf '==========================================\n'
    adb get-state >/dev/null 2>&1 || { device_not_found; return; }
    printf 'Current Folders in Internal Storage:\n'
    adb shell ls -d /sdcard/*/ || true
    printf '==========================================\n'
    printf 'Tip: Type "0" to go back.\n\n'

    read -r -p 'Enter Folder Path on Phone (relative to /sdcard/, e.g. DCIM or DCIM/Camera): ' source || true
    [[ -z "${source:-}" ]] && continue
    [[ "$source" == "0" ]] && return

    full_source="/sdcard/$source"

    read -r -p 'Destination (PC path): ' dest || true
    dest=${dest%"}
    dest=${dest#"}
    [[ -z "${dest:-}" ]] && { printf '[!] Error: No path provided.\n'; read -r -p 'Press Enter to continue...' _; continue; }

    printf '\nTransferring [%s] to [%s]...\n' "$full_source" "$dest"
    if ! adb pull "$full_source" "$dest"; then
      printf '[!] Transfer failed.\n'
      read -r -p 'Press Enter to continue...' _
      continue
    fi

    if repeat_pull; then :; else return; fi
  done
}

pull_sd() {
  while true; do
    clear
    printf '==========================================\n'
    printf '  MODE: SD CARD -TO- PC\n'
    printf '==========================================\n'
    adb get-state >/dev/null 2>&1 || { device_not_found; return; }

    printf 'Finding SD Card ID...\n'
    adb shell ls /storage/ || true
    printf '\n'
    read -r -p 'Enter SD Card ID (e.g. 3492-12F2): ' sdid || true
    [[ -z "${sdid:-}" ]] && continue
    [[ "$sdid" == "0" ]] && return

    printf '\nFolders on SD Card:\n'
    adb shell ls -F "/storage/$sdid/" || true
    printf '\n'
    read -r -p 'Enter Folder Path on SD Card (relative to /storage/<id>/, e.g. DCIM or * for ALL): ' source || true
    [[ -z "${source:-}" ]] && continue
    [[ "$source" == "0" ]] && return

    full_source="/storage/$sdid/$source"
    read -r -p 'Destination (PC path): ' dest || true
    dest=${dest%"}
    dest=${dest#"}
    [[ -z "${dest:-}" ]] && continue

    printf '\nTransferring...\n'
    if ! adb pull "$full_source" "$dest"; then
      printf '[!] Transfer failed.\n'
      read -r -p 'Press Enter to continue...' _
      continue
    fi

    if repeat_pull; then :; else return; fi
  done
}

push_int() {
  while true; do
    clear
    printf '==========================================\n'
    printf '  MODE: PC -TO- PHONE INTERNAL\n'
    printf '==========================================\n'
    adb get-state >/dev/null 2>&1 || { device_not_found; return; }

    read -r -p 'Source (PC path): ' source || true
    source=${source%"}
    source=${source#"}
    [[ -z "${source:-}" ]] && continue
    [[ "$source" == "0" ]] && return

    printf '\nWhere to put it on phone? (Default: /sdcard/)\n'
    printf 'Common: /sdcard/Movies/ or /sdcard/Download/\n'
    read -r -p 'Phone Dest (Enter for root): ' dest || true
    dest=${dest%"}
    dest=${dest#"}
    [[ -z "${dest:-}" ]] && dest='/sdcard/'

    printf '\nPushing...\n'
    if ! adb push "$source" "$dest"; then
      printf '[!] Transfer failed.\n'
      read -r -p 'Press Enter to continue...' _
      continue
    fi

    if repeat_push; then :; else return; fi
  done
}

push_sd() {
  while true; do
    clear
    printf '==========================================\n'
    printf '  MODE: PC -TO- SD CARD\n'
    printf '==========================================\n'
    adb get-state >/dev/null 2>&1 || { device_not_found; return; }
    printf '[!] NOTE: Android 11+ often blocks writing to SD via ADB.\n\n'

    read -r -p 'Enter SD Card ID (from option 1): ' sdid || true
    [[ -z "${sdid:-}" ]] && continue
    [[ "$sdid" == "0" ]] && return

    read -r -p 'Source (PC path): ' source || true
    source=${source%"}
    source=${source#"}
    [[ -z "${source:-}" ]] && continue
    [[ "$source" == "0" ]] && return

    printf '\nPushing...\n'
    if ! adb push "$source" "/storage/$sdid/"; then
      printf '[!] Transfer failed.\n'
      printf '[!] Writing to SD card may be blocked on this device/Android version.\n'
      read -r -p 'Press Enter to continue...' _
      continue
    fi

    if repeat_push; then :; else return; fi
  done
}

repeat_pull() {
  printf '\n==========================================\n'
  printf '[1] Transfer ANOTHER file in this mode\n'
  printf '[2] Return to Main Menu\n'
  printf '==========================================\n'
  read -r -p 'Choose: ' choice || true
  [[ "${choice:-}" == "1" ]]
}

repeat_push() {
  printf '\n==========================================\n'
  printf '[1] Transfer ANOTHER file in this mode\n'
  printf '[2] Return to Main Menu\n'
  printf '==========================================\n'
  read -r -p 'Choose: ' choice || true
  [[ "${choice:-}" == "1" ]]
}

menu