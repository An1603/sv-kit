

# n8n_backup_migrate.sh - Backup n8n từ server cũ (149.28.158.156) và restore sang server mới (46.28.69.11)
# Chạy trên Mac, yêu cầu SSH key cho cả hai server
# Không ảnh hưởng đến Caddy hoặc eu.way4.app
# curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_backup_migrate.sh > n8n_backup_migrate.sh && chmod +x n8n_backup_migrate.sh && sudo ./n8n_backup_migrate.sh

#!/bin/bash

set -e

echo "=== BACKUP & MIGRATE N8N DATA (Workflows, Credentials, Executions) ==="

# Cấu hình server
OLD_SERVER_IP="149.28.158.156"  # Server cũ
NEW_SERVER_IP="46.28.69.11"     # Server mới
SERVER_USER="root"
OLD_N8N_DIR="/home/n8n"
NEW_N8N_DIR="/opt/n8n"
BACKUP_DIR="/tmp/n8n_backup_$(date +%Y%m%d_%H%M%S)"
VOLUME_BACKUP_FILE="$BACKUP_DIR/n8n_data.tar.gz"
ENCRYPTION_KEY_FILE="$BACKUP_DIR/n8n_encryption_key.txt"

# Kiểm tra SSH kết nối
echo "🔑 Kiểm tra kết nối SSH..."
for IP in "$OLD_SERVER_IP" "$NEW_SERVER_IP"; do
    if ! ssh -q -o ConnectTimeout=5 "$SERVER_USER@$IP" "echo 'Connected'" 2>/dev/null; then
        echo "❌ Lỗi SSH đến $IP. Thiết lập SSH key: ssh-keygen -t rsa && ssh-copy-id root@$IP"
        exit 1
    fi
done

# Kiểm tra DNS (đảm bảo domain trỏ đúng)
echo "📡 Kiểm tra DNS cho n8n.way4.app và eu.way4.app..."
for DOMAIN in n8n.way4.app eu.way4.app; do
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n 1)
    if [[ -z "$DOMAIN_IP" || "$DOMAIN_IP" != "$NEW_SERVER_IP" ]]; then
        echo "⚠️ $DOMAIN không trỏ về $NEW_SERVER_IP (IP nhận được: $DOMAIN_IP)."
        echo "Cập nhật DNS A record và thử lại."
        exit 1
    fi
done

# Tạo thư mục backup local
mkdir -p "$BACKUP_DIR"

# Backup từ server cũ
echo "📦 Backup từ server cũ ($OLD_SERVER_IP)..."
ssh "$SERVER_USER@$OLD_SERVER_IP" "
    if [ ! -f '$OLD_N8N_DIR/docker-compose.yml' ]; then
        echo '❌ Không tìm thấy $OLD_N8N_DIR/docker-compose.yml'
        exit 1
    fi
    cd '$OLD_N8N_DIR' &&
    docker-compose down &&
    docker volume inspect n8n_data > /dev/null || { echo '❌ Volume n8n_data không tồn tại'; exit 1; } &&
    tar -czf /root/n8n_data.tar.gz -C /var/lib/docker/volumes/n8n_data/_data . &&
    grep N8N_ENCRYPTION_KEY docker-compose.yml > /root/n8n_encryption_key.txt 2>/dev/null || echo 'N8N_ENCRYPTION_KEY=\$(openssl rand -base64 32)' > /root/n8n_encryption_key.txt &&
    docker-compose up -d
"

# Tải backup về local
echo "📥 Tải backup về local..."
scp "$SERVER_USER@$OLD_SERVER_IP:/root/n8n_data.tar.gz" "$VOLUME_BACKUP_FILE"
scp "$SERVER_USER@$OLD_SERVER_IP:/root/n8n_encryption_key.txt" "$ENCRYPTION_KEY_FILE"

# Kiểm tra server mới: đã có n8n chưa?
echo "🔍 Kiểm tra server mới ($NEW_SERVER_IP)..."
if ssh "$SERVER_USER@$NEW_SERVER_IP" "[ -d '$NEW_N8N_DIR' ] && [ -f '$NEW_N8N_DIR/docker-compose.yml' ]"; then
    echo "n8n đã tồn tại trên server mới, chỉ restore dữ liệu."
else
    echo "🚀 Setup n8n mới trên server ($NEW_SERVER_IP)..."
    ssh "$SERVER_USER@$NEW_SERVER_IP" "
        apt update && apt install -y docker.io docker-compose &&
        systemctl enable docker --now &&
        mkdir -p '$NEW_N8N_DIR' &&
        cat > '$NEW_N8N_DIR/docker-compose.yml' <<'EOL'
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
      - N8N_HOST=n8n.way4.app
      - N8N_PROTOCOL=https
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOL
    "
fi

# Upload backup lên server mới
echo "📤 Upload backup lên server mới..."
scp "$VOLUME_BACKUP_FILE" "$SERVER_USER@$NEW_SERVER_IP:/root/"
scp "$ENCRYPTION_KEY_FILE" "$SERVER_USER@$NEW_SERVER_IP:/root/"

# Restore trên server mới
echo "🔄 Restore dữ liệu trên server mới..."
ssh "$SERVER_USER@$NEW_SERVER_IP" "
    cd '$NEW_N8N_DIR' &&
    docker-compose down || true &&
    docker volume rm n8n_data || true &&
    docker volume create n8n_data &&
    mkdir -p /var/lib/docker/volumes/n8n_data/_data &&
    tar -xzf /root/n8n_data.tar.gz -C /var/lib/docker/volumes/n8n_data/_data . &&
    KEY=\$(cat /root/n8n_encryption_key.txt | cut -d'=' -f2-) &&
    grep -q N8N_ENCRYPTION_KEY docker-compose.yml || echo '      - N8N_ENCRYPTION_KEY=\$KEY' >> docker-compose.yml &&
    sed -i \"s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=\$KEY/\" docker-compose.yml &&
    rm /root/n8n_data.tar.gz /root/n8n_encryption_key.txt &&
    docker-compose up -d &&
    echo '✅ Restore hoàn tất trên server mới!'
"

# Kiểm tra Caddyfile để đảm bảo không bị ảnh hưởng
echo "🔍 Kiểm tra Caddyfile trên server mới..."
ssh "$SERVER_USER@$NEW_SERVER_IP" "
    if grep -q 'n8n.way4.app' /etc/caddy/Caddyfile && grep -q 'eu.way4.app' /etc/caddy/Caddyfile; then
        echo 'Caddyfile OK, domain n8n.way4.app và eu.way4.app không bị ảnh hưởng.'
    else
        echo '⚠️ Cảnh báo: Caddyfile có thể thiếu cấu hình cho n8n.way4.app hoặc eu.way4.app.'
        echo 'Kiểm tra: cat /etc/caddy/Caddyfile'
        echo 'Khôi phục nếu cần: cp /etc/caddy/Caddyfile.bak* /etc/caddy/Caddyfile && systemctl reload caddy'
    fi
"

# Dọn dẹp local
rm -rf "$BACKUP_DIR"

echo "✅ Backup & Migrate hoàn tất!"
echo "👉 Kiểm tra n8n: https://n8n.way4.app (Username: admin, Password: changeme hoặc từ $NEW_N8N_DIR/docker-compose.yml)"
echo "👉 Kiểm tra web: https://eu.way4.app (nên không bị ảnh hưởng)"
echo "📜 Log n8n: ssh root@$NEW_SERVER_IP 'docker logs n8n-n8n-1'"
echo "📜 Log Caddy: ssh root@$NEW_SERVER_IP 'journalctl -xeu caddy.service'"
echo "⚠️ Nếu đổi domain, cập nhật /etc/caddy/Caddyfile và reload: systemctl reload caddy"