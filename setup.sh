#!/bin/bash
set -e

# ==============================
# Biến môi trường
# ==============================
if [ -z "$N8N_DOMAIN" ]; then
  read -p "🌐 Nhập domain cho n8n (ví dụ: way4.app): " N8N_DOMAIN
  if [ -z "$N8N_DOMAIN" ]; then
    echo "❌ Bạn chưa nhập domain cho n8n!"
    exit 1
  fi
fi

if [ -z "$WEB_DOMAIN" ]; then
  read -p "🌐 Nhập domain cho Flutter Web (ví dụ: eurobank.eu.com): " WEB_DOMAIN
  if [ -z "$WEB_DOMAIN" ]; then
    echo "❌ Bạn chưa nhập domain cho Flutter web!"
    exit 1
  fi
fi

# ==============================
# Update hệ thống & cài gói cần thiết
# ==============================
echo "📦 Cập nhật hệ thống..."
sudo apt update -y
sudo apt upgrade -y

echo "📦 Cài đặt Docker & Docker Compose..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

if ! command -v docker-compose &> /dev/null; then
  sudo apt install -y docker-compose
fi

echo "📦 Cài đặt Nginx & Certbot..."
sudo apt install -y nginx certbot python3-certbot-nginx

# ==============================
# Setup Nginx (Khởi động nếu chưa chạy)
# ==============================
if ! pgrep -x "nginx" > /dev/null; then
  echo "🚀 Khởi động Nginx lần đầu..."
  sudo systemctl enable nginx
  sudo systemctl start nginx
else
  echo "✅ Nginx đã chạy"
fi

# ==============================
# Setup n8n với Docker
# ==============================
echo "⚙️ Cài đặt n8n..."
mkdir -p /opt/n8n
cat <<EOF | sudo tee /opt/n8n/docker-compose.yml > /dev/null
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - /opt/n8n/data:/home/node/.n8n
    environment:
      - N8N_HOST=$N8N_DOMAIN
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
EOF

sudo docker-compose -f /opt/n8n/docker-compose.yml up -d

# ==============================
# Cấu hình Nginx cho n8n
# ==============================
N8N_CONF="/etc/nginx/sites-available/n8n"
sudo tee $N8N_CONF > /dev/null <<EOF
server {
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
    }
}
EOF

sudo ln -sf $N8N_CONF /etc/nginx/sites-enabled/n8n

# ==============================
# Cấu hình Nginx cho Flutter Web
# ==============================
WEB_CONF="/etc/nginx/sites-available/flutter_web"
sudo mkdir -p /var/www/$WEB_DOMAIN
sudo tee $WEB_CONF > /dev/null <<EOF
server {
    server_name $WEB_DOMAIN;

    root /var/www/$WEB_DOMAIN;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOF

sudo ln -sf $WEB_CONF /etc/nginx/sites-enabled/flutter_web

# ==============================
# Reload Nginx & cấp SSL
# ==============================
echo "🔄 Kiểm tra cấu hình Nginx..."
sudo nginx -t

echo "🔄 Restart Nginx..."
sudo systemctl restart nginx

echo "🔐 Cấp SSL bằng Let's Encrypt..."
sudo certbot --nginx -d $N8N_DOMAIN -d $WEB_DOMAIN --non-interactive --agree-tos -m admin@$N8N_DOMAIN

echo "✅ Hoàn tất cài đặt!"
echo "👉 n8n: https://$N8N_DOMAIN"
echo "👉 Flutter Web: https://$WEB_DOMAIN"
