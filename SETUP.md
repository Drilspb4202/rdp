# Инструкция по настройке

## Шаг 1: Добавление Tailscale ключа в GitHub Secrets

### Способ 1: Через веб-интерфейс GitHub (рекомендуется)

1. Откройте ваш репозиторий на GitHub: `https://github.com/Drilspb4202/rdp`
2. Перейдите в **Settings** (в верхнем меню репозитория)
3. В левом меню выберите **Secrets and variables** → **Actions**
4. Нажмите кнопку **New repository secret**
5. Заполните форму:
   - **Name**: `TAILSCALE_AUTH_KEY`
   - **Secret**: `tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL`
6. Нажмите **Add secret**

### Способ 2: Через GitHub CLI (если установлен)

```powershell
# Установите GitHub CLI (если не установлен)
winget install --id GitHub.cli

# Авторизуйтесь
gh auth login

# Добавьте секрет
gh secret set TAILSCALE_AUTH_KEY --body "tskey-auth-kXUz5wtMAP11CNTRL-gg4nV2q7ayeLmWGhh51HzeDbvQMKfU7ZL"
```

## Шаг 2: Запуск workflow

1. Перейдите в раздел **Actions** вашего репозитория
2. В левом меню выберите **RDP**
3. Нажмите **Run workflow** (справа)
4. Нажмите зеленую кнопку **Run workflow**

## Шаг 3: Получение данных для подключения

1. Дождитесь выполнения workflow (обычно 2-3 минуты)
2. Откройте выполненный run
3. Найдите шаг **"Maintain Connection"**
4. В логах найдите секцию:
   ```
   === RDP ACCESS ===
   Address: 100.x.x.x
   Username: RDP
   Password: [сгенерированный пароль]
   ==================
   ```

## Шаг 4: Подключение через RDP

1. Убедитесь, что ваш компьютер подключен к той же Tailscale сети
2. Откройте Remote Desktop Connection (mstsc.exe)
3. Введите Tailscale IP из логов
4. Используйте:
   - **Username**: `RDP`
   - **Password**: пароль из логов

## Проверка статуса

После добавления секрета вы можете проверить его наличие:
- Перейдите в Settings → Secrets and variables → Actions
- Должен быть виден секрет `TAILSCALE_AUTH_KEY` (значение скрыто)

---

**Важно**: Workflow будет активен до 60 минут или до ручной остановки. После остановки runner будет удалён.

