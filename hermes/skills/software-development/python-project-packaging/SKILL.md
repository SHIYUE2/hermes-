---
name: python-project-packaging
description: Package a Python project into a self-contained deployable folder — clone, analyze, strip build deps, write single-file web UI, bat launcher.
---

Packaging a Python project for standalone deployment on end-user machines. Use when the task is: "把这个项目打包到一个文件夹里，写网页界面，用 bat 启动" or any request to create a zero-setup deployable package from a Python repo.

## Core principle

The end user should only need: **Python 3.10+ installed, double-click one bat file.** No git, no node, no build toolchain, no manual config.

## Step-by-step workflow

### 1. Clone the repo

```bash
git clone <url> <temp_dir>
```

### 2. Analyze structure

Read `pyproject.toml` or `setup.py` to understand:
- Python version requirement
- Dependencies (core vs optional extras)
- Entry points (console_scripts, CLI commands)
- Build backend (hatchling/setuptools/poetry)

Check if there's a separate frontend (React/TypeScript) — if so, the goal is to REPLACE it with single-file HTML, not build it. Building a JS frontend requires node/npm which defeats standalone deployment.

### 3. Export clean source (no git metadata)

```bash
cd <temp_dir>
git archive --format=tar HEAD | tar -C <deploy_dir>/<pkg_name> --strip-components=1 -xf - <pkg_name>/
```

Also copy top-level files: `pyproject.toml`, `README.md`, `LICENSE`.

### 4. Create requirements.txt

Extract dependencies from `pyproject.toml` into a flat `requirements-web.txt`. Include only what's needed for the web deploy mode. Skip dev dependencies and build backends.

### 5. Write single-file HTML pages (vanilla JS, no framework)

Single `.html` files with inline CSS + inline JS. No React/Vue/Angular — the user shouldn't need npm. Structure:

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>...</title>
  <style>/* all CSS here */</style>
</head>
<body>
  <!-- HTML structure -->
  <script>/* all JS here */</script>
</body>
</html>
```

Key patterns for the JS:
- Global `const API = ''` for the base URL (same-origin)
- `async function api(url, opts)` wrapper around fetch with error handling
- Toast notification for user feedback
- SSE via `new EventSource()` for real-time streams
- No build step, no bundler, no npm

Typical pages to create:
- **index.html** — Dashboard: health check, task list, target input, command type selector, quick-start button
- **chat.html** — SSE stream viewer: task selection, real-time event display, connect/disconnect
- **settings.html** — Config editor: provider selector with presets, model/API key/base URL, runtime params, Python sandbox toggles, POST to `/api/config`

### 6. Create Windows bat launcher

```batch
@echo off
chcp 65001 >nul
title <App Name>

set "DEPLOY_DIR=%~dp0"
cd /d "%DEPLOY_DIR%"

:: 1. Check Python
where python >nul 2>&1 || (echo Need Python 3.10+ && pause && exit /b 1)

:: 2. Create venv
set "VENV_DIR=%DEPLOY_DIR%.venv"
if not exist "%VENV_DIR%\Scripts\python.exe" python -m venv "%VENV_DIR%"

:: 3. Activate + install deps
call "%VENV_DIR%\Scripts\activate.bat"
where uv >nul 2>&1 && (uv pip install -r requirements-web.txt --quiet) || (pip install -r requirements-web.txt --quiet)

:: 4. Start server + open browser
start "" /b cmd /c "timeout /t 2 /nobreak >nul && start http://127.0.0.1:<port>"
python -m uvicorn <pkg>.<module>:create_app --factory --host 127.0.0.1 --port <port> --log-level info
pause
```

Key decisions:
- **uv** first (much faster on Windows), **pip** fallback
- **127.0.0.1 only** (security — don't expose to LAN by default)
- `--factory` flag for uvicorn when `create_app()` returns the app object
- `start "" /b cmd /c "timeout ... && start http://..."` to open browser after server starts
- `chcp 65001` for Chinese character support in terminal
- `set "DEPLOY_DIR=%~dp0"` to resolve the bat file's own directory

### 7. Create config template

Write `config.yaml.example` with commented defaults so the user knows what can be configured. The actual config should auto-generate on first run.

## Pitfalls

1. **`pip install -e .` fails without build backend** — Don't use editable installs in standalone packages. Use flat `requirements.txt` instead.
2. **React/TS frontend needs node** — Don't build it. Replace with single-file HTML pages.
3. **Permission-denied files in git clones** — Use `git archive` instead of `cp -r`; it strips git metadata and avoids permission issues.
4. **Windows paths in bat** — Always quote paths with spaces, use `%~dp0` for relative resolution, avoid trailing backslashes.
5. **Terminal tool blocked for long python imports** — Don't test-import on the bare system Python; dependencies go in the venv that the bat creates.

## Verification

After creating the package, list the files to confirm:
```bash
find <deploy_dir>/<pkg_name> -name "*.py" | wc -l  # Python source count
ls <deploy_dir>/<pkg_name>/web/static/              # Web pages
ls <deploy_dir>/                                    # Bat + requirements + config
```
