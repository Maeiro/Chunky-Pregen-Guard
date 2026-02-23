# Chunky Pregen Guard

Chunky Pregen Guard is a **PowerShell-first** project for running Chunky pre-generation more safely in modded servers that may hit memory spikes or OOM (`OutOfMemoryError`).

It has two usage modes:
- Script mode (core automation via PowerShell).
- Optional GUI mode (easy configuration + launch).

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
- `chunky-autorestart.ps1` (server supervisor script) must exist in your server root. The GUI launches and configures this script.

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

## Recommended Starting Configs
Use these as a baseline and tune with real logs.

| System RAM | JVM `-Xms` / `-Xmx` | Soft / Hard / PreWarn (GB) | Notes |
|---|---|---|---|
| 16 GB | `-Xms4G -Xmx10G` | `8.3 / 9.2 / 7.3` | Prefer `Balanced` or `Low RAM`. |
| 24 GB | `-Xms5G -Xmx13G` | `10.8 / 12.0 / 9.5` | Good default for mixed modpacks. |
| 32 GB | `-Xms6G -Xmx16G` | `13.3 / 14.7 / 11.7` | Usually stable for longer pregen sessions. |
| 64 GB | `-Xms10G -Xmx24G` | `19.9 / 22.1 / 17.5` | Start with `Balanced`; try `Aggressive` if stable. |

Default operational suggestions:
- `CheckIntervalSec=30`
- `AdaptiveLeadMinMinutes=2`
- `AdaptiveLeadMaxMinutes=4`
- `ProjectionMinRamPrivateGB=14`
- `TrendSourceMode=hybrid`

## Requirements
- Windows PowerShell 5.1+.
- `chunky-autorestart.ps1` present in the server folder.
- Forge/Fabric runtime files valid in server root (`run.bat`, `win_args.txt`, etc., depending on your stack).

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

## Usage (EXE GUI)
1. Open:
- `dist/ChunkyPregenGuard/ChunkyPregenGuard.exe`
- or `dist/ChunkyPregenGuard/Run-ChunkyPregenGuard.bat`
2. Configure and click `Start Server`.

If you move only the EXE, ensure it still points to the correct server folder containing `chunky-autorestart.ps1`.

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
MIT. See `LICENSE`.
