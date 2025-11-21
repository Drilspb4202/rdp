# Полностью автоматическая настройка GitHub Secret
# Этот скрипт делает всё сам - нужно только предоставить GitHub токен один раз

Write-Host "=== Автоматическая настройка GitHub Secret ===" -ForegroundColor Green
Write-Host ""

# Проверка и установка зависимостей
Write-Host "[Шаг 1/4] Проверка зависимостей..." -ForegroundColor Cyan

# Python
try {
    $pythonVersion = python --version 2>&1
    Write-Host "  ✓ Python установлен: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Python не найден!" -ForegroundColor Red
    Write-Host "  Установите Python с https://www.python.org/" -ForegroundColor Yellow
    exit 1
}

# PyNaCl
try {
    python -c "import nacl" 2>&1 | Out-Null
    Write-Host "  ✓ PyNaCl установлен" -ForegroundColor Green
} catch {
    Write-Host "  Установка PyNaCl..." -ForegroundColor Yellow
    python -m pip install pynacl --quiet 2>&1 | Out-Null
    Write-Host "  ✓ PyNaCl установлен" -ForegroundColor Green
}

# Поиск токена
Write-Host ""
Write-Host "[Шаг 2/4] Поиск GitHub токена..." -ForegroundColor Cyan

$token = $null
$tokenSources = @(
    @{Name="GITHUB_TOKEN"; Value=$env:GITHUB_TOKEN},
    @{Name="GH_TOKEN"; Value=$env:GH_TOKEN},
    @{Name="git config"; Value=(git config --global github.token 2>$null)}
)

foreach ($source in $tokenSources) {
    if ($source.Value) {
        Write-Host "  ✓ Токен найден в: $($source.Name)" -ForegroundColor Green
        $token = $source.Value
        break
    }
}

if (-not $token) {
    Write-Host "  ⚠ Токен не найден" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Для автоматической настройки нужен GitHub Personal Access Token." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Быстрое получение токена:" -ForegroundColor White
    Write-Host "  1. Откройте: https://github.com/settings/tokens/new" -ForegroundColor Gray
    Write-Host "  2. Название: RDP Setup" -ForegroundColor Gray
    Write-Host "  3. Срок действия: 90 дней (или No expiration)" -ForegroundColor Gray
    Write-Host "  4. Права: repo (все)" -ForegroundColor Gray
    Write-Host "  5. Нажмите 'Generate token'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Введите токен (он не будет сохранён): " -ForegroundColor Cyan -NoNewline
    $token = Read-Host -AsSecureString
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
    )
    
    if (-not $token) {
        Write-Host ""
        Write-Host "Токен не предоставлен. Используйте веб-интерфейс:" -ForegroundColor Yellow
        Write-Host "  https://github.com/beres/rdp/settings/secrets/actions" -ForegroundColor Cyan
        exit 1
    }
}

# Добавление секрета
Write-Host ""
Write-Host "[Шаг 3/4] Добавление секрета в GitHub..." -ForegroundColor Cyan

$repo = "Drilspb4202/rdp"
$secretName = "TAILSCALE_AUTH_KEY"
$secretValue = "tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL"

$baseUrl = "https://api.github.com"
$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/vnd.github.v3+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

# Получение публичного ключа
try {
    Write-Host "  Получение публичного ключа..." -ForegroundColor Gray
    $publicKeyResponse = Invoke-RestMethod -Uri "$baseUrl/repos/$repo/actions/secrets/public-key" -Method Get -Headers $headers
    $keyId = $publicKeyResponse.key_id
    $publicKeyBase64 = $publicKeyResponse.key
} catch {
    Write-Host "  ✗ Ошибка: $_" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 401) {
        Write-Host "  Неверный токен или недостаточно прав" -ForegroundColor Yellow
    }
    exit 1
}

# Шифрование
Write-Host "  Шифрование секрета..." -ForegroundColor Gray
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
    $encryptedSecret = python $pythonScriptPath $publicKeyBase64 $secretValue 2>&1 | Where-Object { $_ -notmatch "Could not find platform" }
    if ($LASTEXITCODE -ne 0 -and -not $encryptedSecret) {
        throw "Ошибка при шифровании"
    }
    $encryptedSecret = $encryptedSecret | Select-Object -Last 1
} catch {
    Write-Host "  ✗ Ошибка при шифровании: $_" -ForegroundColor Red
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
    exit 1
}

# Отправка секрета
Write-Host "  Отправка секрета..." -ForegroundColor Gray
$body = @{
    encrypted_value = $encryptedSecret
    key_id = $keyId
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$baseUrl/repos/$repo/actions/secrets/$secretName" -Method Put -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "  ✓ Секрет успешно добавлен!" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host "  ✓ Секрет уже существует (это нормально)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Ошибка: $_" -ForegroundColor Red
        Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
        exit 1
    }
} finally {
    Remove-Item $pythonScriptPath -ErrorAction SilentlyContinue
}

# Финальное сообщение
Write-Host ""
Write-Host "[Шаг 4/4] Готово!" -ForegroundColor Cyan
Write-Host ""
Write-Host "=== Настройка завершена! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Секрет TAILSCALE_AUTH_KEY добавлен в репозиторий." -ForegroundColor White
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Cyan
Write-Host "  1. Откройте: https://github.com/$repo/actions" -ForegroundColor White
Write-Host "  2. Выберите workflow 'RDP'" -ForegroundColor White
Write-Host "  3. Нажмите 'Run workflow'" -ForegroundColor White
Write-Host "  4. Дождитесь выполнения и найдите данные для RDP в логах" -ForegroundColor White
Write-Host ""

