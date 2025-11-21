# Скрипт для установки GitHub Actions Self-Hosted Runner на Windows
# Требует PowerShell от имени администратора

param(
    [Parameter(Mandatory=$true)]
    [string]$RunnerToken,
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$RunnerPath = "C:\actions-runner",
    
    [Parameter(Mandatory=$false)]
    [string]$RepoUrl = "https://github.com/Drilspb4202/rdp"
)

Write-Host "=== GitHub Actions Self-Hosted Runner Setup ===" -ForegroundColor Green
Write-Host ""

# Проверка прав администратора
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "✗ Этот скрипт требует прав администратора!" -ForegroundColor Red
    Write-Host "Запустите PowerShell от имени администратора" -ForegroundColor Yellow
    exit 1
}

# Создание папки для runner
if (Test-Path $RunnerPath) {
    Write-Host "⚠ Папка $RunnerPath уже существует" -ForegroundColor Yellow
    $response = Read-Host "Удалить и переустановить? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Remove-Item -Path $RunnerPath -Recurse -Force
    } else {
        Write-Host "Отмена установки" -ForegroundColor Yellow
        exit 0
    }
}

New-Item -ItemType Directory -Path $RunnerPath -Force | Out-Null
Set-Location $RunnerPath

Write-Host "✓ Папка создана: $RunnerPath" -ForegroundColor Green

# Определение версии runner
$runnerVersion = "2.329.0"
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip"
$runnerZip = "actions-runner-win-x64-$runnerVersion.zip"
$expectedHash = "f60be5ddf373c52fd735388c3478536afd12bfd36d1d0777c6b855b758e70f25"  # SHA256 hash для проверки

Write-Host "Скачивание runner v$runnerVersion..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip -UseBasicParsing
    Write-Host "✓ Runner скачан" -ForegroundColor Green
    
    # Проверка хеша (опционально, но рекомендуется)
    Write-Host "Проверка целостности файла..." -ForegroundColor Cyan
    $actualHash = (Get-FileHash -Path $runnerZip -Algorithm SHA256).Hash.ToUpper()
    if ($actualHash -ne $expectedHash.ToUpper()) {
        Write-Host "⚠ Предупреждение: хеш файла не совпадает с ожидаемым!" -ForegroundColor Yellow
        Write-Host "  Ожидаемый: $expectedHash" -ForegroundColor Yellow
        Write-Host "  Полученный: $actualHash" -ForegroundColor Yellow
        $response = Read-Host "Продолжить установку? (y/n)"
        if ($response -ne "y" -and $response -ne "Y") {
            Remove-Item $runnerZip
            exit 1
        }
    } else {
        Write-Host "✓ Целостность файла подтверждена" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Ошибка при скачивании runner: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Распаковка runner..." -ForegroundColor Cyan
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$RunnerPath\$runnerZip", $RunnerPath)
    Remove-Item $runnerZip
    Write-Host "✓ Runner распакован" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка при распаковке: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Настройка runner..." -ForegroundColor Cyan
try {
    & .\config.cmd --url $RepoUrl --token $RunnerToken --name $RunnerName --unattended --replace
    Write-Host "✓ Runner настроен" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка при настройке runner: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Установка runner как службы Windows..." -ForegroundColor Cyan
try {
    & .\install.cmd
    Write-Host "✓ Runner установлен как служба" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка при установке службы: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Запуск службы..." -ForegroundColor Cyan
try {
    Start-Service "actions.runner.*"
    Write-Host "✓ Служба запущена" -ForegroundColor Green
} catch {
    Write-Host "⚠ Не удалось запустить службу автоматически. Запустите вручную:" -ForegroundColor Yellow
    Write-Host "  Start-Service actions.runner.*" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "=== УСТАНОВКА ЗАВЕРШЕНА ===" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Runner установлен и запущен!" -ForegroundColor White
Write-Host "Путь: $RunnerPath" -ForegroundColor White
Write-Host "Имя: $RunnerName" -ForegroundColor White
Write-Host ""
Write-Host "Теперь вы можете использовать workflow 'RDP (Self-Hosted)'" -ForegroundColor Cyan
Write-Host ""

# Проверка статуса службы
$service = Get-Service "actions.runner.*" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Статус службы: $($service.Status)" -ForegroundColor $(if ($service.Status -eq "Running") { "Green" } else { "Yellow" })
}

Write-Host ""
Write-Host "Полезные команды:" -ForegroundColor Cyan
Write-Host "  Проверить статус: Get-Service actions.runner.*" -ForegroundColor White
Write-Host "  Остановить: Stop-Service actions.runner.*" -ForegroundColor White
Write-Host "  Запустить: Start-Service actions.runner.*" -ForegroundColor White
Write-Host "  Удалить: cd $RunnerPath; .\config.cmd remove --token <TOKEN>" -ForegroundColor White
Write-Host ""

