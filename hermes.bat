@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: Portable Hermes Launcher
:: Runs Hermes from a portable drive without installation.
:: ============================================================

:: Resolve the directory where this script lives
set "PORTABLE_ROOT=%~dp0"
:: Remove trailing backslash
if "%PORTABLE_ROOT:~-1%"=="\" set "PORTABLE_ROOT=%PORTABLE_ROOT:~0,-1%"

:: Define key paths
set "PORTABLE_PYTHON=%PORTABLE_ROOT%\python"
set "HERMES_DATA=%PORTABLE_ROOT%\hermes"
set "HERMES_AGENT=%PORTABLE_ROOT%\hermes\hermes-agent"
set "VENV=%HERMES_AGENT%\venv"
set "VENV_PYCFG=%VENV%\pyvenv.cfg"

:: ── Patch pyvenv.cfg with current Python path ──────────────
:: This handles drive letter changes on portable drives.
set "NEW_HOME=home = %PORTABLE_PYTHON%"
set "TEMP_CFG=%VENV_PYCFG%.tmp"

(
    echo %NEW_HOME%
    echo implementation = CPython
    echo uv = 0.11.21
    echo version_info = 3.11.9
    echo include-system-site-packages = false
) > "%TEMP_CFG%"
move /y "%TEMP_CFG%" "%VENV_PYCFG%" >nul 2>&1

:: ── Set environment variables ──────────────────────────────
set "HERMES_HOME=%HERMES_DATA%"
set "VIRTUAL_ENV=%VENV%"
set "VIRTUAL_ENV_PROMPT=(hermes) "
set "PYTHONHOME="
set "PYTHONPATH="
set "PATH=%VENV%\Scripts;%PORTABLE_PYTHON%;%PORTABLE_ROOT%\hermes\bin;%PATH%"

:: Disable uv/pip update nags
set "UV_NO_UPDATE=1"
set "PIP_DISABLE_PIP_VERSION_CHECK=1"

:: Isolate Electron userData so portable instance doesn't conflict with
:: any system-installed Hermes via the single-instance lock.
set "HERMES_DESKTOP_USER_DATA_DIR=%PORTABLE_ROOT%\hermes\desktop-data"

:: ── Resolve Git Bash (bash.exe) ─────────────────────────────
:: The Hermes desktop client requires bash.exe on Windows.
:: Search order: portable git → Qoder-bundled git → system install → PATH.
set "GIT_BIN="

:: 1. Portable Git bundled with Hermes (git\bin\bash.exe next to hermes.bat)
if not defined GIT_BIN if exist "%PORTABLE_ROOT%\git\bin\bash.exe" set "GIT_BIN=%PORTABLE_ROOT%\git\bin"
if not defined GIT_BIN if exist "%PORTABLE_ROOT%\git\usr\bin\bash.exe" set "GIT_BIN=%PORTABLE_ROOT%\git\usr\bin"

:: 2. Qoder CLI bundled Git
if not defined GIT_BIN if exist "%USERPROFILE%\.qoder\bin\git\usr\bin\bash.exe" set "GIT_BIN=%USERPROFILE%\.qoder\bin\git\usr\bin"
if not defined GIT_BIN if exist "%USERPROFILE%\.qoder\bin\git\bin\bash.exe" set "GIT_BIN=%USERPROFILE%\.qoder\bin\git\bin"

:: 3. Standard Git for Windows install locations
if not defined GIT_BIN if exist "%ProgramFiles%\Git\bin\bash.exe" set "GIT_BIN=%ProgramFiles%\Git\bin"
if not defined GIT_BIN if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GIT_BIN=%ProgramFiles(x86)%\Git\bin"
if not defined GIT_BIN if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "GIT_BIN=%LOCALAPPDATA%\Programs\Git\bin"
if not defined GIT_BIN if exist "%LOCALAPPDATA%\hermes\git\bin\bash.exe" set "GIT_BIN=%LOCALAPPDATA%\hermes\git\bin"

:: Prepend to PATH so the Electron app's findOnPath('bash') picks it up.
if defined GIT_BIN set "PATH=%GIT_BIN%;%PATH%"

:: Also add git.exe to PATH (hermes backend needs it for self-update).
:: Search for cmd\git.exe relative to GIT_BIN (up two levels) or known locations.
set "GIT_CMD="
if defined GIT_BIN (
    for %%d in ("%GIT_BIN%\..\..") do if exist "%%~fd\cmd\git.exe" set "GIT_CMD=%%~fd\cmd"
)
if not defined GIT_CMD if exist "%PORTABLE_ROOT%\git\cmd\git.exe" set "GIT_CMD=%PORTABLE_ROOT%\git\cmd"
if not defined GIT_CMD if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_CMD=%ProgramFiles%\Git\cmd"
if defined GIT_CMD set "PATH=%GIT_CMD%;%PATH%"

if not defined GIT_BIN (
    echo [WARNING] Git Bash ^(bash.exe^) not found. Hermes desktop client requires it.
    echo   Place PortableGit in: %PORTABLE_ROOT%\git\
    echo   Or install Git for Windows: https://git-scm.com/download/win
    echo   Or run: winget install -e --id Git.Git
)

:: ── Launch Hermes Desktop ─────────────────────────────────
:: Start the Electron desktop GUI client.
set "HERMES_DESKTOP=%HERMES_AGENT%\apps\desktop\release\win-unpacked\Hermes.exe"
if exist "%HERMES_DESKTOP%" (
    start "" "%HERMES_DESKTOP%" %*
    set "EXIT_CODE=0"
) else (
    echo [ERROR] Desktop client not found at: %HERMES_DESKTOP%
    echo Falling back to CLI mode...
    "%VENV%\Scripts\python.exe" "%HERMES_AGENT%\_portable_launch.py" %*
    set "EXIT_CODE=%ERRORLEVEL%"
)

endlocal
exit /b %EXIT_CODE%
