# GitHub Actions Self-Hosted Runner Installer
# Based on GitHub instructions

param(
    [Parameter(Mandatory=$true)]
    [string]$RunnerToken
)

$ErrorActionPreference = "Stop"

Write-Host "=== GitHub Actions Self-Hosted Runner Setup ===" -ForegroundColor Green

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Error: This script requires administrator rights!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator" -ForegroundColor Yellow
    exit 1
}

# Create folder
$runnerPath = "C:\actions-runner"
if (Test-Path $runnerPath) {
    Write-Host "Warning: Folder $runnerPath already exists" -ForegroundColor Yellow
    $response = Read-Host "Delete and reinstall? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Remove-Item -Path $runnerPath -Recurse -Force
    } else {
        Write-Host "Installation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

New-Item -ItemType Directory -Path $runnerPath -Force | Out-Null
Set-Location $runnerPath

Write-Host "Folder created: $runnerPath" -ForegroundColor Green

# Download runner
$runnerVersion = "2.329.0"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip"
$runnerZip = "actions-runner-win-x64-$runnerVersion.zip"
$expectedHash = "f60be5ddf373c52fd735388c3478536afd12bfd36d1d0777c6b855b758e70f25"

Write-Host "Downloading runner v$runnerVersion..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip -UseBasicParsing
Write-Host "Runner downloaded" -ForegroundColor Green

# Validate hash
Write-Host "Validating hash..." -ForegroundColor Cyan
$actualHash = (Get-FileHash -Path $runnerZip -Algorithm SHA256).Hash.ToUpper()
if ($actualHash -ne $expectedHash.ToUpper()) {
    Write-Host "Warning: Hash mismatch!" -ForegroundColor Yellow
    Write-Host "  Expected: $expectedHash" -ForegroundColor Yellow
    Write-Host "  Got: $actualHash" -ForegroundColor Yellow
    $response = Read-Host "Continue? (y/n)"
    if ($response -ne "y" -and $response -ne "Y") {
        Remove-Item $runnerZip
        exit 1
    }
} else {
    Write-Host "Hash validated" -ForegroundColor Green
}

# Extract
Write-Host "Extracting runner..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$runnerPath\$runnerZip", $runnerPath)
Remove-Item $runnerZip
Write-Host "Runner extracted" -ForegroundColor Green

# Configure
Write-Host "Configuring runner..." -ForegroundColor Cyan
& .\config.cmd --url https://github.com/Drilspb4202/rdp --token $RunnerToken --unattended --replace
Write-Host "Runner configured" -ForegroundColor Green

# Install as service
Write-Host "Installing as Windows service..." -ForegroundColor Cyan
& .\install.cmd
Write-Host "Service installed" -ForegroundColor Green

# Start service
Write-Host "Starting service..." -ForegroundColor Cyan
Start-Service "actions.runner.*"
Write-Host "Service started" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "=== INSTALLATION COMPLETE ===" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Runner installed and running!" -ForegroundColor White
Write-Host "Path: $runnerPath" -ForegroundColor White
Write-Host ""
Write-Host "You can now use the 'RDP (Self-Hosted)' workflow" -ForegroundColor Cyan
Write-Host ""

