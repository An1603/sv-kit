#!/bin/bash
set -euo pipefail

echo "=== SV-KIT SETUP SCRIPT (Tối giản) ==="

# --- Hỏi domain nếu chưa có ENV ---
if [ -z "${N8N_DOMAIN:-}" ]; then
  read -rp "Nhập domain cho N8N (vd: n8n.example.com): " N8N_DOMAIN
fi

if [ -z "${FLUTTER_DOMAIN:-}" ]; then
  read -rp "Nhập domain cho Flutter Web (vd: app.example.com): " FLUTTER_DOMAIN
fi

echo "📌 Domain N8N: $N8N_DOMAIN"
echo "📌 Domain Flutter: $FLUTTER_DOMAIN"

# --- Update & cài Docker ---
echo "🐳 Cài đặt Docker & Docker Compose..."
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y docker.io docker-compose
  systemctl enable --now docker
else
  echo "✅ Docker đã cài."
fi

# --- Cài Nginx ---
echo "🌐 Cài đặt Nginx..."
if ! command -v nginx >/dev/null 2>&1; then
  apt-get install -y nginx
  systemctl enable --now nginx
else
  echo "✅ Nginx đã cài."
fi

# --- Tạo thư mục web ---
mkdir -p /var/www/$FLUTTER_DOMAIN
chown -R www-data:www-data /var/www/$FLUTTER_DOMAIN

# --- Config Nginx cho N8N ---
N8N_CONF="/etc/nginx/sites-available/$N8N_DOMAIN.conf"
cat > "$N8N_CONF" <<EOF
server {
    listen 80;
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
ln -sf "$N8N_CONF" /etc/nginx/sites-enabled/

# --- Config Nginx cho Flutter Web ---
FLUTTER_CONF="/etc/nginx/sites-available/$FLUTTER_DOMAIN.conf"
cat > "$FLUTTER_CONF" <<EOF
server {
    listen 80;
    server_name $FLUTTER_DOMAIN;

    root /var/www/$FLUTTER_DOMAIN;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOF
ln -sf "$FLUTTER_CONF" /etc/nginx/sites-enabled/

# --- Khởi động lại Nginx ---
echo "🔄 Restart Nginx..."
nginx -t && systemctl restart nginx

# --- Chạy n8n bằng Docker ---
echo "🚀 Chạy n8n với Docker..."
mkdir -p /opt/n8n
cat > /opt/n8n/docker-compose.yml <<EOF
version: "3.1"

services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - /opt/n8n:/home/node/.n8n
EOF

docker compose -f /opt/n8n/docker-compose.yml up -d

echo "✅ Setup hoàn tất!"
echo "👉 N8N: http://$N8N_DOMAIN"
echo "👉 Flutter Web: http://$FLUTTER_DOMAIN"
