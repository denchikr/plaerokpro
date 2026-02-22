#!/bin/bash
# Playerok PRO — установка на Ubuntu/Debian одной командой
# Одна строка для запуска (подставьте свой репозиторий с этим скриптом):
#   wget https://raw.githubusercontent.com/USER/REPO/main/install-playerok.sh -O install-playerok.sh && bash install-playerok.sh

set -e

# Репозиторий с ботом (можно форк playerok-universal или свой репо)
REPO_URL="${PLAYEROK_REPO_URL:-https://github.com/alleexxeeyy/playerok-universal}"
INSTALL_DIR_NAME="playerok-pro"
SERVICE_NAME="playerok-pro"

RED='\033[1;91m'
CYAN='\033[1;96m'
GREEN='\033[1;92m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

LINE="${BOLD}################################################################################${RESET}"

echo -e "\n${LINE}"
echo -e "${CYAN}  Playerok PRO — установка на Linux (Ubuntu/Debian)${RESET}"
echo -e "${LINE}\n"

# Проверка root / sudo
if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
  echo -e "${RED}Нужны права sudo. Запустите: sudo bash install-playerok.sh${RESET}"
  exit 1
fi

RUN=""
if [[ $EUID -ne 0 ]]; then
  RUN="sudo"
fi

# Имя пользователя для запуска бота
echo -ne "${CYAN}Введите имя пользователя, от которого будет запускаться бот (например playerok или fpc): ${RESET}"
while true; do
  read -r username
  if [[ -z "$username" ]]; then
    echo -ne "${RED}Имя не может быть пустым. Введите снова: ${RESET}"
    continue
  fi
  if [[ "$username" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    if id "$username" &>/dev/null; then
      echo -ne "${YELLOW}Пользователь $username уже есть. Использовать его? (y/n): ${RESET}"
      read -r use
      [[ "$use" =~ ^[yYдД] ]] && break
      echo -ne "${CYAN}Введите другое имя: ${RESET}"
    else
      break
    fi
  else
    echo -ne "${RED}Только латиница, цифры, _ и -. Введите снова: ${RESET}"
  fi
done

# Создать пользователя, если нет
if ! id "$username" &>/dev/null; then
  echo -e "\n${LINE}\nСоздаю пользователя $username...\n${LINE}"
  $RUN useradd -m -s /bin/bash "$username"
fi

HOME_INSTALL="$($RUN getent passwd "$username" | cut -d: -f6)"
INSTALL_PATH="$HOME_INSTALL/$INSTALL_DIR_NAME"

# Обновление и установка пакетов
echo -e "\n${LINE}\nОбновление системы и установка зависимостей...\n${LINE}"
$RUN apt-get update -qq
$RUN apt-get install -y -qq \
  git \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
  libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 \
  fonts-liberation libappindicator3-1 xvfb \
  || true

# Определить python3 и pip
PYTHON3=$(command -v python3)
if [[ -z "$PYTHON3" ]]; then
  echo -e "${RED}Python3 не найден. Установите: sudo apt install python3 python3-venv python3-pip${RESET}"
  exit 1
fi

# Клонирование или обновление репозитория
echo -e "\n${LINE}\nКлонирование репозитория бота...\n${LINE}"
$RUN mkdir -p "$(dirname "$INSTALL_PATH")"
if [[ -d "$INSTALL_PATH/.git" ]]; then
  BRANCH=$($RUN -u "$username" git -C "$INSTALL_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  $RUN -u "$username" git -C "$INSTALL_PATH" fetch --all
  $RUN -u "$username" git -C "$INSTALL_PATH" reset --hard "origin/$BRANCH"
  $RUN -u "$username" git -C "$INSTALL_PATH" pull --rebase 2>/dev/null || true
else
  $RUN -u "$username" git clone "$REPO_URL" "$INSTALL_PATH" || {
    echo -e "${RED}Не удалось клонировать $REPO_URL. Проверьте URL и доступ.${RESET}"
    exit 1
  }
fi

# Владелец файлов
$RUN chown -R "$username:$username" "$INSTALL_PATH"

# Виртуальное окружение и зависимости
echo -e "\n${LINE}\nУстановка Python-зависимостей и Playwright...\n${LINE}"
REQUIREMENTS="$INSTALL_PATH/requirements.txt"
if [[ ! -f "$REQUIREMENTS" ]]; then
  echo -e "${RED}Файл requirements.txt не найден в $INSTALL_PATH${RESET}"
  exit 1
fi

$RUN -u "$username" bash -c "
  set -e
  cd '$INSTALL_PATH'
  python3 -m venv venv
  source venv/bin/activate
  pip install --upgrade pip -q
  pip install -r requirements.txt -q
  playwright install chromium
  playwright install-deps chromium || true
"

# Конфиг по умолчанию, если нет
CONFIG_PATH="$INSTALL_PATH/bot_settings/config.json"
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo -e "\n${YELLOW}Файл config.json не найден. Создаю шаблон. После установки отредактируйте: $CONFIG_PATH${RESET}"
  $RUN -u "$username" mkdir -p "$INSTALL_PATH/bot_settings"
  $RUN -u "$username" tee "$CONFIG_PATH" >/dev/null << 'CONFIG_EOF'
{
  "playerok": {
    "api": { "token": "", "user_agent": "", "proxy": "", "requests_timeout": 30 },
    "watermark": { "enabled": true, "value": "©️ Playerok PRO" },
    "read_chat": { "enabled": true },
    "first_message": { "enabled": true },
    "custom_commands": { "enabled": true },
    "auto_deliveries": { "enabled": true },
    "auto_restore_items": { "sold": true, "expired": false, "all": true },
    "auto_bump_items": { "enabled": false, "interval": 3600, "all": false },
    "auto_withdrawal": { "enabled": false, "interval": 86400, "credentials_type": "", "card_id": "", "sbp_bank_id": "", "sbp_phone_number": "", "usdt_address": "" },
    "auto_complete_deals": { "enabled": true },
    "tg_logging": { "enabled": true, "chat_id": "", "events": { "new_user_message": true, "new_system_message": true, "new_deal": true, "new_review": true, "new_problem": true, "deal_status_changed": true } }
  },
  "telegram": { "api": { "token": "" }, "bot": { "password": "", "signed_users": [] } },
  "logs": { "max_file_size": 30 }
}
CONFIG_EOF
fi

# Systemd unit
echo -e "\n${LINE}\nСоздание systemd-сервиса...\n${LINE}"
$RUN tee "/etc/systemd/system/${SERVICE_NAME}.service" >/dev/null << SERVICEEOF
[Unit]
Description=Playerok PRO Bot
After=network.target

[Service]
Type=simple
User=$username
WorkingDirectory=$INSTALL_PATH
Environment=PATH=$INSTALL_PATH/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$INSTALL_PATH/venv/bin/python bot.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

$RUN systemctl daemon-reload
$RUN systemctl enable "$SERVICE_NAME"
$RUN systemctl restart "$SERVICE_NAME"

echo -e "\n${LINE}"
echo -e "${GREEN}Установка завершена.${RESET}"
echo -e ""
echo -e "  Каталог бота:  ${CYAN}$INSTALL_PATH${RESET}"
echo -e "  Конфиг:        ${CYAN}$CONFIG_PATH${RESET}"
echo -e "  Сервис:        ${CYAN}$SERVICE_NAME${RESET}"
echo -e ""
echo -e "  Управление:"
echo -e "    ${YELLOW}sudo systemctl status $SERVICE_NAME${RESET}   — статус"
echo -e "    ${YELLOW}sudo systemctl restart $SERVICE_NAME${RESET} — перезапуск"
echo -e "    ${YELLOW}sudo systemctl stop $SERVICE_NAME${RESET}     — остановка"
echo -e "    ${YELLOW}sudo journalctl -u $SERVICE_NAME -f${RESET}    — логи в реальном времени"
echo -e ""
echo -e "  Не забудьте прописать Telegram токен и данные PlayerOk в config.json и перезапустить сервис."
echo -e "${LINE}\n"
