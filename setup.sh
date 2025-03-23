set -e

NEW_USER="devadmin"
PUB_KEY_URL="https://example.com/id_rsa.pub"
BACKUP_SCRIPT="/usr/local/bin/backup.sh"

echo "[1/6] Обновление системы..."
apt update && apt upgrade -y

echo "[2/6] Создание пользователя '$NEW_USER'..."
adduser --disabled-password --gecos "" "$NEW_USER"
usermod -aG sudo "$NEW_USER"

echo "[3/6] Настройка SSH..."
mkdir -p /home/$NEW_USER/.ssh
curl -fsSL "$PUB_KEY_URL" -o /home/$NEW_USER/.ssh/authorized_keys
chmod 600 /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

echo "[4/6] Установка и настройка fail2ban..."
apt install -y fail2ban
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = systemd
maxretry = 3
EOF
systemctl enable fail2ban
systemctl restart fail2ban

echo "[5/6] Настройка UFW..."
ufw allow OpenSSH
ufw allow http
ufw allow https
ufw --force enable

echo "[6/6] Cron-задача на бэкап /etc"
cat > "$BACKUP_SCRIPT" <<'EOB'
#!/bin/bash
tar -czf /var/backups/etc-backup-$(date +%F).tar.gz /etc
EOB

chmod +x "$BACKUP_SCRIPT"
(crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT") | crontab -

echo "Готово. Сервер защищён и подготовлен."