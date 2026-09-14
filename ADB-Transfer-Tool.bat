@echo off
setlocal EnableDelayedExpansion
TITLE ADB Ultimate Transfer Tool V1.0
COLOR 0A

:: ====================================================
:: INITIALIZATION
:: ====================================================
cls
echo Starting ADB Server...
adb version >nul 2>&1
if errorlevel 1 (
    COLOR 0C
    echo [!] adb was not found in PATH.
    echo Install platform-tools or add adb to PATH, then try again.
    pause
    exit /b 1
)
adb start-server >nul 2>&1

:CHECK_CONNECTION
adb get-state >nul 2>&1
if errorlevel 1 goto DEVICE_NOT_FOUND

adb devices | findstr /R "\<device\>" >nul
if errorlevel 1 goto DEVICE_NOT_FOUND

goto MENU

:DEVICE_NOT_FOUND
COLOR 0C
cls
echo ====================================================
echo [!] NO ACTIVE DEVICE DETECTED
echo ====================================================
echo.
echo STATUS: Waiting for connection...
echo.
echo TROUBLESHOOTING:
echo 1. Unplug and Replug USB cable.
echo 2. Check phone screen for "Allow USB Debugging?" popup.
echo 3. Ensure the device is authorized and set to a supported USB mode.
echo.
echo Press Ctrl+C to quit or wait 3 seconds to retry...
timeout /t 3 /nobreak >nul
goto CHECK_CONNECTION

:: ====================================================
:: MAIN MENU
:: ====================================================
:MENU
adb get-state >nul 2>&1
if errorlevel 1 goto DEVICE_NOT_FOUND

COLOR 0A
cls
echo ====================================================
echo      ADB TRANSFER TOOL V1.0 (CONNECTED)
echo ====================================================
echo Device ID:
adb devices -l | findstr /R "\<device\>"
echo ====================================================
echo.
echo [1] List Files/Folders (Explore Phone)
echo.
echo --- EXPORT (Phone -to- PC) ---
echo [2] Phone Internal -to- PC
echo [3] Phone SD Card  -to- PC
echo.
echo --- IMPORT (PC -to- Phone) ---
echo [4] PC -to- Phone Internal
echo [5] PC -to- Phone SD Card
echo.
echo [0] EXIT
echo ====================================================
set "opt="
set /p opt="Select Option: "

if "%opt%"=="1" goto EXPLORE
if "%opt%"=="2" goto PULL_INT
if "%opt%"=="3" goto PULL_SD
if "%opt%"=="4" goto PUSH_INT
if "%opt%"=="5" goto PUSH_SD
if "%opt%"=="0" exit /b
goto MENU

:: ====================================================
:: HELPERS & EXPLORER
:: ====================================================

:EXPLORE
cls
echo --- FILE EXPLORER ---
echo [1] Internal Storage (/sdcard/)
echo [2] SD Card (/storage/...)
echo [0] Back to Menu
echo.
set "exopt="
set /p exopt="Select: "

if "%exopt%"=="0" goto MENU
if "%exopt%"=="1" (
    echo Listing /sdcard/...
    adb shell ls -F /sdcard/
    echo.
    pause
    goto EXPLORE
)
if "%exopt%"=="2" (
    echo Listing /storage/...
    adb shell ls /storage/
    echo.
    echo Note your SD Card ID (e.g., 1234-5678)
    pause
    goto EXPLORE
)
goto EXPLORE

:: ====================================================
:: TRANSFER LOGIC
:: ====================================================

:PULL_INT
cls
echo ==========================================
echo   MODE: PHONE INTERNAL -TO- PC
echo ==========================================
adb get-state >nul 2>&1
if errorlevel 1 goto DEVICE_NOT_FOUND

echo Current Folders in Internal Storage:
adb shell ls -d /sdcard/*/
echo ==========================================
echo Tip: Type "0" to go back.
echo.

:PULL_INT_PROMPT
set "source="
set /p source="Enter Folder Path on Phone (relative to /sdcard/, e.g. DCIM or DCIM/Camera): "
if "%source%"=="" goto PULL_INT_PROMPT
if "%source%"=="0" goto MENU

set "full_source=/sdcard/%source%"

echo.
echo Paste PC Destination Path (Right click folder -> Copy as path):
set "dest="
set /p dest="Destination: "
set "dest=%dest:"=%"
if "%dest%"=="" (
    echo [!] Error: No path provided.
    pause
    goto PULL_INT_PROMPT
)

echo.
echo Transferring ["%full_source%"] to ["%dest%"]...
adb pull "%full_source%" "%dest%"
if errorlevel 1 (
    echo [!] Transfer failed.
    pause
    goto PULL_INT_PROMPT
)
goto ASK_REPEAT_PULL

:PULL_SD
cls
echo ==========================================
echo   MODE: SD CARD -TO- PC
echo ==========================================
adb get-state >nul 2>&1
if errorlevel 1 goto DEVICE_NOT_FOUND

echo Finding SD Card ID...
adb shell ls /storage/
echo.

:PULL_SD_PROMPT
set "sdid="
set /p sdid="Enter SD Card ID (e.g. 3492-12F2): "
if "%sdid%"=="" goto PULL_SD_PROMPT
if "%sdid%"=="0" goto MENU

echo.
echo Folders on SD Card:
adb shell ls -F "/storage/%sdid%/"
echo.
set "source="
set /p source="Enter Folder Path on SD Card (relative to /storage/%sdid%/, e.g. DCIM or * for ALL): "
if "%source%"=="" goto PULL_SD_PROMPT
if "%source%"=="0" goto MENU

set "full_source=/storage/%sdid%/%source%"

echo.
echo Paste PC Destination Path:
set "dest="
set /p dest="Destination: "
set "dest=%dest:"=%"
if "%dest%"=="" goto PULL_SD_PROMPT

echo.
echo Transferring...
adb pull "%full_source%" "%dest%"
if errorlevel 1 (
    echo [!] Transfer failed.
    pause
    goto PULL_SD_PROMPT
)
goto ASK_REPEAT_PULL

:PUSH_INT
cls
echo ==========================================
echo   MODE: PC -TO- PHONE INTERNAL
echo ==========================================
adb get-state >nul 2>&1
if errorlevel 1 goto DEVICE_NOT_FOUND

echo Paste PC Source Path (File or Folder):
set "source="
set /p source="Source: "
set "source=%source:"=%"
if "%source%"=="" goto PUSH_INT
if "%source%"=="0" goto MENU

echo.
echo Where to put it on phone? (Default: /sdcard/)
echo Common: /sdcard/Movies/ or /sdcard/Download/
set "dest="
set /p dest="Phone Dest (Enter for root): "
set "dest=%dest:"=%"
if "%dest%"=="" set "dest=/sdcard/"

echo.
echo Pushing...
adb push "%source%" "%dest%"
if errorlevel 1 (
    echo [!] Transfer failed.
    pause
    goto PUSH_INT
)
goto ASK_REPEAT_PUSH

:PUSH_SD
cls
echo ==========================================
echo   MODE: PC -TO- SD CARD
echo ==========================================
adb get-state >nul 2>&1
if errorlevel 1 goto DEVICE_NOT_FOUND

echo [!] NOTE: Android 11+ often blocks writing to SD via ADB.
echo.

:PUSH_SD_PROMPT
set "sdid="
set /p sdid="Enter SD Card ID (from option 1): "
if "%sdid%"=="" goto PUSH_SD_PROMPT
if "%sdid%"=="0" goto MENU

echo Paste PC Source Path:
set "source="
set /p source="Source: "
set "source=%source:"=%"
if "%source%"=="" goto PUSH_SD_PROMPT
if "%source%"=="0" goto MENU

echo.
echo Pushing...
adb push "%source%" "/storage/%sdid%/"
if errorlevel 1 (
    echo [!] Transfer failed.
    echo [!] Writing to SD card may be blocked on this device/Android version.
    pause
    goto PUSH_SD_PROMPT
)
goto ASK_REPEAT_PUSH

:: ====================================================
:: REPEAT LOOPS
:: ====================================================

:ASK_REPEAT_PULL
echo.
echo ==========================================
echo [1] Transfer ANOTHER file in this mode
echo [2] Return to Main Menu
echo ==========================================
set "choice="
set /p choice="Choose: "
if "%choice%"=="1" goto PULL_INT
goto MENU

:ASK_REPEAT_PUSH
echo.
echo ==========================================
echo [1] Transfer ANOTHER file in this mode
echo [2] Return to Main Menu
echo ==========================================
set "choice="
set /p choice="Choose: "
if "%choice%"=="1" goto PUSH_INT
goto MENU
