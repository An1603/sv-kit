#!/bin/bash
set -e

echo "=== SV-KIT N8N SETUP ==="

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Nhập domain
read -rp "Nhập domain cho N8N (vd: n8n.example.com): " N8N_DOMAIN
if [[ -z "$N8N_DOMAIN" ]]; then
    echo "Bạn chưa nhập domain!"
    exit 1
fi

# Kiểm tra domain trỏ về server
SERVER_IP=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short $N8N_DOMAIN)

if [[ "$SERVER_IP" != "$DOMAIN_IP" ]]; then
    echo "Domain $N8N_DOMAIN chưa trỏ về server $SERVER_IP."
    exit 1
fi

echo "📦 Cập nhật server..."
apt update -y && apt upgrade -y

# Cài Docker nếu chưa có
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Cài Docker..."
    apt install -y docker.io docker-compose
    systemctl enable docker --now
fi

# Cài Caddy nếu chưa có
if ! command -v caddy >/dev/null 2>&1; then
    echo "🛡 Cài Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
fi

# Backup Caddyfile cũ
CADDYFILE="/etc/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
    cp "$CADDYFILE" "${CADDYFILE}.bak_$(date +%s)"
fi

# Tạo Caddyfile mới
cat > "$CADDYFILE" <<EOF
$N8N_DOMAIN {
    reverse_proxy localhost:5678
    encode gzip
    tls admin@$N8N_DOMAIN
}
EOF

# Chạy Docker n8n
echo "🚀 Khởi chạy n8n..."
mkdir -p /opt/n8n
cat > /opt/n8n/docker-compose.yml <<EOL
version: '3'
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme
EOL

docker-compose -f /opt/n8n/docker-compose.yml up -d

# Restart Caddy an toàn
if ! systemctl is-active --quiet caddy; then
    systemctl start caddy
fi
systemctl enable caddy
caddy validate --config "$CADDYFILE" || { echo "❌ Caddy config lỗi, rollback..."; mv "${CADDYFILE}.bak_$(date +%s)" "$CADDYFILE"; systemctl restart caddy; exit 1; }
systemctl reload caddy

echo "✅ Setup hoàn tất!"
echo "👉 N8N: https://$N8N_DOMAIN"
echo "⚠️ Đừng quên đổi password n8n trong /opt/n8n/docker-compose.yml trước khi đưa vào production!"
