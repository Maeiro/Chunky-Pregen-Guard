# Chunky Pregen Guard Core v3
param(
    [double]$MaxMemoryGB = 18,
    [double]$HardMemoryGB = 22,
    [double]$PreWarnMemoryGB = 17.5,
    [int]$CheckIntervalSec = 10,
    [int]$WarmupSec = 180,
    [int]$StartupDelaySec = 10,
    [int]$MaxStartupDelaySec = 60,
    [int]$RestartDelaySec = 3,
    [int]$StopTimeoutSec = 180,
    [int]$AverageWindowChecks = 10,
    [int]$MinConsecutiveAboveThreshold = 4,
    [double]$SoftTriggerEffectiveMarginGB = 1.0,
    [int]$FlushSettleSec = 15,
    [int]$StopGraceSec = 20,
    [int]$KillVerifyTimeoutSec = 8,
    [int]$KillVerifyPollMs = 300,
    [double]$ProjectionMinRamPrivateGB = 14.0,
    [int]$LowEtaConsecutiveChecks = 3,
    [int]$AdaptiveLeadMinMinutes = 2,
    [int]$AdaptiveLeadMaxMinutes = 4,
    [ValidateSet("private", "ws", "hybrid")]
    [string]$TrendSourceMode = "hybrid",
    [int]$UseReadySignalForResume = 1,
    [string]$ServerReadyPattern = 'Done \(.*\)! For help, type "help"',
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
$checkIntervalSecEffective = [Math]::Max(1, $CheckIntervalSec)
$minResumeDelaySec = [Math]::Max(0, $StartupDelaySec)
$maxResumeDelaySec = if ($UseReadySignalForResume -eq 1) { [Math]::Max($minResumeDelaySec, $MaxStartupDelaySec) } else { $minResumeDelaySec }
$restartDelaySecEffective = [Math]::Max(0, $RestartDelaySec)
$softEffectiveThresholdGB = [Math]::Round($MaxMemoryGB + [Math]::Max(0, $SoftTriggerEffectiveMarginGB), 3)
$killVerifyTimeoutSecEffective = [Math]::Max(1, $KillVerifyTimeoutSec)
$killVerifyPollMsEffective = [Math]::Max(100, $KillVerifyPollMs)

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    $line | Tee-Object -FilePath $LogFile -Append | Out-Host
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
        return $true
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

    if (Wait-ProcessExit -ProcessId $ProcessId -TimeoutSec $killVerifyTimeoutSecEffective -PollMs $killVerifyPollMsEffective) {
        return $true
    }

    Write-Log "Kill() did not stop process in ${killVerifyTimeoutSecEffective}s. Trying taskkill fallback (PID=$ProcessId)."
    try {
        & taskkill /PID $ProcessId /T /F | Out-Null
    } catch {
        Write-Log "taskkill failed (PID=$ProcessId): $($_.Exception.Message)"
    }

    if (Wait-ProcessExit -ProcessId $ProcessId -TimeoutSec $killVerifyTimeoutSecEffective -PollMs $killVerifyPollMsEffective) {
        return $true
    }

    Write-Log "Process still running after force-stop attempt (PID=$ProcessId)."
    return $false
}

function Wait-ProcessExit {
    param(
        [int]$ProcessId,
        [int]$TimeoutSec,
        [int]$PollMs
    )

    if ($ProcessId -le 0) {
        return $true
    }

    $timeout = [Math]::Max(1, $TimeoutSec)
    $poll = [Math]::Max(100, $PollMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        if ($null -eq (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
            return $true
        }
        Start-Sleep -Milliseconds $poll
    }

    return $null -eq (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
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
            $now = Get-Date
            $timestamped = "[{0}] [SERVER] {1}" -f ($now.ToString("yyyy-MM-dd HH:mm:ss")), $EventArgs.Data
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

function Test-ServerReadySignalInLog {
    param($serverState)

    if ($UseReadySignalForResume -ne 1) {
        return $false
    }

    if ($null -eq $serverState) {
        return $false
    }

    $startedAt = $null
    if ($serverState -is [hashtable] -and $serverState.ContainsKey("StartedAt")) {
        $startedAt = $serverState.StartedAt
    }
    if ($null -eq $startedAt) {
        $startedAt = Get-Date
    }

    try {
        $tailLines = Get-Content -Path $LogFile -Tail 600 -ErrorAction SilentlyContinue
        foreach ($line in @($tailLines)) {
            if ($line -notmatch '^\\[(?<ts>\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})\\]\\s\\[SERVER\\]\\s(?<msg>.*)$') {
                continue
            }

            $lineTs = [datetime]::ParseExact($Matches.ts, 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
            if ($lineTs -lt $startedAt.AddSeconds(-1)) {
                continue
            }

            if ($Matches.msg -match $ServerReadyPattern) {
                return $true
            }
        }
    } catch {
    }

    return $false
}

function Send-ResumeCommands {
    param($serverState)

    $waitStart = Get-Date
    $resumeReason = "fallback_timeout"
    $readyLogged = $false

    while ($true) {
        if ($serverState.Process.HasExited) {
            Write-Log "Resume skipped: server process exited before resume commands."
            return [pscustomobject]@{
                Sent = $false
                ResumedAt = $null
                Reason = "fallback_timeout"
                WaitSec = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
            }
        }

        $elapsedSec = ((Get-Date) - $waitStart).TotalSeconds
        $readyDetected = ($UseReadySignalForResume -eq 1) -and (Test-ServerReadySignalInLog -serverState $serverState)
        if ($readyDetected -and (-not $readyLogged)) {
            Write-Log "ResumeReadySignal: matched readiness pattern in server log."
            $readyLogged = $true
        }
        if ($readyDetected -and ($elapsedSec -ge $minResumeDelaySec)) {
            $resumeReason = "ready_signal"
            break
        }

        if ($elapsedSec -ge $maxResumeDelaySec) {
            $resumeReason = "fallback_timeout"
            break
        }

        Start-Sleep -Milliseconds 250
    }

    $waitSec = [math]::Round(((Get-Date) - $waitStart).TotalSeconds, 1)
    Write-Log "ResumeReason: $resumeReason; wait_sec=$waitSec; min_delay_sec=$minResumeDelaySec; max_delay_sec=$maxResumeDelaySec"

    $resumeSent = $false
    $resumedAt = $null
    foreach ($cmd in $resumeCommandList) {
        try {
            $serverState.Process.StandardInput.WriteLine($cmd)
            if (-not $resumeSent) {
                $resumedAt = Get-Date
            }
            $resumeSent = $true
            Write-Log "Command sent after server start: $cmd"
        } catch {
            Write-Log "Failed to send command after server start: $cmd"
        }
        Start-Sleep -Seconds 1
    }

    return [pscustomobject]@{
        Sent = $resumeSent
        ResumedAt = $resumedAt
        Reason = $resumeReason
        WaitSec = $waitSec
    }
}

function Resolve-ResumeResult {
    param($Value)

    if ($null -eq $Value) {
        return [pscustomobject]@{ Sent = $false; ResumedAt = $null; Reason = "unknown"; WaitSec = 0 }
    }

    if ($Value -is [array]) {
        $candidate = $Value |
            Where-Object { $_ -is [psobject] -and ($_.PSObject.Properties.Name -contains "Sent") } |
            Select-Object -Last 1
        if ($null -ne $candidate) {
            return $candidate
        }
    } elseif ($Value -is [psobject] -and ($Value.PSObject.Properties.Name -contains "Sent")) {
        return $Value
    }

    return [pscustomobject]@{ Sent = $false; ResumedAt = $null; Reason = "invalid_result"; WaitSec = 0 }
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

Write-Log "Supervisor started. RAM limit=$MaxMemoryGB GB; interval=$checkIntervalSecEffective s; warmup=$WarmupSec s; gui=$($GuiMode.IsPresent)"
Write-Log "RAM policy: soft(avg+sustained)=$MaxMemoryGB GB; hard(peak)=$HardMemoryGB GB; window=$AverageWindowChecks checks; consecutive=$MinConsecutiveAboveThreshold"
Write-Log "Startup policy: readySignal=$UseReadySignalForResume; minDelay=${minResumeDelaySec}s; maxDelay=${maxResumeDelaySec}s; restartDelay=${restartDelaySecEffective}s"
Write-Log "Stop policy: sustainedEffectiveThreshold=$softEffectiveThresholdGB GB; stopGrace=${StopGraceSec}s; killVerify=${killVerifyTimeoutSecEffective}s/${killVerifyPollMsEffective}ms"
Write-Log "Ready pattern: $ServerReadyPattern"
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
    $lastResumeAt = $null

    Write-Log "Server started (PID=$($server.Process.Id)). Waiting for readiness before resuming Chunky."
    $initialResume = Resolve-ResumeResult -Value (Send-ResumeCommands -serverState $server)
    if ($initialResume.Sent -and ($null -ne $initialResume.ResumedAt)) {
        $lastResumeAt = $initialResume.ResumedAt
    }

    while ($true) {
        Start-Sleep -Seconds $checkIntervalSecEffective

        $proc = $server.Process
        if ($proc.HasExited) {
            Write-Log "Java process exited (code=$($proc.ExitCode)). Restarting in $restartDelaySecEffective s."
            Clear-ManagedPidFile
            Cleanup-Events -serverState $server
            Start-Sleep -Seconds $restartDelaySecEffective
            Cleanup-ResidualManagedJava -Context "RestartAfterExit"

            $server = Start-Server
            $script:ManagedServerState = $server
            Write-ManagedPidFile -serverState $server
            $memorySamples = New-Object System.Collections.Generic.List[double]
            $consecutiveAboveThreshold = 0

            Write-Log "Server restarted (PID=$($server.Process.Id)). Waiting for readiness."
            $resumeAfterExit = Resolve-ResumeResult -Value (Send-ResumeCommands -serverState $server)
            if ($resumeAfterExit.Sent -and ($null -ne $resumeAfterExit.ResumedAt)) {
                $lastResumeAt = $resumeAfterExit.ResumedAt
            }
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
        $shouldRestartBySoft = ($avgMemoryGB -ge $MaxMemoryGB) -and
            ($consecutiveAboveThreshold -ge $MinConsecutiveAboveThreshold) -and
            ($memoryEffectiveGB -ge $softEffectiveThresholdGB)

        if ($shouldRestartByHard -or $shouldRestartBySoft) {
            $stopRequestedAt = Get-Date
            if ($null -ne $lastResumeAt) {
                $runToNextStopSec = [math]::Round(($stopRequestedAt - $lastResumeAt).TotalSeconds, 1)
                Write-Log "CycleSummary: run_to_next_stop_sec=$runToNextStopSec"
            }

            $reason = if ($shouldRestartByHard) {
                "RAM spike: effective=$memoryEffectiveGB GB (ws=$memoryWsGB GB; private=$memoryPrivateGB GB; hard=$HardMemoryGB GB)"
            } else {
                "Sustained RAM: effective=$memoryEffectiveGB GB, avg=$avgMemoryGB GB (soft=$MaxMemoryGB GB; effective_min=$softEffectiveThresholdGB GB)"
            }

            Graceful-Stop -serverState $server -Reason $reason
            Clear-ManagedPidFile
            Cleanup-Events -serverState $server
            Cleanup-ResidualManagedJava -Context "PostStopBeforeRestart"
            $postStopResidual = @(Get-ManagedJavaProcesses)
            $residualPidList = if (@($postStopResidual).Count -gt 0) { ($postStopResidual | ForEach-Object { $_.Id }) -join "," } else { "none" }
            Write-Log "PostStopProcessCheck: residual_java_count=$(@($postStopResidual).Count); residual_pids=$residualPidList"

            Write-Log "Restarting server in $restartDelaySecEffective s."
            Start-Sleep -Seconds $restartDelaySecEffective

            $server = Start-Server
            $script:ManagedServerState = $server
            Write-ManagedPidFile -serverState $server
            $memorySamples = New-Object System.Collections.Generic.List[double]
            $consecutiveAboveThreshold = 0

            Write-Log "Server restarted (PID=$($server.Process.Id)). Waiting for readiness."
            $resumeAfterRestart = Resolve-ResumeResult -Value (Send-ResumeCommands -serverState $server)
            if ($resumeAfterRestart.Sent -and ($null -ne $resumeAfterRestart.ResumedAt)) {
                $lastResumeAt = $resumeAfterRestart.ResumedAt
                $stopToResumeSec = [math]::Round(($lastResumeAt - $stopRequestedAt).TotalSeconds, 1)
                Write-Log "CycleSummary: stop_to_resume_sec=$stopToResumeSec"
            } else {
                Write-Log "CycleSummary: stop_to_resume_sec=NA (resume command not sent)"
            }
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
