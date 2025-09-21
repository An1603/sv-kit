#!/bin/bash
set -e

# =============================
# Setup n8n + Flutter web + Nginx + SSL
# =============================

# --- Hỏi domain cho n8n nếu chưa có ---
if [ -z "$N8N_DOMAIN" ]; then
  read -p "👉 Nhập domain cho n8n (ví dụ: n8n.way4.app): " N8N_DOMAIN
  if [ -z "$N8N_DOMAIN" ]; then
    echo "❌ Bạn chưa nhập domain cho n8n!"
    exit 1
  fi
fi

# --- Cập nhật hệ thống ---
echo "📦 Cập nhật hệ thống..."
sudo apt-get update -y
sudo apt-get upgrade -y

# --- Cài đặt Docker & Docker Compose nếu chưa có ---
if ! command -v docker &> /dev/null; then
  echo "🐳 Cài đặt Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo systemctl enable docker --now
fi

if ! command -v docker-compose &> /dev/null; then
  echo "🐙 Cài đặt Docker Compose..."
  sudo apt-get install -y docker-compose
fi

# --- Cài đặt Nginx ---
if ! command -v nginx &> /dev/null; then
  echo "🌐 Cài đặt Nginx..."
  sudo apt-get install -y nginx
  sudo systemctl enable nginx
  sudo systemctl start nginx
fi

# --- Xóa config cũ nếu tồn tại ---
NGINX_CONF="/etc/nginx/sites-available/n8n.conf"
if [ -f "$NGINX_CONF" ]; then
  echo "⚠️ Xóa config Nginx cũ cho $N8N_DOMAIN..."
  sudo rm -f "$NGINX_CONF"
  sudo rm -f /etc/nginx/sites-enabled/n8n.conf || true
fi

# --- Tạo config Nginx mới ---
echo "📝 Tạo config Nginx cho n8n ($N8N_DOMAIN)..."
cat <<EOF | sudo tee /etc/nginx/sites-available/n8n.conf > /dev/null
server {
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://localhost:5678/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_http_version 1.1;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/n8n.conf

# --- Test & restart Nginx ---
echo "🔄 Kiểm tra & restart Nginx..."
if sudo nginx -t; then
  sudo systemctl stop nginx
  sleep 2
  sudo systemctl start nginx || {
    echo "❌ Không thể start nginx, thử kill tiến trình cũ..."
    sudo pkill -9 nginx || true
    sudo systemctl start nginx
  }
else
  echo "❌ Cấu hình Nginx lỗi, dừng setup!"
  exit 1
fi

# --- Cài Certbot để cấp SSL ---
if ! command -v certbot &> /dev/null; then
  echo "🔐 Cài đặt Certbot..."
  sudo apt-get install -y certbot python3-certbot-nginx
fi

echo "🔐 Xin chứng chỉ SSL cho $N8N_DOMAIN..."
sudo certbot --nginx -d $N8N_DOMAIN --non-interactive --agree-tos -m admin@$N8N_DOMAIN || true

# --- Setup thư mục cho Flutter Web ---
echo "📂 Tạo thư mục cho Flutter web..."
sudo mkdir -p /var/www/eurobank
sudo chown -R www-data:www-data /var/www/eurobank

# --- Docker Compose cho n8n ---
echo "🐳 Setup n8n bằng Docker Compose..."
mkdir -p ~/n8n
cat <<EOF > ~/n8n/docker-compose.yml
services:
  n8n:
    image: n8nio/n8n
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
    restart: always
EOF

cd ~/n8n
docker-compose up -d

echo "✅ Setup hoàn tất!"
echo "🌐 Truy cập n8n tại: https://$N8N_DOMAIN"
