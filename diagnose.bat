@echo off
setlocal EnableDelayedExpansion

:: ============================================================
:: Portable Hermes - Diagnostic Check
:: Run this if Hermes fails to start after moving the drive.
:: ============================================================

set "PORTABLE_ROOT=%~dp0"
if "%PORTABLE_ROOT:~-1%"=="\" set "PORTABLE_ROOT=%PORTABLE_ROOT:~0,-1%"

echo.
echo === Portable Hermes Diagnostic ===
echo Root: %PORTABLE_ROOT%
echo.

:: Check Python runtime
if exist "%PORTABLE_ROOT%\python\python.exe" (
    echo [OK] Embedded Python found
) else (
    echo [FAIL] python\python.exe not found!
)

if exist "%PORTABLE_ROOT%\python\python311.dll" (
    echo [OK] python311.dll found
) else (
    echo [FAIL] python\python311.dll not found!
)

if exist "%PORTABLE_ROOT%\python\Lib" (
    echo [OK] Standard library (Lib) found
) else (
    echo [FAIL] python\Lib not found! Extract python311.zip into python\Lib
)

:: Check Hermes source
if exist "%PORTABLE_ROOT%\hermes\hermes-agent\hermes_cli" (
    echo [OK] Hermes source code found
) else (
    echo [FAIL] hermes\hermes-agent\hermes_cli not found!
)

:: Check venv
if exist "%PORTABLE_ROOT%\hermes\hermes-agent\venv\Scripts\hermes.exe" (
    echo [OK] Venv hermes.exe found
) else (
    echo [FAIL] hermes\hermes-agent\venv\Scripts\hermes.exe not found!
)

if exist "%PORTABLE_ROOT%\hermes\hermes-agent\venv\Lib\site-packages" (
    echo [OK] Site-packages found
) else (
    echo [FAIL] Venv site-packages not found!
)

:: Check Hermes data
if exist "%PORTABLE_ROOT%\hermes\config.yaml" (
    echo [OK] config.yaml found
) else (
    echo [WARN] hermes\config.yaml not found
)

:: Check Portable Git
if exist "%PORTABLE_ROOT%\git\bin\bash.exe" (
    echo [OK] Portable Git bash.exe found
) else (
    echo [FAIL] git\bin\bash.exe not found! Run setup-git.bat
)

if exist "%PORTABLE_ROOT%\git\cmd\git.exe" (
    for /f "tokens=*" %%v in ('"%PORTABLE_ROOT%\git\cmd\git.exe" --version 2^>nul') do echo [OK] %%v
) else (
    echo [FAIL] git\cmd\git.exe not found! Run setup-git.bat
)

:: Quick Python import test
echo.
echo --- Python Import Test ---
set "HERMES_HOME=%PORTABLE_ROOT%\hermes"
set "VIRTUAL_ENV=%PORTABLE_ROOT%\hermes\hermes-agent\venv"
set "PYTHONHOME="
set "PATH=%PORTABLE_ROOT%\hermes\hermes-agent\venv\Scripts;%PORTABLE_ROOT%\python;%PATH%"

"%PORTABLE_ROOT%\hermes\hermes-agent\venv\Scripts\python.exe" -c "import hermes_constants; print('[OK] hermes_constants imported, home:', hermes_constants.get_hermes_home())" 2>&1
if errorlevel 1 (
    echo [FAIL] Cannot import hermes_constants
)

echo.
echo === Diagnostic complete ===
pause
