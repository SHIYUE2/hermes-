#!/usr/bin/env pwsh
# ============================================================
# Portable Hermes Launcher (PowerShell)
# Runs Hermes from a portable drive without installation.
# ============================================================

$ErrorActionPreference = "Stop"

# Resolve the directory where this script lives
$PortableRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Define key paths
$PortablePython = Join-Path $PortableRoot "python"
$HermesData    = Join-Path $PortableRoot "hermes"
$HermesAgent   = Join-Path $HermesData "hermes-agent"
$Venv          = Join-Path $HermesAgent "venv"
$VenvPyCfg     = Join-Path $Venv "pyvenv.cfg"

# ── Patch pyvenv.cfg with current Python path ──────────────
$cfgContent = @"
home = $PortablePython
implementation = CPython
uv = 0.11.21
version_info = 3.11.9
include-system-site-packages = false
"@
Set-Content -Path $VenvPyCfg -Value $cfgContent -Encoding ASCII

# ── Set environment variables ──────────────────────────────
$env:HERMES_HOME               = $HermesData
$env:VIRTUAL_ENV               = $Venv
$env:VIRTUAL_ENV_PROMPT        = "(hermes) "
$env:PYTHONHOME                = $null
$env:PYTHONPATH                = $null
$env:UV_NO_UPDATE              = "1"
$env:PIP_DISABLE_PIP_VERSION_CHECK = "1"

$venvScripts = Join-Path $Venv "Scripts"
$binDir      = Join-Path $HermesData "bin"
$env:PATH = "$venvScripts;$PortablePython;$binDir;$env:PATH"

# ── Launch Hermes ──────────────────────────────────────────
$pythonExe    = Join-Path $venvScripts "python.exe"
$launchScript = Join-Path $HermesAgent "_portable_launch.py"
& $pythonExe $launchScript @args
exit $LASTEXITCODE
