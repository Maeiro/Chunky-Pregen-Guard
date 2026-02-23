# Chunky Pregen Guard

Chunky Pregen Guard is a small powershell app to run Chunky pre-generation more safely on modded servers that may hit memory spikes or OOM (`OutOfMemoryError`).

Main usage mode:
- GUI (simple setup + one-click start).

Single-file behavior:
- You can use only `ChunkyPregenGuard.exe` in your server folder.
- If required files are missing, the app creates them automatically (for example `chunky-autorestart.ps1`).

Advanced/alternative mode:
- Direct PowerShell script execution.

## Why This Exists
Chunky pre-generation can cause aggressive memory growth in some modpacks, especially with problematic worldgen mods.

Without automation, admins often do a manual loop:
1. run pregen;
2. stop server when memory gets critical;
3. start server again and resume Chunky.

Chunky Pregen Guard automates this workflow so restarts are more predictable and configurable.

## Project Components
- `chunky-pregen-guard.ps1`: GUI launcher/configurator script.
- `start-chunky-pregen-guard.bat`: starts GUI script mode quickly.
- `build-exe.ps1`: builds the GUI executable.
- `dist/ChunkyPregenGuard/ChunkyPregenGuard.exe`: packaged GUI executable.

Important runtime dependency:
- `chunky-autorestart.ps1` (server supervisor script) is created/updated automatically in your server root by the launcher when needed.

## What The GUI Provides
- UI language: `pt-BR` and `English`.
- Recommended presets based on detected system RAM.
- JVM profile options (`Balanced`, `Aggressive pregen`, `Low RAM`).
- Memory/restart controls:
  - `Soft`, `Hard`, `PreWarn` limits.
  - Check/warmup/startup/flush/stop timers.
  - Trend mode (`hybrid`, `private`, `ws`) + ETA guards.
- Optional `user_jvm_args.txt` update.
- Command preview and `.bat` export.
- Startup diagnostics/log hints.
- One-click cleanup: `Stop Running Guard/Server` (force-stop orphan supervisor/java + stale lock/pid files).

## Requirements
- Windows PowerShell 5.1+.
- `ChunkyPregenGuard.exe` present in the server folder.
- Forge/Fabric runtime files valid in server root (`run.bat`, `win_args.txt`, etc., depending on your stack).

## Usage (EXE GUI - Recommended)
1. Open:
- `dist/ChunkyPregenGuard/ChunkyPregenGuard.exe`
- or `dist/ChunkyPregenGuard/Run-ChunkyPregenGuard.bat`
2. Configure and click `Start Server`.
3. If you suspect orphan processes, click `Stop Running Guard/Server` before starting again.

If you move only the EXE, ensure it still points to the correct server folder containing `chunky-autorestart.ps1`.

## Usage (Script GUI)
1. Run:
```bat
start-chunky-pregen-guard.bat
```
2. Adjust settings.
3. Click `Start Server`.

Optional custom root:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\chunky-pregen-guard.ps1 -ServerRoot "C:\path\to\server"
```

## Build EXE
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-exe.ps1 -Clean
```

Options:
- `-Clean`: clear `dist` before build.
- `-NoZip`: build without ZIP package.

Outputs:
- `dist/ChunkyPregenGuard/ChunkyPregenGuard.exe`
- `dist/ChunkyPregenGuard-package.zip`

## JVM Args Behavior
If `Apply JVM settings` is enabled:
- updates `user_jvm_args.txt` before startup;
- creates `user_jvm_args.txt.bak` only when content changes;
- avoids timestamp backup clutter.

## Logs and Diagnostics
- GUI launcher log: `logs/chunky-pregen-guard-ui.log`
- Supervisor log: `logs/chunky-autorestart.log`

If startup fails:
1. check server logs;
2. check `logs/chunky-autorestart.log`;
3. check `logs/chunky-pregen-guard-ui.log`.

## Manual Cleanup (Terminal)
If you need a deterministic force cleanup without opening the GUI:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\chunky-autorestart.ps1 -CleanupOnly 1
```

This mode force-stops matching Guard/server processes and removes stale lock/pid files by design.

## Quick Troubleshooting
- `Another supervisor is already active (PID=...)`:
  - another supervisor process is running;
  - stop it or enable startup cleanup.
- GUI opens but server does not start:
  - verify `chunky-autorestart.ps1` exists in server root;
  - check server logs for missing mods/dependencies.
- Antivirus blocks EXE:
  - run script mode (`start-chunky-pregen-guard.bat`) or add local exception.

## License
GNU GPL v3. See `LICENSE`.


