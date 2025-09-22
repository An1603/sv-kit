#!/bin/bash

# n8n_backup_migrate.sh - Backup n8n từ server cũ và restore sang server mới
# Chạy trên Mac, yêu cầu SSH key cho OLD_SERVER_IP và NEW_SERVER_IP

set -e

echo "=== BACKUP & MIGRATE N8N DATA (Workflows, Credentials, Executions) ==="

# Cấu hình server
OLD_SERVER_IP="46.28.69.11"  # Server cũ
NEW_SERVER_IP="NEW_SERVER_IP"  # Thay bằng IP server mới
SERVER_USER="root"
BACKUP_DIR="/tmp/n8n_backup_$(date +%Y%m%d_%H%M%S)"
ENCRYPTION_KEY_FILE="$BACKUP_DIR/n8n_encryption_key.txt"
VOLUME_BACKUP_FILE="$BACKUP_DIR/n8n_data.tar.gz"

# Kiểm tra SSH kết nối
for IP in "$OLD_SERVER_IP" "$NEW_SERVER_IP"; do
    if ! ssh -q "$SERVER_USER@$IP" "echo 'Connected'"; then
        echo "❌ Lỗi SSH đến $IP. Thiết lập SSH key: ssh-keygen && ssh-copy-id root@$IP"
        exit 1
    fi
done

# Tạo thư mục backup local
mkdir -p "$BACKUP_DIR"

# Backup từ server cũ
echo "📦 Backup từ server cũ ($OLD_SERVER_IP)..."
ssh "$SERVER_USER@$OLD_SERVER_IP" "
    cd /opt/n8n &&
    docker-compose down &&
    docker volume inspect n8n_n8n_data > /dev/null || { echo '❌ Volume n8n_n8n_data không tồn tại'; exit 1; } &&
    tar -czf /root/n8n_data.tar.gz -C /var/lib/docker/volumes/n8n_n8n_data/_data . &&
    grep -q N8N_ENCRYPTION_KEY docker-compose.yml && grep N8N_ENCRYPTION_KEY docker-compose.yml > /root/n8n_encryption_key.txt || echo 'N8N_ENCRYPTION_KEY=your_key_here' > /root/n8n_encryption_key.txt &&
    docker-compose up -d
"

# Tải backup về local
scp "$SERVER_USER@$OLD_SERVER_IP:/root/n8n_data.tar.gz" "$VOLUME_BACKUP_FILE"
scp "$SERVER_USER@$OLD_SERVER_IP:/root/n8n_encryption_key.txt" "$ENCRYPTION_KEY_FILE"

# Setup server mới (nếu chưa có Docker/n8n)
echo "🚀 Setup cơ bản trên server mới ($NEW_SERVER_IP)..."
ssh "$SERVER_USER@$NEW_SERVER_IP" "
    apt update && apt install -y docker.io docker-compose &&
    systemctl enable docker --now &&
    mkdir -p /opt/n8n &&
    cat > /opt/n8n/docker-compose.yml <<'EOL'
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
      - N8N_BASIC_AUTH_PASSWORD=changeme  # Đổi sau
      - N8N_HOST=n8n.way4.app  # Thay domain mới nếu cần
      - N8N_PROTOCOL=https
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOL
"

# Upload backup lên server mới
scp "$VOLUME_BACKUP_FILE" "$SERVER_USER@$NEW_SERVER_IP:/root/"
scp "$ENCRYPTION_KEY_FILE" "$SERVER_USER@$NEW_SERVER_IP:/root/"

# Restore trên server mới
echo "🔄 Restore dữ liệu trên server mới..."
ssh "$SERVER_USER@$NEW_SERVER_IP" "
    cd /opt/n8n &&
    docker-compose down || true &&
    docker volume rm n8n_n8n_data || true &&
    docker volume create n8n_n8n_data &&
    tar -xzf /root/n8n_data.tar.gz -C /var/lib/docker/volumes/n8n_n8n_data/_data . &&
    KEY=\$(cat /root/n8n_encryption_key.txt | cut -d'=' -f2-) &&
    sed -i \"s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=\$KEY/\" docker-compose.yml &&
    rm /root/n8n_data.tar.gz /root/n8n_encryption_key.txt &&
    docker-compose up -d &&
    echo '✅ Restore hoàn tất trên server mới!'
"

# Dọn dẹp local
rm -rf "$BACKUP_DIR"

echo "✅ Backup & Migrate hoàn tất!"
echo "👉 Kiểm tra n8n mới: https://n8n.way4.app (thay domain nếu cần)"
echo "👤 Username: admin | 🔑 Password: changeme (đổi trong /opt/n8n/docker-compose.yml)"
echo "📜 Log: ssh root@$NEW_SERVER_IP 'docker logs n8n-n8n-1'"
echo "⚠️ Cập nhật Caddyfile trên server mới nếu cần domain khác."