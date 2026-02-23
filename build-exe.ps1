param(
    [switch]$Clean,
    [switch]$NoZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Resolve-Path (Join-Path $scriptDir "..")).Path
$toolsDir = Join-Path $scriptDir "tools\ps2exe"
$distDir = Join-Path $scriptDir "dist"
$packageDir = Join-Path $distDir "ChunkyPregenGuard"
$inputFile = Join-Path $scriptDir "chunky-pregen-guard.ps1"
$outputExe = Join-Path $packageDir "ChunkyPregenGuard.exe"
$iconFile = Join-Path $rootDir "wems-logo.ico"
$readmeFile = Join-Path $scriptDir "README.md"
$runBat = Join-Path $packageDir "Run-ChunkyPregenGuard.bat"
$zipFile = Join-Path $distDir "ChunkyPregenGuard-package.zip"

function Write-Step {
    param([string]$Message)
    Write-Host "[build] $Message"
}

function Ensure-Ps2ExeLocal {
    if (-not (Test-Path -Path $toolsDir)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    }

    $needFiles = @("ps2exe.ps1", "ps2exe.psm1", "ps2exe.psd1")
    $missing = @($needFiles | Where-Object { -not (Test-Path -Path (Join-Path $toolsDir $_)) })
    if ($missing.Count -eq 0) {
        return
    }

    Write-Step "Downloading local PS2EXE tooling..."
    $base = "https://raw.githubusercontent.com/MScholtes/PS2EXE/master/Module"
    foreach ($name in $needFiles) {
        $uri = "$base/$name"
        $dst = Join-Path $toolsDir $name
        Invoke-WebRequest -Uri $uri -OutFile $dst -UseBasicParsing
    }
}

if (-not (Test-Path -Path $inputFile)) {
    throw "Input script not found: $inputFile"
}

if ($Clean -and (Test-Path -Path $distDir)) {
    Write-Step "Cleaning dist folder..."
    Remove-Item -Path $distDir -Recurse -Force
}

if (-not (Test-Path -Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}
if (-not (Test-Path -Path $packageDir)) {
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
}

Ensure-Ps2ExeLocal

$modulePath = Join-Path $toolsDir "ps2exe.psm1"
Import-Module $modulePath -Force

$compileParams = @{
    inputFile   = $inputFile
    outputFile  = $outputExe
    noConsole   = $true
    STA         = $true
    title       = "Chunky Pregen Guard"
    description = "GUI launcher for chunky-pregen-guard.ps1"
    product     = "Chunky Pregen Guard"
    company     = "Local Build"
    version     = "1.0.0.0"
}
if (Test-Path -Path $iconFile) {
    $compileParams.iconFile = $iconFile
}

Write-Step "Compiling EXE..."
Invoke-ps2exe @compileParams | Out-Host

if (-not (Test-Path -Path $outputExe)) {
    throw "EXE was not generated: $outputExe"
}

Write-Step "Preparing package files..."
@(
    "@echo off",
    "cd /d ""%~dp0""",
    'start "" ".\ChunkyPregenGuard.exe"',
    "exit /b 0"
) | Set-Content -Path $runBat -Encoding ASCII

if (Test-Path -Path $readmeFile) {
    Copy-Item -Path $readmeFile -Destination (Join-Path $packageDir "README.md") -Force
}

if (-not $NoZip) {
    if (Test-Path -Path $zipFile) {
        Remove-Item -Path $zipFile -Force
    }
    Write-Step "Creating ZIP package..."
    Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipFile -CompressionLevel Optimal
}

Write-Step "Done."
Write-Host "EXE: $outputExe"
if (-not $NoZip) {
    Write-Host "ZIP: $zipFile"
}
