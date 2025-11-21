# Скрипт для добавления Tailscale ключа в GitHub Secrets
# Требуется: GitHub CLI (gh) должен быть установлен и авторизован

$tailscaleKey = "tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL"
$repo = "beres/rdp"  # Замените на ваш username/repo

Write-Host "Добавление Tailscale ключа в GitHub Secrets..." -ForegroundColor Green

# Проверяем, авторизован ли gh
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Ошибка: GitHub CLI не авторизован. Выполните: gh auth login" -ForegroundColor Red
    exit 1
}

# Добавляем секрет
gh secret set TAILSCALE_AUTH_KEY --body $tailscaleKey --repo $repo

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ Секрет TAILSCALE_AUTH_KEY успешно добавлен!" -ForegroundColor Green
    Write-Host "Теперь вы можете запустить workflow через GitHub Actions" -ForegroundColor Cyan
} else {
    Write-Host "`n✗ Ошибка при добавлении секрета" -ForegroundColor Red
    Write-Host "Убедитесь, что:" -ForegroundColor Yellow
    Write-Host "  1. GitHub CLI установлен (gh)" -ForegroundColor Yellow
    Write-Host "  2. Вы авторизованы (gh auth login)" -ForegroundColor Yellow
    Write-Host "  3. У вас есть права на репозиторий $repo" -ForegroundColor Yellow
}

