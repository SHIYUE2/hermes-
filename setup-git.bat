@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: Setup PortableGit for Hermes Portable
:: Downloads and extracts PortableGit into the git\ dir.
:: ============================================================

set "PORTABLE_ROOT=%~dp0"
if "%PORTABLE_ROOT:~-1%"=="\" set "PORTABLE_ROOT=%PORTABLE_ROOT:~0,-1%"

set "GIT_DIR=%PORTABLE_ROOT%\git"

if exist "%GIT_DIR%\bin\bash.exe" (
    echo [OK] PortableGit already installed at: %GIT_DIR%
    echo      Run hermes.bat to launch Hermes.
    goto :done
)

echo ============================================================
echo  Hermes Portable - Git Setup
echo ============================================================
echo.
echo This will download PortableGit and extract it to:
echo   %GIT_DIR%
echo.
set /p CONFIRM="Continue? [Y/n]: "
if /i "!CONFIRM!"=="n" (
    echo Cancelled.
    goto :done
)

echo.
echo [1/5] Finding latest PortableGit release...

:: Use PowerShell to query GitHub API for latest release URL and size
for /f "usebackq tokens=1,2 delims=|" %%a in (`powershell -NoProfile -Command ^
    "$asset = (Invoke-RestMethod 'https://api.github.com/repos/git-for-windows/git/releases/latest') ^
    | Select-Object -ExpandProperty assets ^
    | Where-Object { $_.name -match 'PortableGit.*64-bit.*\.7z\.exe$' } ^
    | Select-Object -First 1; ^
    if ($asset) { Write-Output ('{0}|{1}' -f $asset.browser_download_url, $asset.size) }"`) do (
    set "DOWNLOAD_URL=%%a"
    set "EXPECTED_SIZE=%%b"
)

if not defined DOWNLOAD_URL (
    echo [ERROR] Could not find PortableGit download URL.
    echo         Visit https://git-scm.com/download/win to download manually.
    echo         Extract to: %GIT_DIR%
    goto :done
)

echo        URL:  !DOWNLOAD_URL!
echo        Size: !EXPECTED_SIZE! bytes

set "DOWNLOAD_FILE=%PORTABLE_ROOT%\PortableGit-installer.7z.exe"

echo [2/5] Downloading...
:: Try curl first (more reliable for large files), fall back to PowerShell
where curl >nul 2>&1
if not errorlevel 1 (
    echo        Using curl...
    curl -L -o "!DOWNLOAD_FILE!" "!DOWNLOAD_URL!" --progress-bar
) else (
    echo        Using PowerShell...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '!DOWNLOAD_FILE!' -UseBasicParsing"
)
if errorlevel 1 (
    echo [ERROR] Download failed.
    goto :done
)

:: Verify download size
for %%A in ("!DOWNLOAD_FILE!") do set "ACTUAL_SIZE=%%~zA"
if defined EXPECTED_SIZE if "!ACTUAL_SIZE!" neq "!EXPECTED_SIZE!" (
    echo [ERROR] Download incomplete: expected !EXPECTED_SIZE! bytes, got !ACTUAL_SIZE! bytes.
    echo         Please check your network connection and try again.
    goto :cleanup
)

echo [3/5] Extracting to %GIT_DIR%...
:: The .7z.exe is a self-extracting archive; run with -o flag for output dir
"!DOWNLOAD_FILE!" -o"%GIT_DIR%" -y >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Extraction failed.
    echo         Installer kept at: !DOWNLOAD_FILE!
    echo         Try extracting manually.
    goto :done
)

echo [4/5] Running post-install...
if exist "%GIT_DIR%\post-install.bat" (
    pushd "%GIT_DIR%"
    call post-install.bat >nul 2>&1
    popd
)

echo [5/5] Verifying...
if exist "%GIT_DIR%\bin\bash.exe" (
    echo.
    echo [OK] PortableGit installed successfully!
    echo      bash.exe: %GIT_DIR%\bin\bash.exe
    echo      git.exe:  %GIT_DIR%\cmd\git.exe
    echo.
    echo Run hermes.bat to launch Hermes.
) else (
    echo [ERROR] bash.exe not found after extraction.
    echo         Installer kept at: !DOWNLOAD_FILE!
    echo         Try extracting manually.
    goto :done
)

:cleanup
if exist "!DOWNLOAD_FILE!" del "!DOWNLOAD_FILE!" >nul 2>&1

:done
endlocal
pause
