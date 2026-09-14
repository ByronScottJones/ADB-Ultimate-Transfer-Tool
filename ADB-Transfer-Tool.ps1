$Host.UI.RawUI.WindowTitle = "ADB Ultimate Transfer Tool V1.0"
$ErrorActionPreference = "Continue"

function Test-AdbAvailable {
    return [bool](Get-Command adb -ErrorAction SilentlyContinue)
}

function Remove-WrappingQuotes {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    return $Value.Trim().Trim('"')
}

function Test-DeviceConnected {
    adb get-state *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $devices = adb devices
    foreach ($line in $devices) {
        if ($line -match "\sdevice$") {
            return $true
        }
    }

    return $false
}

function Wait-ForConnection {
    while (-not (Test-DeviceConnected)) {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Red
        Write-Host "[!] NO ACTIVE DEVICE DETECTED" -ForegroundColor Red
        Write-Host "====================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "STATUS: Waiting for connection..."
        Write-Host ""
        Write-Host "TROUBLESHOOTING:"
        Write-Host "1. Unplug and Replug USB cable."
        Write-Host "2. Check phone screen for 'Allow USB Debugging?' popup."
        Write-Host "3. Ensure the device is authorized and set to a supported USB mode."
        Write-Host ""
        Write-Host "Press Ctrl+C to quit or wait 3 seconds to retry..."
        Start-Sleep -Seconds 3
    }
}

function Show-Explorer {
    while ($true) {
        Clear-Host
        Write-Host "--- FILE EXPLORER ---"
        Write-Host "[1] Internal Storage (/sdcard/)"
        Write-Host "[2] SD Card (/storage/...)"
        Write-Host "[0] Back to Menu"
        Write-Host ""
        $exopt = Read-Host "Select"

        switch ($exopt) {
            "0" { return }
            "1" {
                Write-Host "Listing /sdcard/..."
                adb shell ls -F /sdcard/
                Write-Host ""
                Read-Host "Press Enter to continue"
            }
            "2" {
                Write-Host "Listing /storage/..."
                adb shell ls /storage/
                Write-Host ""
                Write-Host "Note your SD Card ID (e.g., 1234-5678)"
                Read-Host "Press Enter to continue"
            }
            default { }
        }
    }
}

function Ask-RepeatPull {
    param([string]$Mode)
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "[1] Transfer ANOTHER file in this mode"
    Write-Host "[2] Return to Main Menu"
    Write-Host "=========================================="
    $choice = Read-Host "Choose"

    if ($choice -eq "1") {
        if ($Mode -eq "internal") {
            Start-PullInternal
        } else {
            Start-PullSd
        }
    }
}

function Ask-RepeatPush {
    param([string]$Mode)
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "[1] Transfer ANOTHER file in this mode"
    Write-Host "[2] Return to Main Menu"
    Write-Host "=========================================="
    $choice = Read-Host "Choose"

    if ($choice -eq "1") {
        if ($Mode -eq "internal") {
            Start-PushInternal
        } else {
            Start-PushSd
        }
    }
}

function Start-PullInternal {
    while ($true) {
        Clear-Host
        Write-Host "=========================================="
        Write-Host "  MODE: PHONE INTERNAL -> PC"
        Write-Host "=========================================="
        Wait-ForConnection

        Write-Host "Current Folders in Internal Storage:"
        adb shell ls -d /sdcard/*/
        Write-Host "=========================================="
        Write-Host "Tip: Type '0' to go back."
        Write-Host ""

        $source = Read-Host "Enter Folder Path on Phone (relative to /sdcard/, e.g. DCIM or DCIM/Camera)"
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        if ($source -eq "0") { return }

        $fullSource = "/sdcard/$source"
        $dest = Remove-WrappingQuotes (Read-Host "Destination path on this computer")
        if ([string]::IsNullOrWhiteSpace($dest)) {
            Write-Host "[!] Error: No path provided." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            continue
        }

        Write-Host ""
        Write-Host "Transferring [\"$fullSource\"] to [\"$dest\"]..."
        adb pull "$fullSource" "$dest"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Transfer failed." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            continue
        }

        Ask-RepeatPull -Mode "internal"
        return
    }
}

function Start-PullSd {
    while ($true) {
        Clear-Host
        Write-Host "=========================================="
        Write-Host "  MODE: SD CARD -> PC"
        Write-Host "=========================================="
        Wait-ForConnection

        Write-Host "Finding SD Card ID..."
        adb shell ls /storage/
        Write-Host ""

        $sdid = Read-Host "Enter SD Card ID (e.g. 3492-12F2)"
        if ([string]::IsNullOrWhiteSpace($sdid)) { continue }
        if ($sdid -eq "0") { return }

        Write-Host ""
        Write-Host "Folders on SD Card:"
        adb shell ls -F "/storage/$sdid/"
        Write-Host ""

        $source = Read-Host "Enter Folder Path on SD Card (relative to /storage/$sdid/, e.g. DCIM or * for ALL)"
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        if ($source -eq "0") { return }

        $fullSource = "/storage/$sdid/$source"
        $dest = Remove-WrappingQuotes (Read-Host "Destination path on this computer")
        if ([string]::IsNullOrWhiteSpace($dest)) { continue }

        Write-Host ""
        Write-Host "Transferring..."
        adb pull "$fullSource" "$dest"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Transfer failed." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            continue
        }

        Ask-RepeatPull -Mode "sd"
        return
    }
}

function Start-PushInternal {
    while ($true) {
        Clear-Host
        Write-Host "=========================================="
        Write-Host "  MODE: PC -> PHONE INTERNAL"
        Write-Host "=========================================="
        Wait-ForConnection

        $source = Remove-WrappingQuotes (Read-Host "Source path on this computer (file or folder)")
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        if ($source -eq "0") { return }

        Write-Host ""
        Write-Host "Where to put it on phone? (Default: /sdcard/)"
        Write-Host "Common: /sdcard/Movies/ or /sdcard/Download/"
        $dest = Remove-WrappingQuotes (Read-Host "Phone Dest (Enter for root)")
        if ([string]::IsNullOrWhiteSpace($dest)) { $dest = "/sdcard/" }

        Write-Host ""
        Write-Host "Pushing..."
        adb push "$source" "$dest"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Transfer failed." -ForegroundColor Red
            Read-Host "Press Enter to continue"
            continue
        }

        Ask-RepeatPush -Mode "internal"
        return
    }
}

function Start-PushSd {
    while ($true) {
        Clear-Host
        Write-Host "=========================================="
        Write-Host "  MODE: PC -> SD CARD"
        Write-Host "=========================================="
        Wait-ForConnection

        Write-Host "[!] NOTE: Android 11+ often blocks writing to SD via ADB."
        Write-Host ""

        $sdid = Read-Host "Enter SD Card ID (from option 1)"
        if ([string]::IsNullOrWhiteSpace($sdid)) { continue }
        if ($sdid -eq "0") { return }

        $source = Remove-WrappingQuotes (Read-Host "Source path on this computer")
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        if ($source -eq "0") { return }

        Write-Host ""
        Write-Host "Pushing..."
        adb push "$source" "/storage/$sdid/"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Transfer failed." -ForegroundColor Red
            Write-Host "[!] Writing to SD card may be blocked on this device/Android version." -ForegroundColor Yellow
            Read-Host "Press Enter to continue"
            continue
        }

        Ask-RepeatPush -Mode "sd"
        return
    }
}

Clear-Host
Write-Host "Starting ADB Server..."
if (-not (Test-AdbAvailable)) {
    Write-Host "[!] adb was not found in PATH." -ForegroundColor Red
    Write-Host "Install platform-tools or add adb to PATH, then try again."
    exit 1
}

adb start-server *> $null
Wait-ForConnection

while ($true) {
    Clear-Host
    Write-Host "===================================================="
    Write-Host "     ADB TRANSFER TOOL V1.0 (CONNECTED)"
    Write-Host "===================================================="
    Write-Host "Device ID:"
    adb devices -l | Select-String "\sdevice\s"
    Write-Host "===================================================="
    Write-Host ""
    Write-Host "[1] List Files/Folders (Explore Phone)"
    Write-Host ""
    Write-Host "--- EXPORT (Phone -> PC) ---"
    Write-Host "[2] Phone Internal -> PC"
    Write-Host "[3] Phone SD Card  -> PC"
    Write-Host ""
    Write-Host "--- IMPORT (PC -> Phone) ---"
    Write-Host "[4] PC -> Phone Internal"
    Write-Host "[5] PC -> Phone SD Card"
    Write-Host ""
    Write-Host "[0] EXIT"
    Write-Host "===================================================="

    $opt = Read-Host "Select Option"

    switch ($opt) {
        "1" { Show-Explorer }
        "2" { Start-PullInternal }
        "3" { Start-PullSd }
        "4" { Start-PushInternal }
        "5" { Start-PushSd }
        "0" { break }
        default { }
    }
}
