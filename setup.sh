#!/bin/bash
set -e

# ===============================
# Config
# ===============================
export DEBIAN_FRONTEND=noninteractive

# Lấy domain cho n8n từ ENV hoặc hỏi người dùng
if [ -z "$N8N_DOMAIN" ]; then
  read -p "👉 Nhập domain cho n8n (ví dụ: n8n.way4.app): " N8N_DOMAIN
fi

if [ -z "$N8N_DOMAIN" ]; then
  echo "❌ Bạn chưa nhập domain cho n8n!"
  exit 1
fi

echo "✅ Domain cho n8n: $N8N_DOMAIN"

# ===============================
# Update hệ thống và cài tool
# ===============================
echo "📦 Đang cài đặt packages cần thiết..."
apt-get update -y
apt-get install -y curl wget gnupg2 ca-certificates lsb-release software-properties-common git unzip

# ===============================
# Cài Docker + Docker Compose nếu chưa có
# ===============================
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Cài Docker..."
  curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "🐳 Cài Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# ===============================
# Cài đặt Nginx + Certbot nếu chưa có
# ===============================
if ! command -v nginx >/dev/null 2>&1; then
  echo "🌐 Cài đặt Nginx..."
  apt-get install -y nginx
fi

if ! command -v certbot >/dev/null 2>&1; then
  echo "🔐 Cài đặt Certbot..."
  apt-get install -y certbot python3-certbot-nginx
fi

# ===============================
# Deploy n8n bằng Docker
# ===============================
mkdir -p /opt/n8n
cd /opt/n8n

cat > docker-compose.yml <<EOF
version: "3"
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin123
      - N8N_HOST=$N8N_DOMAIN
      - N8N_PROTOCOL=https
      - NODE_ENV=production
    volumes:
      - .n8n:/home/node/.n8n
EOF

docker-compose up -d

# ===============================
# Cấu hình Nginx cho n8n
# ===============================
NGINX_CONF="/etc/nginx/sites-available/n8n.conf"

cat > $NGINX_CONF <<EOF
server {
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf $NGINX_CONF /etc/nginx/sites-enabled/n8n.conf
nginx -t && systemctl reload nginx

# ===============================
# SSL với Certbot
# ===============================
echo "🔑 Đang cấp SSL cho $N8N_DOMAIN..."
certbot --nginx -d $N8N_DOMAIN --non-interactive --agree-tos -m admin@$N8N_DOMAIN || true

echo "✅ Cài đặt xong! Truy cập n8n tại: https://$N8N_DOMAIN"
