#!/bin/bash

# deploy_flutter_web.sh - Build và deploy Flutter Web lên server (nén/giải nén)
# Chạy trên Mac, từ thư mục root dự án Flutter
# Yêu cầu: Flutter, SSH key cho root@46.28.69.11, Docker Compose trên server

set -e

echo "=== DEPLOY FLUTTER WEB TO SERVER (NÉN/GIẢI NÉN) ==="

# Cấu hình server
SERVER_IP="46.28.69.11"
SERVER_USER="root"
SERVER_PATH="/home/web/build"
DOMAIN="eu.way4.app"
TEMP_TAR="/tmp/flutter_web_build.tar.gz"
COMPOSE_FILE="/home/n8n/docker-compose.yml"
CADDYFILE="/home/n8n/Caddyfile"

# Kiểm tra kết nối SSH
echo "🔍 Kiểm tra kết nối SSH tới $SERVER_USER@$SERVER_IP..."
if ! ssh -o ConnectTimeout=5 "$SERVER_USER@$SERVER_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo "❌ Không thể kết nối SSH tới $SERVER_USER@$SERVER_IP."
    echo "👉 Kiểm tra SSH key: ssh-copy-id $SERVER_USER@$SERVER_IP"
    echo "👉 Xóa host key cũ nếu cần: ssh-keygen -R $SERVER_IP"
    exit 1
fi

# Kiểm tra DNS
echo "🔍 Kiểm tra DNS cho $DOMAIN..."
SERVER_IP_CHECK=$(dig +short "$DOMAIN" | head -n1)
if [[ -z "$SERVER_IP_CHECK" || "$SERVER_IP_CHECK" != "$SERVER_IP" ]]; then
    echo "⚠️ DNS cho $DOMAIN không trỏ tới $SERVER_IP (hiện tại: $SERVER_IP_CHECK)."
    echo "👉 Cập nhật A record trong panel quản lý DNS."
fi

# Kiểm tra build
if [[ ! -d "build/web" ]]; then
    echo "❌ Build thất bại. Kiểm tra lỗi Flutter."
    exit 1
fi

# Nén thư mục build/web
echo "📦 Nén build/web thành $TEMP_TAR..."
rm -f "$TEMP_TAR"  # Xóa file nén cũ nếu có
tar -czf "$TEMP_TAR" -C build/web .

# Upload file nén
echo "📤 Upload $TEMP_TAR lên $SERVER_USER@$SERVER_IP:/tmp..."
scp "$TEMP_TAR" "$SERVER_USER@$SERVER_IP:/tmp/"

# SSH để xử lý trên server
echo "🔧 Giải nén, sửa quyền, và reload Caddy trên server..."
ssh "$SERVER_USER@$SERVER_IP" "
    # Backup thư mục hiện tại
    if [ -d \"$SERVER_PATH\" ]; then
        echo 'Sao lưu $SERVER_PATH...'
        cp -r \"$SERVER_PATH\" \"/home/web/build.bak_\$(date +%s)\"
    fi

    # Tạo thư mục và giải nén
    mkdir -p \"$SERVER_PATH\" &&
    rm -rf \"$SERVER_PATH\"/* &&
    tar -xzf /tmp/flutter_web_build.tar.gz -C \"$SERVER_PATH\"/ &&
    rm /tmp/flutter_web_build.tar.gz &&

    # Sửa quyền cho container Caddy
    chown -R 1000:1000 \"$SERVER_PATH\" &&
    chmod -R 755 \"$SERVER_PATH\" &&

    # Kiểm tra và thêm volume vào docker-compose.yml
    if ! grep -q \"$SERVER_PATH:/home/web/build\" \"$COMPOSE_FILE\"; then
        echo 'Thêm volume $SERVER_PATH vào $COMPOSE_FILE...'
        sed -i '/caddy:/,/networks:/ s|volumes:|volumes:\\n      - $SERVER_PATH:/home/web/build|' \"$COMPOSE_FILE\"
    fi &&

    # Format Caddyfile để loại bỏ cảnh báo
    if [ -f \"$CADDYFILE\" ]; then
        docker run --rm -v \"$CADDYFILE\":/Caddyfile caddy:2 caddy fmt --overwrite /Caddyfile
    fi &&

    # Restart Caddy qua Docker Compose
    cd /home/n8n &&
    docker-compose up -d
"

if [[ $? -ne 0 ]]; then
    echo "⚠️ Lỗi xử lý trên server. Kiểm tra log Caddy: ssh $SERVER_USER@$SERVER_IP 'docker logs n8n-caddy-1'"
    exit 1
fi

# Xóa file nén tạm trên local
rm -f "$TEMP_TAR"

echo "✅ Deploy hoàn tất!"
echo "👉 Web sẵn sàng tại: https://$DOMAIN"
echo "📜 Kiểm tra log Caddy: ssh $SERVER_USER@$SERVER_IP 'docker logs n8n-caddy-1'"
echo "⚠️ Nếu lỗi, kiểm tra DNS hoặc thử: curl -k http://localhost:80 -H \"Host: $DOMAIN\" (trên server)"