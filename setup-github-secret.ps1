# Автоматическая настройка GitHub Secret для Tailscale
# Этот скрипт добавляет секрет в GitHub через API

param(
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$Repo = "beres/rdp"
)

$ErrorActionPreference = "Stop"

# Проверка зависимостей
Write-Host "=== Проверка зависимостей ===" -ForegroundColor Green

# Проверка Python
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Python не найден. Установите Python 3.x" -ForegroundColor Red
    exit 1
}

# Проверка PyNaCl
try {
    python -c "import nacl" 2>&1 | Out-Null
    Write-Host "✓ PyNaCl установлен" -ForegroundColor Green
} catch {
    Write-Host "Установка PyNaCl..." -ForegroundColor Yellow
    pip install pynacl --quiet
    Write-Host "✓ PyNaCl установлен" -ForegroundColor Green
}

# Проверка токена
if (-not $GitHubToken) {
    Write-Host ""
    Write-Host "⚠ GitHub токен не найден!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Для добавления секрета нужен GitHub Personal Access Token." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Как получить токен:" -ForegroundColor White
    Write-Host "1. Откройте: https://github.com/settings/tokens" -ForegroundColor Gray
    Write-Host "2. Нажмите 'Generate new token' -> 'Generate new token (classic)'" -ForegroundColor Gray
    Write-Host "3. Выберите права: repo (все права)" -ForegroundColor Gray
    Write-Host "4. Скопируйте токен" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Затем выполните:" -ForegroundColor White
    Write-Host "  `$env:GITHUB_TOKEN = 'ваш_токен'" -ForegroundColor Green
    Write-Host "  .\setup-github-secret.ps1" -ForegroundColor Green
    Write-Host ""
    Write-Host "Или передайте токен напрямую:" -ForegroundColor White
    Write-Host "  .\setup-github-secret.ps1 -GitHubToken 'ваш_токен'" -ForegroundColor Green
    Write-Host ""
    
    # Пробуем найти токен в других местах
    $possibleTokens = @(
        $env:GH_TOKEN,
        (git config --global github.token 2>$null),
        (git config github.token 2>$null)
    )
    
    $foundToken = $possibleTokens | Where-Object { $_ } | Select-Object -First 1
    if ($foundToken) {
        Write-Host "Найден токен в git config. Использовать? (Y/N): " -ForegroundColor Cyan -NoNewline
        $response = Read-Host
        if ($response -eq 'Y' -or $response -eq 'y') {
            $GitHubToken = $foundToken
            Write-Host "Используем найденный токен" -ForegroundColor Green
        } else {
            exit 1
        }
    } else {
        exit 1
    }
}

Write-Host ""
Write-Host "=== Добавление секрета в GitHub ===" -ForegroundColor Green

$secretName = "TAILSCALE_AUTH_KEY"
$secretValue = "tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL"

$owner, $repoName = $Repo -split '/'
if (-not $owner -or -not $repoName) {
    throw "Неверный формат репозитория. Используйте: owner/repo"
}

$baseUrl = "https://api.github.com"
$headers = @{
    "Authorization" = "Bearer $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# Шаг 1: Получить публичный ключ
Write-Host "[1/3] Получение публичного ключа..." -ForegroundColor Yellow
try {
    $publicKeyResponse = Invoke-RestMethod -Uri "$baseUrl/repos/$Repo/actions/secrets/public-key" -Method Get -Headers $headers
    $keyId = $publicKeyResponse.key_id
    $publicKeyBase64 = $publicKeyResponse.key
    Write-Host "✓ Публичный ключ получен" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "Неверный токен или недостаточно прав" -ForegroundColor Yellow
    } elseif ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "Репозиторий не найден или нет доступа" -ForegroundColor Yellow
    }
    exit 1
}

# Шаг 2: Шифрование через Python
Write-Host "[2/3] Шифрование секрета..." -ForegroundColor Yellow

$pythonScript = @"
import base64
import sys
from nacl import encoding, public

def encrypt(public_key: str, secret_value: str) -> str:
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

$pythonScriptPath = "$env:TEMP\encrypt_github_secret_$(Get-Random).py"
$pythonScript | Out-File -FilePath $pythonScriptPath -Encoding UTF8

try {
    $encryptedSecret = python $pythonScriptPath $publicKeyBase64 $secretValue
    if ($LASTEXITCODE -ne 0) {
        throw "Ошибка при шифровании"
    }
    Write-Host "✓ Секрет зашифрован" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка при шифровании: $_" -ForegroundColor Red
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
    exit 1
}

# Шаг 3: Отправка секрета
Write-Host "[3/3] Отправка секрета в GitHub..." -ForegroundColor Yellow

$body = @{
    encrypted_value = $encryptedSecret
    key_id = $keyId
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/repos/$Repo/actions/secrets/$secretName" -Method Put -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "✓ Секрет '$secretName' успешно добавлен в репозиторий $Repo!" -ForegroundColor Green
} catch {
    Write-Host "✗ Ошибка при добавлении секрета: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host "Секрет уже существует (это нормально)" -ForegroundColor Yellow
    }
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
    exit 1
} finally {
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Готово! ===" -ForegroundColor Green
Write-Host "Теперь вы можете запустить workflow через GitHub Actions:" -ForegroundColor Cyan
Write-Host "  https://github.com/$Repo/actions" -ForegroundColor White

