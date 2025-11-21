# Добавление GitHub Secret через API с правильным шифрованием
# Использует GitHub API напрямую

param(
    [Parameter(Mandatory=$true)]
    [string]$Token,
    
    [string]$Repo = "beres/rdp",
    [string]$SecretName = "TAILSCALE_AUTH_KEY",
    [string]$SecretValue = "tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Добавление GitHub Secret ===" -ForegroundColor Green
Write-Host "Репозиторий: $Repo" -ForegroundColor Cyan
Write-Host "Имя секрета: $SecretName" -ForegroundColor Cyan
Write-Host ""

$owner, $repoName = $Repo -split '/'
if (-not $owner -or -not $repoName) {
    throw "Неверный формат репозитория. Используйте: owner/repo"
}

$baseUrl = "https://api.github.com"
$headers = @{
    "Authorization" = "Bearer $Token"
    "Accept" = "application/vnd.github.v3+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# Шаг 1: Получить публичный ключ
Write-Host "[1/3] Получение публичного ключа репозитория..." -ForegroundColor Yellow
try {
    $publicKeyResponse = Invoke-RestMethod -Uri "$baseUrl/repos/$Repo/actions/secrets/public-key" -Method Get -Headers $headers
    $keyId = $publicKeyResponse.key_id
    $publicKeyBase64 = $publicKeyResponse.key
    Write-Host "✓ Публичный ключ получен (ID: $keyId)" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "Проверьте правильность токена и права доступа (нужны права repo)" -ForegroundColor Yellow
    } elseif ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "Репозиторий не найден или нет доступа" -ForegroundColor Yellow
    }
    exit 1
}

# Шаг 2: Шифрование секрета
Write-Host "[2/3] Шифрование секрета..." -ForegroundColor Yellow

# GitHub использует libsodium sealed box (NaCl crypto_box_seal)
# Для PowerShell нужна библиотека или альтернативный метод
# Используем готовое решение через .NET или внешнюю библиотеку

# Вариант 1: Попробуем использовать встроенные возможности
# Но GitHub требует именно libsodium sealed box

# Скачиваем и используем готовую библиотеку для шифрования
$libsodiumDll = "$env:TEMP\libsodium.dll"
if (-not (Test-Path $libsodiumDll)) {
    Write-Host "Скачивание libsodium..." -ForegroundColor Cyan
    # Пробуем скачать предкомпилированную DLL
    $libsodiumUrl = "https://github.com/jedisct1/libsodium/releases/download/1.0.18-stable/libsodium-1.0.18-stable-msvc.zip"
    # Это сложно, попробуем другой подход
}

# Альтернатива: используем готовый PowerShell модуль или скрипт
# Или используем Python/Node.js для шифрования

Write-Host "Для шифрования требуется libsodium sealed box." -ForegroundColor Yellow
Write-Host "Используем альтернативный метод..." -ForegroundColor Cyan

# Временное решение: создаем скрипт, который использует Python для шифрования
$pythonScript = @"
import base64
import json
import sys
from nacl import encoding, public

def encrypt(public_key: str, secret_value: str) -> str:
    \"\"\"Encrypt a Unicode string using the public key.\"\"\"
    public_key = public.PublicKey(public_key.encode("utf-8"), encoding.Base64Encoder())
    sealed_box = public.SealedBox(public_key)
    encrypted = sealed_box.encrypt(secret_value.encode("utf-8"))
    return base64.b64encode(encrypted).decode("utf-8")

if __name__ == "__main__":
    public_key = sys.argv[1]
    secret_value = sys.argv[2]
    encrypted = encrypt(public_key, secret_value)
    print(encrypted)
"@

$pythonScriptPath = "$env:TEMP\encrypt_secret.py"
$pythonScript | Out-File -FilePath $pythonScriptPath -Encoding UTF8

# Проверяем наличие Python и PyNaCl
Write-Host "Проверка Python..." -ForegroundColor Cyan
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python найден: $pythonVersion" -ForegroundColor Green
    
    # Проверяем PyNaCl
    $pynaclCheck = python -c "import nacl; print('OK')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Установка PyNaCl..." -ForegroundColor Yellow
        pip install pynacl --quiet
    }
    
    # Шифруем секрет
    $encryptedSecret = python $pythonScriptPath $publicKeyBase64 $SecretValue
    Write-Host "✓ Секрет зашифрован" -ForegroundColor Green
} catch {
    Write-Host "✗ Python не найден или PyNaCl не установлен" -ForegroundColor Red
    Write-Host ""
    Write-Host "Установите Python и PyNaCl:" -ForegroundColor Yellow
    Write-Host "  pip install pynacl" -ForegroundColor White
    Write-Host ""
    Write-Host "Или используйте веб-интерфейс GitHub:" -ForegroundColor Yellow
    Write-Host "  https://github.com/$Repo/settings/secrets/actions" -ForegroundColor Cyan
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
    exit 1
}

# Шаг 3: Отправка зашифрованного секрета
Write-Host "[3/3] Отправка секрета в GitHub..." -ForegroundColor Yellow

$body = @{
    encrypted_value = $encryptedSecret
    key_id = $keyId
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/repos/$Repo/actions/secrets/$SecretName" -Method Put -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "✓ Секрет успешно добавлен!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Теперь вы можете запустить workflow через GitHub Actions" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Ошибка при добавлении секрета: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host "Секрет с таким именем уже существует или неверный формат данных" -ForegroundColor Yellow
    }
    exit 1
} finally {
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Готово ===" -ForegroundColor Green

