#!/bin/bash
# setup.sh - Script cài đặt môi trường cho VPS Ubuntu 22.04
# Hỗ trợ: N8N + Flutter web + Nginx + SSL (Let's Encrypt)

set -e

# --- Nhập domain ---
if [ -z "$N8N_DOMAIN" ]; then
  read -p "👉 Nhập domain cho n8n (ví dụ: n8n.way4.app): " N8N_DOMAIN
fi

if [ -z "$WEB_DOMAIN" ]; then
  read -p "👉 Nhập domain cho Flutter web (ví dụ: eurobank.eu.com): " WEB_DOMAIN
fi

if [ -z "$N8N_DOMAIN" ] || [ -z "$WEB_DOMAIN" ]; then
  echo "❌ Bạn chưa nhập đủ domain!"
  exit 1
fi

echo "✅ Domain N8N: $N8N_DOMAIN"
echo "✅ Domain Web: $WEB_DOMAIN"

# --- Update hệ thống ---
echo "🔄 Update hệ thống..."
sudo apt-get update -y
sudo apt-get upgrade -y

# --- Cài Docker & Compose ---
if ! command -v docker &> /dev/null; then
  echo "🐳 Cài Docker..."
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker --now
else
  echo "✅ Docker đã được cài."
fi

if ! command -v docker compose &> /dev/null; then
  echo "🐳 Cài Docker Compose plugin..."
  sudo apt-get install -y docker-compose-plugin
fi

# --- Cài Nginx + Certbot ---
if ! command -v nginx &> /dev/null; then
  echo "🌐 Cài Nginx..."
  sudo apt-get install -y nginx
fi

if ! command -v certbot &> /dev/null; then
  echo "🔒 Cài Certbot..."
  sudo apt-get install -y certbot python3-certbot-nginx
fi

sudo systemctl enable nginx --now

# --- Tạo thư mục ---
sudo mkdir -p /var/www/eurobank
sudo chown -R www-data:www-data /var/www/eurobank

# --- Deploy N8N ---
echo "⚙️ Deploy n8n với Docker Compose..."
mkdir -p ~/n8n
cat > ~/n8n/docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin
      - WEBHOOK_URL=https://$N8N_DOMAIN/
EOF

docker compose -f ~/n8n/docker-compose.yml up -d

# --- Xóa config Nginx cũ nếu có ---
echo "⚠️ Tìm & xóa config Nginx cũ có chứa domain..."
for conf in /etc/nginx/sites-available/* /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*; do
  if [ -f "$conf" ] && (grep -q "$N8N_DOMAIN" "$conf" || grep -q "$WEB_DOMAIN" "$conf"); then
    echo "🗑️  Xóa $conf"
    sudo rm -f "$conf"
  fi
done

# --- Nginx config cho N8N ---
NGINX_CONF_N8N="/etc/nginx/sites-available/n8n.conf"
cat > ~/n8n.conf <<EOF
server {
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://localhost:5678/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo mv ~/n8n.conf $NGINX_CONF_N8N
sudo ln -sf $NGINX_CONF_N8N /etc/nginx/sites-enabled/

# --- Nginx config cho Flutter Web ---
NGINX_CONF_WEB="/etc/nginx/sites-available/eurobank.conf"
cat > ~/eurobank.conf <<EOF
server {
    server_name $WEB_DOMAIN;

    root /var/www/eurobank;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOF

sudo mv ~/eurobank.conf $NGINX_CONF_WEB
sudo ln -sf $NGINX_CONF_WEB /etc/nginx/sites-enabled/

# --- Kiểm tra & restart Nginx ---
echo "📝 Kiểm tra & restart Nginx..."
sudo nginx -t
sudo systemctl restart nginx || sudo systemctl start nginx

# --- Cài SSL ---
echo "🔒 Cài SSL với Let's Encrypt..."
sudo certbot --nginx -d $N8N_DOMAIN -d $WEB_DOMAIN --non-interactive --agree-tos -m admin@$N8N_DOMAIN || true

echo "🎉 Hoàn tất cài đặt!"
echo "👉 N8N: https://$N8N_DOMAIN"
echo "👉 Flutter web: https://$WEB_DOMAIN"
