@echo off
:: ================================================================
:: setup-openfolder-protocol.bat
:: One-click installer for the openfolder:// custom URI protocol.
:: Run this ONCE on each HR user's Windows PC.
:: No admin rights required (registers in HKEY_CURRENT_USER).
:: ================================================================

setlocal EnableDelayedExpansion

echo.
echo  ============================================
echo   HR System — Open Folder Protocol Setup
echo  ============================================
echo.

:: Step 1: Create tools directory
set "TOOLS_DIR=C:\HR-Tools"
if not exist "%TOOLS_DIR%" (
    mkdir "%TOOLS_DIR%"
    echo  [OK] Created folder: %TOOLS_DIR%
) else (
    echo  [OK] Folder already exists: %TOOLS_DIR%
)

:: Step 2: Copy the PowerShell handler next to this batch file
set "SCRIPT_SRC=%~dp0OpenHRFolder.ps1"
set "SCRIPT_DST=%TOOLS_DIR%\OpenHRFolder.ps1"

if not exist "%SCRIPT_SRC%" (
    echo.
    echo  [ERROR] OpenHRFolder.ps1 not found next to this batch file.
    echo  Make sure both files are in the same folder and try again.
    echo.
    pause
    exit /b 1
)

copy /Y "%SCRIPT_SRC%" "%SCRIPT_DST%" >nul
echo  [OK] Copied handler to: %SCRIPT_DST%

:: Step 3: Register the openfolder:// protocol in HKCU (no admin needed)
set "REG_ROOT=HKCU\Software\Classes\openfolder"
set "CMD_VALUE=powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%SCRIPT_DST%\" \"%%1\""

reg add "%REG_ROOT%"                       /ve /d "URL:HR Open Folder Protocol" /f >nul
reg add "%REG_ROOT%"                       /v "URL Protocol" /d "" /f              >nul
reg add "%REG_ROOT%\DefaultIcon"           /ve /d "explorer.exe,0" /f              >nul
reg add "%REG_ROOT%\shell\open\command"    /ve /d "%CMD_VALUE%" /f                 >nul

echo  [OK] Registered openfolder:// protocol in Windows Registry
echo.
echo  ============================================
echo   Setup complete!
echo.
echo   You can now click "Open Folder" in the
echo   HR system and it will open Windows Explorer
echo   directly — no more copy/paste needed.
echo  ============================================
echo.
pause
