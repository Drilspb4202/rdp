# Настройка Self-Hosted Runner для RDP

Если у вас нет доступа к платным GitHub Actions minutes, вы можете использовать свой собственный Windows сервер как self-hosted runner.

## 📋 Требования

- Windows Server или Windows 10/11 (Pro или выше)
- Доступ к интернету
- Административные права

## 🚀 Установка Self-Hosted Runner

### Шаг 1: Получите токен регистрации

1. Перейдите в ваш репозиторий: https://github.com/Drilspb4202/rdp
2. Settings → Actions → Runners
3. Нажмите "New self-hosted runner"
4. Выберите "Windows" и скопируйте команды регистрации

### Шаг 2: Установите runner на Windows сервере

**Вариант A: Автоматическая установка (рекомендуется)**

Откройте PowerShell **от имени администратора** и выполните:

```powershell
# Используйте токен из шага 1
.\install-runner.ps1 -RunnerToken "YOUR_TOKEN_HERE"
```

**Вариант B: Ручная установка**

```powershell
# Создайте папку для runner
mkdir C:\actions-runner
cd C:\actions-runner

# Скачайте последнюю версию runner
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip" -OutFile "actions-runner-win-x64-2.311.0.zip"

# Распакуйте
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\actions-runner-win-x64-2.311.0.zip", "$PWD")

# Запустите конфигурацию (используйте токен из шага 1)
.\config.cmd --url https://github.com/Drilspb4202/rdp --token YOUR_TOKEN_HERE

# Установите как службу Windows
.\install.cmd

# Запустите службу
Start-Service actions.runner.*
```

### Шаг 3: Обновите workflow для использования self-hosted runner

Создайте файл `.github/workflows/rdp-self-hosted.yml`:

```yaml
name: RDP (Self-Hosted)

on:
  workflow_dispatch:

jobs:
  rdp:
    runs-on: self-hosted  # Используем self-hosted runner
    timeout-minutes: 60
    
    steps:
      # ... остальные шаги такие же
```

## ⚠️ Важные замечания

- Self-hosted runner должен быть доступен 24/7, если вы хотите запускать workflow в любое время
- Убедитесь, что на сервере установлен PowerShell 7+
- Runner должен иметь доступ к интернету для установки Tailscale
- Безопасность: убедитесь, что сервер защищён, так как он будет выполнять код из репозитория

## 🔄 Обновление runner

```powershell
cd C:\actions-runner
.\run.cmd --update
```

## 🛑 Остановка и удаление

```powershell
# Остановите службу
Stop-Service actions.runner.*

# Удалите службу
.\config.cmd remove --token YOUR_TOKEN_HERE
```

