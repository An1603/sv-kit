#!/bin/bash
# n8n_restore.sh - Restore n8n từ Google Drive trên server mới
# Chạy trên server mới, yêu cầu rclone và SSH key
# ssh -L 53682:localhost:53682 root@46.28.69.11
# curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_restore.sh > n8n_restore.sh && chmod +x n8n_restore.sh && sudo ./n8n_restore.sh

set -e

echo "=== RESTORE N8N DATA FROM GOOGLE DRIVE ==="

# Cấu hình
RCLONE_REMOTE="gdrive:n8n-backups"
BACKUP_DATE="20250922_020000"  # Thay bằng ngày backup thực tế (YYYYMMDD_HHMMSS)
BACKUP_FILE="/root/n8n_backup_$BACKUP_DATE.tar.gz"
KEY_FILE="/root/n8n_encryption_key_$BACKUP_DATE.txt"

# Kiểm tra và cài rclone
if ! command -v rclone >/dev/null 2>&1; then
    echo "📦 Cài đặt rclone..."
    curl https://rclone.org/install.sh | bash
fi

# Kiểm tra remote gdrive
if ! rclone listremotes | grep -q "^gdrive:$"; then
    echo "❌ Remote 'gdrive' chưa được cấu hình! Chạy 'rclone config'."
    exit 1
fi

# Tải backup từ Google Drive
echo "📥 Tải backup từ Google Drive..."
rclone copy "$RCLONE_REMOTE/n8n_backup_$BACKUP_DATE.tar.gz" "$BACKUP_FILE" --progress
rclone copy "$RCLONE_REMOTE/n8n_encryption_key_$BACKUP_DATE.txt" "$KEY_FILE" --progress

# Cài Docker nếu chưa có
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Cài Docker..."
    apt update && apt install -y docker.io docker-compose
    systemctl enable docker --now
fi

# Setup n8n Docker Compose
echo "🚀 Setup n8n Docker Compose..."
mkdir -p /opt/n8n
cat > /opt/n8n/docker-compose.yml <<EOL
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - '5678:5678'
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
      - N8N_HOST=n8n.way4.app  # Thay domain mới nếu cần
      - N8N_PROTOCOL=https
      - N8N_ENCRYPTION_KEY=
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOL

# Restore
echo "🔄 Restore dữ liệu..."
cd /opt/n8n
docker-compose down || true
docker volume rm n8n_n8n_data || true
docker volume create n8n_n8n_data
tar -xzf "$BACKUP_FILE" -C /var/lib/docker/volumes/n8n_n8n_data/_data .
KEY=$(cat "$KEY_FILE" | cut -d'=' -f2-)
sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$KEY/" docker-compose.yml
rm "$BACKUP_FILE" "$KEY_FILE"
docker-compose up -d

echo "✅ Restore hoàn tất!"
echo "👉 Kiểm tra n8n: https://n8n.way4.app (thay domain nếu cần)"
echo "📜 Log: docker logs n8n-n8n-1"
echo "⚠️ Cập nhật Caddyfile nếu dùng domain mới."