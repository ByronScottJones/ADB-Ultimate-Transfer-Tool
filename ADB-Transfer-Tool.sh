#!/usr/bin/env bash

set -u

menu() {
  clear
  echo "===================================================="
  echo "     ADB TRANSFER TOOL V1.0 (CONNECTED)"
  echo "===================================================="
  echo "Device ID:"
  adb devices -l | awk 'NR>1 && $2=="device" {print $0}'
  echo "===================================================="
  echo
  echo "[1] List Files/Folders (Explore Phone)"
  echo
  echo "--- EXPORT (Phone -> PC) ---"
  echo "[2] Phone Internal -> PC"
  echo "[3] Phone SD Card  -> PC"
  echo
  echo "--- IMPORT (PC -> Phone) ---"
  echo "[4] PC -> Phone Internal"
  echo "[5] PC -> Phone SD Card"
  echo
  echo "[0] EXIT"
  echo "===================================================="
  read -r -p "Select Option: " opt

  case "$opt" in
    1) explore ;;
    2) pull_internal ;;
    3) pull_sd ;;
    4) push_internal ;;
    5) push_sd ;;
    0) exit 0 ;;
    *) menu ;;
  esac
}

check_connection() {
  if adb get-state >/dev/null 2>&1 && adb devices | awk 'NR>1 && $2=="device" {found=1} END {exit(found?0:1)}'; then
    return 0
  fi

  clear
  echo "===================================================="
  echo "[!] NO ACTIVE DEVICE DETECTED"
  echo "===================================================="
  echo
  echo "STATUS: Waiting for connection..."
  echo
  echo "TROUBLESHOOTING:"
  echo "1. Unplug and Replug USB cable."
  echo "2. Check phone screen for \"Allow USB Debugging?\" popup."
  echo "3. Ensure the device is authorized and set to a supported USB mode."
  echo
  echo "Press Ctrl+C to quit or wait 3 seconds to retry..."
  sleep 3
  check_connection
}

explore() {
  clear
  echo "--- FILE EXPLORER ---"
  echo "[1] Internal Storage (/sdcard/)"
  echo "[2] SD Card (/storage/...)"
  echo "[0] Back to Menu"
  echo
  read -r -p "Select: " exopt

  case "$exopt" in
    0) menu ;;
    1)
      echo "Listing /sdcard/..."
      adb shell ls -F /sdcard/
      echo
      read -r -p "Press Enter to continue..." _
      explore
      ;;
    2)
      echo "Listing /storage/..."
      adb shell ls /storage/
      echo
      echo "Note your SD Card ID (e.g., 1234-5678)"
      read -r -p "Press Enter to continue..." _
      explore
      ;;
    *) explore ;;
  esac
}

ask_repeat_pull() {
  local mode="$1"
  echo
  echo "=========================================="
  echo "[1] Transfer ANOTHER file in this mode"
  echo "[2] Return to Main Menu"
  echo "=========================================="
  read -r -p "Choose: " choice

  if [[ "$choice" == "1" ]]; then
    if [[ "$mode" == "internal" ]]; then
      pull_internal
    else
      pull_sd
    fi
  else
    menu
  fi
}

ask_repeat_push() {
  local mode="$1"
  echo
  echo "=========================================="
  echo "[1] Transfer ANOTHER file in this mode"
  echo "[2] Return to Main Menu"
  echo "=========================================="
  read -r -p "Choose: " choice

  if [[ "$choice" == "1" ]]; then
    if [[ "$mode" == "internal" ]]; then
      push_internal
    else
      push_sd
    fi
  else
    menu
  fi
}

pull_internal() {
  clear
  echo "=========================================="
  echo "  MODE: PHONE INTERNAL -> PC"
  echo "=========================================="
  check_connection

  echo "Current Folders in Internal Storage:"
  adb shell ls -d /sdcard/*/
  echo "=========================================="
  echo "Tip: Type \"0\" to go back."
  echo

  while true; do
    read -r -p "Enter Folder Path on Phone (relative to /sdcard/, e.g. DCIM or DCIM/Camera): " source
    [[ -z "$source" ]] && continue
    [[ "$source" == "0" ]] && menu
    break
  done

  full_source="/sdcard/$source"

  echo
  read -r -p "Destination path on this computer: " dest
  dest=${dest%\"}
  dest=${dest#\"}

  if [[ -z "$dest" ]]; then
    echo "[!] Error: No path provided."
    read -r -p "Press Enter to continue..." _
    pull_internal
  fi

  echo
  echo "Transferring [\"$full_source\"] to [\"$dest\"]..."
  if ! adb pull "$full_source" "$dest"; then
    echo "[!] Transfer failed."
    read -r -p "Press Enter to continue..." _
    pull_internal
  fi

  ask_repeat_pull "internal"
}

pull_sd() {
  clear
  echo "=========================================="
  echo "  MODE: SD CARD -> PC"
  echo "=========================================="
  check_connection

  echo "Finding SD Card ID..."
  adb shell ls /storage/
  echo

  while true; do
    read -r -p "Enter SD Card ID (e.g. 3492-12F2): " sdid
    [[ -z "$sdid" ]] && continue
    [[ "$sdid" == "0" ]] && menu
    break
  done

  echo
  echo "Folders on SD Card:"
  adb shell ls -F "/storage/$sdid/"
  echo

  while true; do
    read -r -p "Enter Folder Path on SD Card (relative to /storage/$sdid/, e.g. DCIM or * for ALL): " source
    [[ -z "$source" ]] && continue
    [[ "$source" == "0" ]] && menu
    break
  done

  full_source="/storage/$sdid/$source"

  echo
  read -r -p "Destination path on this computer: " dest
  dest=${dest%\"}
  dest=${dest#\"}
  [[ -z "$dest" ]] && pull_sd

  echo
  echo "Transferring..."
  if ! adb pull "$full_source" "$dest"; then
    echo "[!] Transfer failed."
    read -r -p "Press Enter to continue..." _
    pull_sd
  fi

  ask_repeat_pull "sd"
}

push_internal() {
  clear
  echo "=========================================="
  echo "  MODE: PC -> PHONE INTERNAL"
  echo "=========================================="
  check_connection

  read -r -p "Source path on this computer (file or folder): " source
  source=${source%\"}
  source=${source#\"}
  [[ -z "$source" ]] && push_internal
  [[ "$source" == "0" ]] && menu

  echo
  echo "Where to put it on phone? (Default: /sdcard/)"
  echo "Common: /sdcard/Movies/ or /sdcard/Download/"
  read -r -p "Phone Dest (Enter for root): " dest
  dest=${dest%\"}
  dest=${dest#\"}
  [[ -z "$dest" ]] && dest="/sdcard/"

  echo
  echo "Pushing..."
  if ! adb push "$source" "$dest"; then
    echo "[!] Transfer failed."
    read -r -p "Press Enter to continue..." _
    push_internal
  fi

  ask_repeat_push "internal"
}

push_sd() {
  clear
  echo "=========================================="
  echo "  MODE: PC -> SD CARD"
  echo "=========================================="
  check_connection

  echo "[!] NOTE: Android 11+ often blocks writing to SD via ADB."
  echo

  while true; do
    read -r -p "Enter SD Card ID (from option 1): " sdid
    [[ -z "$sdid" ]] && continue
    [[ "$sdid" == "0" ]] && menu
    break
  done

  read -r -p "Source path on this computer: " source
  source=${source%\"}
  source=${source#\"}
  [[ -z "$source" ]] && push_sd
  [[ "$source" == "0" ]] && menu

  echo
  echo "Pushing..."
  if ! adb push "$source" "/storage/$sdid/"; then
    echo "[!] Transfer failed."
    echo "[!] Writing to SD card may be blocked on this device/Android version."
    read -r -p "Press Enter to continue..." _
    push_sd
  fi

  ask_repeat_push "sd"
}

clear
echo "Starting ADB Server..."
if ! command -v adb >/dev/null 2>&1; then
  echo "[!] adb was not found in PATH."
  echo "Install platform-tools or add adb to PATH, then try again."
  exit 1
fi

adb start-server >/dev/null 2>&1
check_connection
menu
