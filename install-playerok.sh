#!/bin/bash
set -e

# =========================================================
#  УСТАНОВКА PLAYEROK PRO И СЕРВИСА
#  Скрипт запускается ТОЛЬКО от root (под sudo не надо).
# =========================================================

if [[ "$EUID" -ne 0 ]]; then
  echo "Этот скрипт нужно запускать от root (например, сразу после ssh root@IP)."
  exit 1
fi

ARCHIVE_URL="https://github.com/denchikr/plaerokpro/raw/main/playerok-pro.rar"
INSTALL_DIR="/opt/playerok-pro"
SERVICE_NAME="playerok"

echo "=== Установка зависимостей (apt update, wget, unrar) ==="
apt update
apt install -y wget unrar

echo
read -rp "Введите имя Linux-пользователя, от которого будет работать бот (например: playerok): " APP_USER

while ! [[ "$APP_USER" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; do
  echo "Имя должно начинаться с буквы и содержать только a-z, A-Z, 0-9, _ или -."
  read -rp "Введите имя ещё раз: " APP_USER
done

if id "$APP_USER" >/dev/null 2>&1; then
  echo "Пользователь $APP_USER уже существует, используем его."
else
  echo "Создаю пользователя $APP_USER..."
  useradd -m -s /bin/bash "$APP_USER"
fi

echo "Создаю директорию установки: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
chown "$APP_USER":"$APP_USER" "$INSTALL_DIR"

echo "Скачиваю архив проекта в $INSTALL_DIR/playerok-pro.rar"
sudo -u "$APP_USER" bash -lc "cd '$INSTALL_DIR' && wget -O playerok-pro.rar '$ARCHIVE_URL'"

echo "Распаковываю архив..."
sudo -u "$APP_USER" bash -lc "cd '$INSTALL_DIR' && unrar x -y playerok-pro.rar"

echo
echo "=== ВАЖНО: команда запуска бота ==="
echo "Введите КОМАНДУ, которой вы обычно запускаете бота,"
echo "например: python3 main.py   или   python3 bot.py   или   node index.js"
read -rp "Команда запуска: " START_CMD

if [[ -z "$START_CMD" ]]; then
  echo "Команда запуска не может быть пустой."
  exit 1
fi

if [[ "$START_CMD" == *"'"* ]]; then
  echo "Команда не должна содержать одинарные кавычки (')."
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "Создаю systemd-сервис: $SERVICE_FILE"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=PlayerOK Pro Bot
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash -lc '$START_CMD'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Перезапускаю systemd и включаю сервис..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service"

echo
echo "=============================================="
echo "Установка завершена."
echo "Сервис: ${SERVICE_NAME}.service"
echo "Директория проекта: $INSTALL_DIR"
echo
echo "Проверить статус:  systemctl status ${SERVICE_NAME}.service"
echo "Логи в реальном времени: journalctl -u ${SERVICE_NAME}.service -f"
echo "=============================================="
