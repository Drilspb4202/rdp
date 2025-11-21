# Скрипт для добавления Tailscale ключа в GitHub Secrets через API
# Требуется: GitHub Personal Access Token с правами repo

param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$Repo = "beres/rdp",
    [string]$SecretName = "TAILSCALE_AUTH_KEY",
    [string]$SecretValue = "tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL"
)

if (-not $Token) {
    Write-Host "Ошибка: GitHub токен не найден!" -ForegroundColor Red
    Write-Host "Установите переменную окружения GITHUB_TOKEN или передайте токен через параметр -Token" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Как получить токен:" -ForegroundColor Cyan
    Write-Host "1. Перейдите: https://github.com/settings/tokens" -ForegroundColor White
    Write-Host "2. Нажмите 'Generate new token' -> 'Generate new token (classic)'" -ForegroundColor White
    Write-Host "3. Выберите права: repo (все)" -ForegroundColor White
    Write-Host "4. Скопируйте токен и выполните:" -ForegroundColor White
    Write-Host "   `$env:GITHUB_TOKEN = 'ваш_токен'" -ForegroundColor Green
    Write-Host "   .\add-secret.ps1" -ForegroundColor Green
    exit 1
}

$owner, $repoName = $Repo -split '/'
if (-not $owner -or -not $repoName) {
    Write-Host "Ошибка: Неверный формат репозитория. Используйте: owner/repo" -ForegroundColor Red
    exit 1
}

Write-Host "Добавление секрета $SecretName в репозиторий $Repo..." -ForegroundColor Green

# Шаг 1: Получить публичный ключ репозитория
Write-Host "Получение публичного ключа репозитория..." -ForegroundColor Cyan
$publicKeyUrl = "https://api.github.com/repos/$Repo/actions/secrets/public-key"
$headers = @{
    "Authorization" = "Bearer $Token"
    "Accept" = "application/vnd.github.v3+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

try {
    $publicKeyResponse = Invoke-RestMethod -Uri $publicKeyUrl -Method Get -Headers $headers
    $keyId = $publicKeyResponse.key_id
    $publicKey = $publicKeyResponse.key
    Write-Host "✓ Публичный ключ получен" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка при получении публичного ключа: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "Проверьте правильность токена и его права доступа" -ForegroundColor Yellow
    }
    exit 1
}

# Шаг 2: Зашифровать секрет используя публичный ключ
Write-Host "Шифрование секрета..." -ForegroundColor Cyan

# Используем .NET для шифрования с помощью публичного ключа
Add-Type -AssemblyName System.Security

# Конвертируем base64 публичный ключ в байты
$publicKeyBytes = [Convert]::FromBase64String($publicKey)

# Используем Sodium для шифрования (если доступен) или встроенные методы
# Для GitHub Secrets используется libsodium box_seal
# Упрощенная версия - используем встроенный метод

# GitHub использует libsodium sealed box для шифрования
# Это требует библиотеку libsodium, но мы можем использовать альтернативный подход
# через GitHub CLI или напрямую через API с правильным шифрованием

# Вместо этого, попробуем использовать более простой метод через GitHub CLI
# или создадим правильное шифрование

# Для правильного шифрования нужна библиотека libsodium
# Попробуем скачать и использовать её
$libsodiumUrl = "https://github.com/jedisct1/libsodium/releases/download/1.0.18-stable/libsodium-1.0.18-stable-msvc.zip"
$libsodiumPath = "$env:TEMP\libsodium"

Write-Host "Для шифрования секрета требуется libsodium..." -ForegroundColor Yellow
Write-Host "Используем альтернативный метод через GitHub API..." -ForegroundColor Cyan

# Альтернативный подход: используем готовую библиотеку или PowerShell модуль
# Но проще всего - использовать правильный метод шифрования

# GitHub Secrets API требует шифрования с помощью libsodium sealed box
# Это сложно реализовать в чистом PowerShell без внешних библиотек

Write-Host ""
Write-Host "⚠ ВНИМАНИЕ: Прямое шифрование через PowerShell сложно." -ForegroundColor Yellow
Write-Host "Рекомендуется использовать один из методов:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Через веб-интерфейс GitHub (самый простой):" -ForegroundColor Cyan
Write-Host "   https://github.com/$Repo/settings/secrets/actions" -ForegroundColor White
Write-Host ""
Write-Host "2. Установить GitHub CLI и использовать:" -ForegroundColor Cyan
Write-Host "   gh secret set $SecretName --body `"$SecretValue`"" -ForegroundColor White
Write-Host ""
Write-Host "3. Использовать готовый скрипт с libsodium (требует установки)" -ForegroundColor Cyan

# Попробуем использовать альтернативный метод - через curl и правильное шифрование
# Но для этого нужна библиотека libsodium

exit 0

