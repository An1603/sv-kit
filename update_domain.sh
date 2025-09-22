#!/bin/bash

# update_domain.sh - Cập nhật tên miền từ eu.way4.app sang eurobank.eu.com
# Chạy trên Mac, yêu cầu SSH key cho root@46.28.69.11
# Cập nhật /etc/caddy/Caddyfile trên server và reload Caddy

set -e

echo "=== CẬP NHẬT TÊN MIỀN WEB TỪ eu.way4.app SANG eurobank.eu.com ==="

# Cấu hình server
SERVER_IP="46.28.69.11"
SERVER_USER="root"
CADDYFILE="/etc/caddy/Caddyfile"
OLD_DOMAIN="eu.way4.app"
NEW_DOMAIN="eurobank.eu.com"
TEMP_CADDYFILE="/tmp/Caddyfile.tmp"

# Kiểm tra SSH key
echo "🔑 Kiểm tra kết nối SSH..."
if ! ssh -q "$SERVER_USER@$SERVER_IP" "echo 'Connected'"; then
    echo "❌ Lỗi SSH. Thiết lập SSH key: ssh-keygen && ssh-copy-id root@$SERVER_IP"
    exit 1
fi

# Kiểm tra DNS
echo "📡 Kiểm tra DNS cho $NEW_DOMAIN..."
SERVER_IP_LOCAL=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short "$NEW_DOMAIN" | tail -n 1)
if [[ -z "$DOMAIN_IP" || "$SERVER_IP_LOCAL" != "$DOMAIN_IP" ]]; then
    echo "❌ $NEW_DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $DOMAIN_IP)."
    echo "Vui lòng cập nhật DNS A record cho $NEW_DOMAIN và thử lại."
    exit 1
fi

# Tạo Caddyfile mới trên local
echo "📝 Tạo Caddyfile tạm thời..."
cat > "$TEMP_CADDYFILE" <<EOF
n8n.way4.app {
    reverse_proxy localhost:5678
    encode gzip
    tls
}

$NEW_DOMAIN {
    root * /opt/web/build
    file_server
    encode gzip
    tls
}
EOF

# Upload Caddyfile mới lên server
echo "📤 Upload Caddyfile mới lên $SERVER_USER@$SERVER_IP:/tmp..."
scp "$TEMP_CADDYFILE" "$SERVER_USER@$SERVER_IP:/tmp/Caddyfile.tmp"

# SSH để kiểm tra, sao lưu, thay thế Caddyfile, và reload Caddy
echo "🔧 Cập nhật Caddyfile và reload Caddy trên server..."
ssh "$SERVER_USER@$SERVER_IP" "
    # Sao lưu Caddyfile hiện tại
    if [[ -f '$CADDYFILE' ]]; then
        cp '$CADDYFILE' '$CADDYFILE.bak_$(date +%s)'
    fi
    # Kiểm tra Caddyfile tạm
    if ! caddy validate --config /tmp/Caddyfile.tmp; then
        echo '❌ Caddyfile tạm không hợp lệ!'
        exit 1
    fi
    # Thay thế Caddyfile
    mv /tmp/Caddyfile.tmp '$CADDYFILE'
    chown caddy:caddy '$CADDYFILE'
    chmod 644 '$CADDYFILE'
    # Reload Caddy
    systemctl reload caddy
"

if [[ $? -ne 0 ]]; then
    echo "⚠️ Lỗi cập nhật trên server. Kiểm tra log: ssh root@$SERVER_IP 'journalctl -xeu caddy.service'"
    exit 1
fi

# Dọn dẹp file tạm trên local
rm -f "$TEMP_CADDYFILE"

echo "✅ Cập nhật tên miền hoàn tất!"
echo "👉 Web sẵn sàng tại: https://$NEW_DOMAIN"
echo "👉 n8n không bị ảnh hưởng: https://n8n.way4.app"
echo "📜 Kiểm tra log Caddy: ssh root@$SERVER_IP 'journalctl -xeu caddy.service'"