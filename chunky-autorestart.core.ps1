# Chunky Pregen Guard Core v3
param(
    [double]$MaxMemoryGB = 18,
    [double]$HardMemoryGB = 22,
    [double]$PreWarnMemoryGB = 17.5,
    [int]$CheckIntervalSec = 30,
    [int]$WarmupSec = 180,
    [int]$StartupDelaySec = 60,
    [int]$StopTimeoutSec = 180,
    [int]$AverageWindowChecks = 10,
    [int]$MinConsecutiveAboveThreshold = 4,
    [int]$FlushSettleSec = 15,
    [int]$StopGraceSec = 20,
    [double]$ProjectionMinRamPrivateGB = 14.0,
    [int]$LowEtaConsecutiveChecks = 3,
    [int]$AdaptiveLeadMinMinutes = 2,
    [int]$AdaptiveLeadMaxMinutes = 4,
    [ValidateSet("private", "ws", "hybrid")]
    [string]$TrendSourceMode = "hybrid",
    [int]$PreWarnProjectionEnabled = 1,
    [int]$BroadcastEnabled = 1,
    [string]$BroadcastPrefix = "[AutoRestart]",
    [string]$ResumeCommands = "chunky continue",
    [string]$LogFile = "logs/chunky-autorestart.log",
    [string]$LockFile = "logs/chunky-autorestart.lock",
    [switch]$GuiMode,
    [int]$StopExistingServer = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path "user_jvm_args.txt")) {
    throw "user_jvm_args.txt not found in current directory."
}

$winArgsFile = "libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt"
if (-not (Test-Path -Path $winArgsFile)) {
    $autoWinArgs = Get-ChildItem -Path "libraries/net/minecraftforge/forge" -Recurse -Filter "win_args.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -ne $autoWinArgs) {
        $winArgsFile = $autoWinArgs.FullName.Replace((Get-Location).Path + [System.IO.Path]::DirectorySeparatorChar, "")
    }
}
if (-not (Test-Path -Path $winArgsFile)) {
    throw "Forge win_args.txt file not found."
}

$logDir = Split-Path -Path $LogFile -Parent
if ($logDir -and -not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$resumeCommandList = $ResumeCommands.Split(";") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
$avgWindow = [Math]::Max(1, $AverageWindowChecks)

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    $line | Tee-Object -FilePath $LogFile -Append
}

function Get-OtherSupervisors {
    $scriptName = [System.IO.Path]::GetFileName($PSCommandPath)
    if (-not $scriptName) {
        return @()
    }

    $procList = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -match '^powershell(\.exe)?$|^pwsh(\.exe)?$') -and
        $_.CommandLine -and
        $_.CommandLine.Contains($scriptName) -and
        $_.ProcessId -ne $PID
    }

    return @($procList)
}

function Stop-OtherSupervisors {
    param([array]$SupervisorProcesses)
    foreach ($p in $SupervisorProcesses) {
        Write-Log "Stopping old supervisor (PID=$($p.ProcessId)) to avoid duplication."
        try {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
        } catch {
            throw "Failed to stop old supervisor (PID=$($p.ProcessId)): $($_.Exception.Message)"
        }
    }
}

function Get-ManagedJavaProcess {
    $procList = Get-CimInstance Win32_Process -Filter "name='java.exe'" -ErrorAction SilentlyContinue
    if ($null -eq $procList) {
        return $null
    }

    $match = $procList | Where-Object {
        $_.CommandLine -and $_.CommandLine.Contains("@$winArgsFile")
    } | Select-Object -First 1

    if ($null -eq $match) {
        return $null
    }

    return Get-Process -Id $match.ProcessId -ErrorAction SilentlyContinue
}

function Stop-ManagedJavaProcess {
    param([System.Diagnostics.Process]$Process)
    if ($null -eq $Process) {
        return
    }

    if ($Process.HasExited) {
        return
    }

    Write-Log "Stopping existing server (PID=$($Process.Id)) to take over supervision."
    try {
        Stop-Process -Id $Process.Id -Force -ErrorAction Stop
        Start-Sleep -Seconds 3
    } catch {
        throw "Failed to stop existing server (PID=$($Process.Id)): $($_.Exception.Message)"
    }
}

function Start-Server {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "java"
    $javaArgs = "@user_jvm_args.txt @$winArgsFile"
    if (-not $GuiMode) {
        $javaArgs = "$javaArgs nogui"
    }
    $psi.Arguments = $javaArgs
    $psi.WorkingDirectory = (Get-Location).Path
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.EnableRaisingEvents = $true

    $null = $process.Start()

    $outEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($EventArgs.Data) {
            $timestamped = "[{0}] [SERVER] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $EventArgs.Data
            Add-Content -Path $using:LogFile -Value $timestamped
        }
    }
    $errEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) {
            $timestamped = "[{0}] [SERVER-ERR] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $EventArgs.Data
            Add-Content -Path $using:LogFile -Value $timestamped
        }
    }

    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    return @{
        Process = $process
        OutEvent = $outEvent
        ErrEvent = $errEvent
        StartedAt = Get-Date
    }
}

function Cleanup-Events {
    param($serverState)
    foreach ($evt in @($serverState.OutEvent, $serverState.ErrEvent)) {
        if ($null -ne $evt) {
            Unregister-Event -SubscriptionId $evt.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $evt.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Send-ResumeCommands {
    param($serverState)
    foreach ($cmd in $resumeCommandList) {
        try {
            $serverState.Process.StandardInput.WriteLine($cmd)
            Write-Log "Command sent after server start: $cmd"
        } catch {
            Write-Log "Failed to send command after server start: $cmd"
        }
        Start-Sleep -Seconds 1
    }
}

function Graceful-Stop {
    param($serverState, [string]$Reason)

    $proc = $serverState.Process
    if ($proc.HasExited) {
        return
    }

    $graceSeconds = if ($StopGraceSec -gt 0) { $StopGraceSec } else { [Math]::Max(5, $StopTimeoutSec) }

    Write-Log "Requesting stop: $Reason"

    if ($BroadcastEnabled) {
        try { $proc.StandardInput.WriteLine("say $BroadcastPrefix Automatic restart now for memory stability.") } catch {}
    }

    Write-Log "ShutdownPhase: chunky_pause"
    try { $proc.StandardInput.WriteLine("chunky pause") } catch {}
    Start-Sleep -Seconds 2

    Write-Log "ShutdownPhase: save_flush"
    try { $proc.StandardInput.WriteLine("save-all flush") } catch {}
    if ($FlushSettleSec -gt 0) {
        Start-Sleep -Seconds $FlushSettleSec
    }

    Write-Log "ShutdownPhase: stop_sent"
    try { $proc.StandardInput.WriteLine("stop") } catch {}

    if (-not $proc.WaitForExit($graceSeconds * 1000)) {
        Write-Log "Graceful stop exceeded timeout of ${graceSeconds}s. Forcing shutdown."
        Write-Log "ShutdownPhase: force_kill"
        try { $proc.Kill($true) } catch {}
    }
}

Write-Log "Supervisor started. RAM limit=$MaxMemoryGB GB; interval=$CheckIntervalSec s; warmup=$WarmupSec s; gui=$($GuiMode.IsPresent)"
Write-Log "RAM policy: soft(avg+sustained)=$MaxMemoryGB GB; hard(peak)=$HardMemoryGB GB; window=$AverageWindowChecks checks; consecutive=$MinConsecutiveAboveThreshold"
Write-Log "Resume commands: $($resumeCommandList -join ' | ')"

if (Test-Path -Path $LockFile) {
    $existingPid = (Get-Content -Path $LockFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
    if ($existingPid -match '^\d+$') {
        $existingProc = Get-Process -Id ([int]$existingPid) -ErrorAction SilentlyContinue
        if ($existingProc) {
            throw "There is already an active supervisor (PID=$existingPid). Close it before starting another."
        }
    }
}

Set-Content -Path $LockFile -Value $PID

try {
    $otherSupervisors = @(Get-OtherSupervisors)
    if (@($otherSupervisors).Count -gt 0) {
        if ($StopExistingServer) {
            Stop-OtherSupervisors -SupervisorProcesses $otherSupervisors
        } else {
            $pids = ($otherSupervisors | ForEach-Object { $_.ProcessId }) -join ","
            throw "There is another active supervisor (PID=$pids)."
        }
    }

    $alreadyRunning = Get-ManagedJavaProcess
    if ($alreadyRunning) {
        if ($StopExistingServer) {
            Stop-ManagedJavaProcess -Process $alreadyRunning
        } else {
            throw "There is already a server java process running (PID=$($alreadyRunning.Id)). Stop the current server and run the .bat again."
        }
    }

    $server = Start-Server
    $memorySamples = New-Object System.Collections.Generic.List[double]
    $consecutiveAboveThreshold = 0

    Write-Log "Server started (PID=$($server.Process.Id)). Waiting $StartupDelaySec s before resuming Chunky."
    Start-Sleep -Seconds $StartupDelaySec
    Send-ResumeCommands -serverState $server

    while ($true) {
        Start-Sleep -Seconds $CheckIntervalSec

        $proc = $server.Process
        if ($proc.HasExited) {
            Write-Log "Java process exited (code=$($proc.ExitCode)). Restarting in 10 s."
            Cleanup-Events -serverState $server
            Start-Sleep -Seconds 10

            $server = Start-Server
            $memorySamples = New-Object System.Collections.Generic.List[double]
            $consecutiveAboveThreshold = 0

            Write-Log "Server restarted (PID=$($server.Process.Id)). Waiting $StartupDelaySec s."
            Start-Sleep -Seconds $StartupDelaySec
            Send-ResumeCommands -serverState $server
            continue
        }

        $uptimeSec = [int]((Get-Date) - $server.StartedAt).TotalSeconds
        $liveProc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($null -eq $liveProc) {
            Write-Log "Healthcheck: PID=$($proc.Id) process not found. Waiting next check."
            continue
        }

        $memoryWsGB = [math]::Round($liveProc.WorkingSet64 / 1GB, 3)
        $memoryPrivateGB = [math]::Round($liveProc.PrivateMemorySize64 / 1GB, 3)
        $memoryEffectiveGB = [math]::Round([Math]::Max($memoryWsGB, $memoryPrivateGB), 3)

        $memorySamples.Add($memoryEffectiveGB)
        while ($memorySamples.Count -gt $avgWindow) {
            $memorySamples.RemoveAt(0)
        }

        $avgMemoryGB = [math]::Round((($memorySamples | Measure-Object -Average).Average), 3)
        if ($memoryEffectiveGB -ge $MaxMemoryGB) {
            $consecutiveAboveThreshold++
        } else {
            $consecutiveAboveThreshold = 0
        }

        Write-Log "Healthcheck: PID=$($proc.Id) RAM_WS=$memoryWsGB GB RAM_PRIVATE=$memoryPrivateGB GB RAM_EFFECTIVE=$memoryEffectiveGB GB AVG_EFFECTIVE=$avgMemoryGB GB AboveSoftSeq=$consecutiveAboveThreshold Uptime=${uptimeSec}s"

        if ($uptimeSec -lt $WarmupSec) {
            continue
        }

        $shouldRestartByHard = $memoryEffectiveGB -ge $HardMemoryGB
        $shouldRestartBySoft = ($avgMemoryGB -ge $MaxMemoryGB) -and ($consecutiveAboveThreshold -ge $MinConsecutiveAboveThreshold)

        if ($shouldRestartByHard -or $shouldRestartBySoft) {
            $reason = if ($shouldRestartByHard) {
                "RAM spike: effective=$memoryEffectiveGB GB (ws=$memoryWsGB GB; private=$memoryPrivateGB GB; hard=$HardMemoryGB GB)"
            } else {
                "Sustained RAM: effective=$memoryEffectiveGB GB, avg=$avgMemoryGB GB (soft=$MaxMemoryGB GB)"
            }

            Graceful-Stop -serverState $server -Reason $reason
            Cleanup-Events -serverState $server

            Write-Log "Restarting server in 10 s."
            Start-Sleep -Seconds 10

            $server = Start-Server
            $memorySamples = New-Object System.Collections.Generic.List[double]
            $consecutiveAboveThreshold = 0

            Write-Log "Server restarted (PID=$($server.Process.Id)). Waiting $StartupDelaySec s."
            Start-Sleep -Seconds $StartupDelaySec
            Send-ResumeCommands -serverState $server
        }
    }
}
finally {
    if (Test-Path -Path $LockFile) {
        Remove-Item -Path $LockFile -Force -ErrorAction SilentlyContinue
    }
}

