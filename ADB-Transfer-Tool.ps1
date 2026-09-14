$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'ADB Ultimate Transfer Tool V1.0'
$Host.UI.RawUI.ForegroundColor = 'Green'

function Test-AdbAvailable {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        Write-Host '[!] adb was not found in PATH.' -ForegroundColor Red
        Write-Host 'Install Android platform-tools or add adb to PATH, then try again.'
        Pause
        exit 1
    }
}

function Test-DeviceConnected {
    try {
        adb get-state *> $null
        $stateOk = $LASTEXITCODE -eq 0
        if (-not $stateOk) { return $false }

        $devices = adb devices
        return ($devices -split "`n" | Where-Object { $_ -match "\sdevice\s*$" }).Count -gt 0
    } catch {
        return $false
    }
}

function Wait-ForDevice {
    Clear-Host
    Write-Host '====================================================' -ForegroundColor Red
    Write-Host '[!] NO ACTIVE DEVICE DETECTED' -ForegroundColor Red
    Write-Host '====================================================' -ForegroundColor Red
    Write-Host ''
    Write-Host 'STATUS: Waiting for connection...'
    Write-Host ''
    Write-Host 'TROUBLESHOOTING:'
    Write-Host '1. Unplug and replug USB cable.'
    Write-Host '2. Check phone screen for "Allow USB Debugging?" popup.'
    Write-Host '3. Ensure the device is authorized and set to a supported USB mode.'
    Write-Host ''
    Write-Host 'Press Ctrl+C to quit or wait 3 seconds to retry...'
    Start-Sleep -Seconds 3
}

function Read-Trimmed([string]$Prompt) {
    return ((Read-Host $Prompt) -replace '^"|"$', '').Trim()
}

function Show-Menu {
    Clear-Host
    Write-Host '====================================================' -ForegroundColor Green
    Write-Host '     ADB TRANSFER TOOL V1.0 (CONNECTED)'
    Write-Host '====================================================' -ForegroundColor Green
    Write-Host 'Device ID:'
    adb devices -l | Select-String '\bdevice\b' | ForEach-Object { Write-Host $_.Line }
    Write-Host '====================================================' -ForegroundColor Green
    Write-Host ''
    Write-Host '[1] List Files/Folders (Explore Phone)'
    Write-Host ''
    Write-Host '--- EXPORT (Phone -to- PC) ---'
    Write-Host '[2] Phone Internal -to- PC'
    Write-Host '[3] Phone SD Card  -to- PC'
    Write-Host ''
    Write-Host '--- IMPORT (PC -to- Phone) ---'
    Write-Host '[4] PC -to- Phone Internal'
    Write-Host '[5] PC -to- Phone SD Card'
    Write-Host ''
    Write-Host '[0] EXIT'
    Write-Host '====================================================' -ForegroundColor Green
}

function Explore {
    while ($true) {
        Clear-Host
        Write-Host '--- FILE EXPLORER ---'
        Write-Host '[1] Internal Storage (/sdcard/)'
        Write-Host '[2] SD Card (/storage/...)'
        Write-Host '[0] Back to Menu'
        Write-Host ''
        $exopt = Read-Host 'Select'
        switch ($exopt) {
            '0' { return }
            '1' {
                Write-Host 'Listing /sdcard/...'
                adb shell ls -F /sdcard/
                Pause
            }
            '2' {
                Write-Host 'Listing /storage/...'
                adb shell ls /storage/
                Write-Host ''
                Write-Host 'Note your SD Card ID (e.g., 1234-5678)'
                Pause
            }
        }
    }
}

function Pull-Internal {
    while ($true) {
        Clear-Host
        Write-Host '=========================================='
        Write-Host '  MODE: PHONE INTERNAL -TO- PC'
        Write-Host '=========================================='
        if (-not (Test-DeviceConnected)) { Wait-ForDevice; return }
        Write-Host 'Current Folders in Internal Storage:'
        adb shell ls -d /sdcard/*/
        Write-Host '=========================================='
        Write-Host 'Tip: Type "0" to go back.'
        Write-Host ''
        $source = Read-Trimmed 'Enter Folder Path on Phone (relative to /sdcard/, e.g. DCIM or DCIM/Camera)'
        if (-not $source) { continue }
        if ($source -eq '0') { return }
        $fullSource = "/sdcard/$source"
        $dest = Read-Trimmed 'Destination (PC path)'
        if (-not $dest) { Write-Host '[!] Error: No path provided.'; Pause; continue }
        Write-Host ''
        Write-Host "Transferring [$fullSource] to [$dest]..."
        adb pull $fullSource $dest
        if ($LASTEXITCODE -ne 0) { Write-Host '[!] Transfer failed.'; Pause; continue }
        if (-not (Ask-RepeatPull)) { return }
    }
}

function Pull-SD {
    while ($true) {
        Clear-Host
        Write-Host '=========================================='
        Write-Host '  MODE: SD CARD -TO- PC'
        Write-Host '=========================================='
        if (-not (Test-DeviceConnected)) { Wait-ForDevice; return }
        Write-Host 'Finding SD Card ID...'
        adb shell ls /storage/
        Write-Host ''
        $sdid = Read-Trimmed 'Enter SD Card ID (e.g. 3492-12F2)'
        if (-not $sdid) { continue }
        if ($sdid -eq '0') { return }
        Write-Host ''
        Write-Host 'Folders on SD Card:'
        adb shell ls -F "/storage/$sdid/"
        Write-Host ''
        $source = Read-Trimmed "Enter Folder Path on SD Card (relative to /storage/$sdid/, e.g. DCIM or * for ALL)"
        if (-not $source) { continue }
        if ($source -eq '0') { return }
        $fullSource = "/storage/$sdid/$source"
        $dest = Read-Trimmed 'Destination (PC path)'
        if (-not $dest) { continue }
        Write-Host ''
        Write-Host 'Transferring...'
        adb pull $fullSource $dest
        if ($LASTEXITCODE -ne 0) { Write-Host '[!] Transfer failed.'; Pause; continue }
        if (-not (Ask-RepeatPull)) { return }
    }
}

function Push-Internal {
    while ($true) {
        Clear-Host
        Write-Host '=========================================='
        Write-Host '  MODE: PC -TO- PHONE INTERNAL'
        Write-Host '=========================================='
        if (-not (Test-DeviceConnected)) { Wait-ForDevice; return }
        $source = Read-Trimmed 'Source (PC path)'
        if (-not $source) { continue }
        if ($source -eq '0') { return }
        Write-Host ''
        Write-Host 'Where to put it on phone? (Default: /sdcard/)'
        Write-Host 'Common: /sdcard/Movies/ or /sdcard/Download/'
        $dest = Read-Trimmed 'Phone Dest (Enter for root)'
        if (-not $dest) { $dest = '/sdcard/' }
        Write-Host ''
        Write-Host 'Pushing...'
        adb push $source $dest
        if ($LASTEXITCODE -ne 0) { Write-Host '[!] Transfer failed.'; Pause; continue }
        if (-not (Ask-RepeatPush)) { return }
    }
}

function Push-SD {
    while ($true) {
        Clear-Host
        Write-Host '=========================================='
        Write-Host '  MODE: PC -TO- SD CARD'
        Write-Host '=========================================='
        if (-not (Test-DeviceConnected)) { Wait-ForDevice; return }
        Write-Host '[!] NOTE: Android 11+ often blocks writing to SD via ADB.'
        Write-Host ''
        $sdid = Read-Trimmed 'Enter SD Card ID (from option 1)'
        if (-not $sdid) { continue }
        if ($sdid -eq '0') { return }
        $source = Read-Trimmed 'Source (PC path)'
        if (-not $source) { continue }
        if ($source -eq '0') { return }
        Write-Host ''
        Write-Host 'Pushing...'
        adb push $source "/storage/$sdid/"
        if ($LASTEXITCODE -ne 0) {
            Write-Host '[!] Transfer failed.'
            Write-Host '[!] Writing to SD card may be blocked on this device/Android version.'
            Pause
            continue
        }
        if (-not (Ask-RepeatPush)) { return }
    }
}

function Ask-RepeatPull {
    Write-Host ''
    Write-Host '=========================================='
    Write-Host '[1] Transfer ANOTHER file in this mode'
    Write-Host '[2] Return to Main Menu'
    Write-Host '=========================================='
    $choice = Read-Host 'Choose'
    return $choice -eq '1'
}

function Ask-RepeatPush {
    Write-Host ''
    Write-Host '=========================================='
    Write-Host '[1] Transfer ANOTHER file in this mode'
    Write-Host '[2] Return to Main Menu'
    Write-Host '=========================================='
    $choice = Read-Host 'Choose'
    return $choice -eq '1'
}

Test-AdbAvailable
adb start-server *> $null

while ($true) {
    if (-not (Test-DeviceConnected)) {
        Wait-ForDevice
        continue
    }

    Show-Menu
    $opt = Read-Host 'Select Option'
    switch ($opt) {
        '1' { Explore }
        '2' { Pull-Internal }
        '3' { Pull-SD }
        '4' { Push-Internal }
        '5' { Push-SD }
        '0' { exit }
    }
}
