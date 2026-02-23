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
    [string]$ManagedPidFile = "logs/chunky-autorestart.server.pid",
    [switch]$GuiMode,
    [int]$StopExistingServer = 1,
    [int]$CleanupOnly = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-ParentDirectory {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return
    }
    $dir = Split-Path -Path $FilePath -Parent
    if ([string]::IsNullOrWhiteSpace($dir)) {
        return
    }
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Resolve-WinArgsFile {
    $defaultPath = "libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt"
    if (Test-Path -Path $defaultPath) {
        return $defaultPath
    }

    $autoWinArgs = Get-ChildItem -Path "libraries/net/minecraftforge/forge" -Recurse -Filter "win_args.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $autoWinArgs) {
        return $null
    }

    return $autoWinArgs.FullName.Replace((Get-Location).Path + [System.IO.Path]::DirectorySeparatorChar, "")
}

Ensure-ParentDirectory -FilePath $LogFile
Ensure-ParentDirectory -FilePath $LockFile
Ensure-ParentDirectory -FilePath $ManagedPidFile

$resolvedWinArgsFile = Resolve-WinArgsFile
if (($CleanupOnly -ne 1) -and (-not (Test-Path -Path "user_jvm_args.txt"))) {
    throw "user_jvm_args.txt not found in current directory."
}
if (($CleanupOnly -ne 1) -and [string]::IsNullOrWhiteSpace($resolvedWinArgsFile)) {
    throw "Forge win_args.txt file not found."
}

$script:WinArgsMatchTokens = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($resolvedWinArgsFile)) {
    $script:WinArgsMatchTokens.Add("@$resolvedWinArgsFile")
    try {
        $absWinArgs = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $resolvedWinArgsFile))
        $script:WinArgsMatchTokens.Add("@$absWinArgs")
    } catch {
    }
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

function Stop-ProcessForceSafe {
    param(
        [int]$ProcessId,
        [string]$LogMessage = ""
    )

    if ($ProcessId -le 0) {
        return $false
    }

    $target = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $target) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($LogMessage)) {
        Write-Log $LogMessage
    }

    try {
        $target.Kill($true)
    } catch {
        try {
            Stop-Process -Id $ProcessId -Force -ErrorAction Stop
        } catch {
            Write-Log "Failed to stop process (PID=$ProcessId): $($_.Exception.Message)"
            return $false
        }
    }

    Start-Sleep -Milliseconds 700
    if ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
        Write-Log "Process still running after force-stop attempt (PID=$ProcessId)."
        return $false
    }

    return $true
}

function Stop-OtherSupervisors {
    param([array]$SupervisorProcesses)
    foreach ($p in @($SupervisorProcesses)) {
        if ($null -eq $p) {
            continue
        }
        $stopOk = Stop-ProcessForceSafe -ProcessId ([int]$p.ProcessId) -LogMessage "Stopping old supervisor (PID=$($p.ProcessId)) to avoid duplication."
        if (-not $stopOk) {
            $stillAlive = Get-Process -Id ([int]$p.ProcessId) -ErrorAction SilentlyContinue
            if ($null -ne $stillAlive) {
                throw "Failed to stop old supervisor (PID=$($p.ProcessId))."
            }
        }
    }
}

function Get-ManagedPidFromFile {
    if (-not (Test-Path -Path $ManagedPidFile)) {
        return $null
    }

    try {
        $raw = (Get-Content -Path $ManagedPidFile -ErrorAction Stop | Select-Object -First 1).Trim()
        if ($raw -match '^\d+$') {
            return [int]$raw
        }
    } catch {
    }

    return $null
}

function Write-ManagedPidFile {
    param($serverState)

    if ($null -eq $serverState) {
        return
    }

    $proc = $null
    if ($serverState -is [hashtable] -and $serverState.ContainsKey("Process")) {
        $proc = $serverState.Process
    }
    if ($null -eq $proc) {
        return
    }

    try {
        Set-Content -Path $ManagedPidFile -Value $proc.Id -Encoding ASCII
    } catch {
        Write-Log "Failed to update managed PID file: $($_.Exception.Message)"
    }
}

function Clear-ManagedPidFile {
    if (Test-Path -Path $ManagedPidFile) {
        Remove-Item -Path $ManagedPidFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-ManagedJavaProcesses {
    $procList = Get-CimInstance Win32_Process -Filter "name='java.exe'" -ErrorAction SilentlyContinue
    if ($null -eq $procList) {
        return @()
    }

    $results = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $cwd = (Get-Location).Path

    foreach ($item in $procList) {
        $cmd = [string]$item.CommandLine
        if ([string]::IsNullOrWhiteSpace($cmd)) {
            continue
        }

        $isMatch = $false
        foreach ($token in $script:WinArgsMatchTokens) {
            if (-not [string]::IsNullOrWhiteSpace($token) -and $cmd.Contains($token)) {
                $isMatch = $true
                break
            }
        }

        if (-not $isMatch -and ($cmd -match '@"?user_jvm_args\.txt"?')) {
            if ([string]::IsNullOrWhiteSpace($cwd) -or $cmd.Contains($cwd)) {
                $isMatch = $true
            }
        }

        if (-not $isMatch) {
            continue
        }

        $proc = Get-Process -Id $item.ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $proc) {
            continue
        }

        if (-not $seen.ContainsKey($proc.Id)) {
            $seen[$proc.Id] = $true
            $results.Add($proc)
        }
    }

    return $results.ToArray()
}

function Stop-ManagedJavaProcesses {
    param(
        [array]$Processes,
        [switch]$ManualCleanup
    )

    [int]$stoppedCount = 0
    foreach ($proc in @($Processes)) {
        if ($null -eq $proc) {
            continue
        }

        $processId = [int]$proc.Id
        if ($processId -le 0) {
            continue
        }

        $message = if ($ManualCleanup) {
            "ManualCleanup stopping managed Java PID=$processId"
        } else {
            "Stopping existing server (PID=$processId) to take over supervision."
        }

        $stopped = Stop-ProcessForceSafe -ProcessId $processId -LogMessage $message
        if ($stopped) {
            $stoppedCount++
        }

        if ((-not $ManualCleanup) -and ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue))) {
            throw "Failed to stop existing server (PID=$processId)."
        }
    }

    return $stoppedCount
}

function Cleanup-ResidualManagedJava {
    param(
        [string]$Context = "ResidualCleanup",
        [int]$WaitSeconds = 6
    )

    $waitUntil = (Get-Date).AddSeconds([Math]::Max(0, $WaitSeconds))
    while ((Get-Date) -lt $waitUntil) {
        $stillRunning = @(Get-ManagedJavaProcesses)
        if (@($stillRunning).Count -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 500
    }

    $residual = @(Get-ManagedJavaProcesses)
    if (@($residual).Count -eq 0) {
        return
    }

    $pidList = ($residual | ForEach-Object { $_.Id }) -join ","
    Write-Log "${Context}: residual managed Java detected ($pidList). Forcing cleanup."
    $null = Stop-ManagedJavaProcesses -Processes $residual -ManualCleanup
    Start-Sleep -Seconds 1

    $afterForce = @(Get-ManagedJavaProcesses)
    if (@($afterForce).Count -gt 0) {
        $stillList = ($afterForce | ForEach-Object { $_.Id }) -join ","
        Write-Log "${Context}: residual managed Java still running after force cleanup ($stillList)."
    } else {
        Write-Log "${Context}: residual managed Java cleanup successful."
    }
}

function Start-Server {
    if ([string]::IsNullOrWhiteSpace($resolvedWinArgsFile)) {
        throw "Forge win_args.txt file not found."
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "java"
    $javaArgs = "@user_jvm_args.txt @$resolvedWinArgsFile"
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
    if ($null -eq $serverState) {
        return
    }
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

function Stop-ManagedServerOnExit {
    param([string]$Reason = "Supervisor exiting")

    $state = $script:ManagedServerState
    if ($null -eq $state) {
        Clear-ManagedPidFile
        return
    }

    $proc = $null
    if ($state -is [hashtable] -and $state.ContainsKey("Process")) {
        $proc = $state.Process
    }

    if ($null -eq $proc) {
        Clear-ManagedPidFile
        return
    }

    $stillRunning = $false
    try {
        $stillRunning = -not $proc.HasExited
    } catch {
        $stillRunning = $null -ne (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)
    }

    if ($stillRunning) {
        Write-Log "$Reason. Stopping managed server (PID=$($proc.Id))."
        $null = Stop-ProcessForceSafe -ProcessId $proc.Id
    }

    Clear-ManagedPidFile
}

function Invoke-ManualCleanup {
    Write-Log "ManualCleanup started"

    [int]$supervisorStopped = 0
    [int]$javaStopped = 0

    $otherSupervisors = @(Get-OtherSupervisors)
    foreach ($p in $otherSupervisors) {
        if ($null -eq $p) {
            continue
        }
        if (Stop-ProcessForceSafe -ProcessId ([int]$p.ProcessId) -LogMessage "ManualCleanup stopping supervisor PID=$($p.ProcessId)") {
            $supervisorStopped++
        }
    }

    $seenJavaPids = @{}
    $managedJava = @(Get-ManagedJavaProcesses)
    foreach ($proc in $managedJava) {
        if ($null -eq $proc) {
            continue
        }
        $processId = [int]$proc.Id
        $seenJavaPids[$processId] = $true
        if (Stop-ProcessForceSafe -ProcessId $processId -LogMessage "ManualCleanup stopping managed Java PID=$processId") {
            $javaStopped++
        }
    }

    $pidFromFile = Get-ManagedPidFromFile
    if (($null -ne $pidFromFile) -and (-not $seenJavaPids.ContainsKey($pidFromFile))) {
        if (Stop-ProcessForceSafe -ProcessId $pidFromFile -LogMessage "ManualCleanup stopping managed Java PID=$pidFromFile (from pid file)") {
            $javaStopped++
        }
    }

    $removedAny = $false
    if (Test-Path -Path $LockFile) {
        Remove-Item -Path $LockFile -Force -ErrorAction SilentlyContinue
        $removedAny = $true
    }
    if (Test-Path -Path $ManagedPidFile) {
        Remove-Item -Path $ManagedPidFile -Force -ErrorAction SilentlyContinue
        $removedAny = $true
    }
    if ($removedAny) {
        Write-Log "ManualCleanup removed lock/managed-pid files"
    } else {
        Write-Log "ManualCleanup found no lock/managed-pid files to remove"
    }

    Write-Log "ManualCleanup finished. supervisorsStopped=$supervisorStopped managedJavaStopped=$javaStopped"
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
        $forceOk = Stop-ProcessForceSafe -ProcessId $proc.Id -LogMessage "ShutdownPhase: force_kill PID=$($proc.Id)"
        if (-not $forceOk) {
            Write-Log "Force kill did not confirm process exit (PID=$($proc.Id))."
        }
    }
}

if ($CleanupOnly -eq 1) {
    Invoke-ManualCleanup
    exit 0
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

$script:ManagedServerState = $null
$server = $null
$exitEventSub = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    try {
        $state = $script:ManagedServerState
        if ($null -eq $state) {
            return
        }

        $proc = $null
        if ($state -is [hashtable] -and $state.ContainsKey("Process")) {
            $proc = $state.Process
        }
        if ($null -eq $proc) {
            return
        }

        if (-not $proc.HasExited) {
            $line = "[{0}] Supervisor exiting. Stopping managed server (PID={1})." -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $proc.Id
            Add-Content -Path $using:LogFile -Value $line
            try {
                $proc.Kill($true)
            } catch {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            }
        }

        if (Test-Path -Path $using:ManagedPidFile) {
            Remove-Item -Path $using:ManagedPidFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
    }
}

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

    $alreadyRunning = @(Get-ManagedJavaProcesses)
    $pidFromFile = Get-ManagedPidFromFile
    if ($null -ne $pidFromFile) {
        $fromFileProc = Get-Process -Id $pidFromFile -ErrorAction SilentlyContinue
        if ($null -ne $fromFileProc) {
            $alreadyHasPid = $false
            foreach ($p in $alreadyRunning) {
                if ($p.Id -eq $pidFromFile) {
                    $alreadyHasPid = $true
                    break
                }
            }
            if (-not $alreadyHasPid) {
                $alreadyRunning += $fromFileProc
            }
        }
    }

    if (@($alreadyRunning).Count -gt 0) {
        if ($StopExistingServer) {
            $null = Stop-ManagedJavaProcesses -Processes $alreadyRunning
            Clear-ManagedPidFile
        } else {
            throw "There is already a server java process running (PID=$($alreadyRunning[0].Id)). Stop the current server and run the .bat again."
        }
    }

    $server = Start-Server
    $script:ManagedServerState = $server
    Write-ManagedPidFile -serverState $server
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
            Clear-ManagedPidFile
            Cleanup-Events -serverState $server
            Start-Sleep -Seconds 10
            Cleanup-ResidualManagedJava -Context "RestartAfterExit"

            $server = Start-Server
            $script:ManagedServerState = $server
            Write-ManagedPidFile -serverState $server
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
            Clear-ManagedPidFile
            Cleanup-Events -serverState $server
            Cleanup-ResidualManagedJava -Context "PostStopBeforeRestart"

            Write-Log "Restarting server in 10 s."
            Start-Sleep -Seconds 10

            $server = Start-Server
            $script:ManagedServerState = $server
            Write-ManagedPidFile -serverState $server
            $memorySamples = New-Object System.Collections.Generic.List[double]
            $consecutiveAboveThreshold = 0

            Write-Log "Server restarted (PID=$($server.Process.Id)). Waiting $StartupDelaySec s."
            Start-Sleep -Seconds $StartupDelaySec
            Send-ResumeCommands -serverState $server
        }
    }
}
finally {
    try { Stop-ManagedServerOnExit -Reason "Supervisor shutdown" } catch {}
    try { Cleanup-Events -serverState $server } catch {}
    if ($null -ne $exitEventSub) {
        Unregister-Event -SubscriptionId $exitEventSub.Id -ErrorAction SilentlyContinue
        Remove-Job -Id $exitEventSub.Id -Force -ErrorAction SilentlyContinue
    }
    Clear-ManagedPidFile
    if (Test-Path -Path $LockFile) {
        Remove-Item -Path $LockFile -Force -ErrorAction SilentlyContinue
    }
}
