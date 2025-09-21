#!/bin/bash
set -e
source <(curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/utils.sh)

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  error "Bạn cần truyền domain khi chạy script!"
  echo "👉 Ví dụ: ./setup.sh domain.com"
  exit 1
fi

log "🔄 Bắt đầu cài đặt môi trường VPS cho domain: $DOMAIN ..."

log "📦 Cập nhật hệ thống..."
sudo dnf update -y

log "📦 Cài Nginx..."
sudo dnf install -y epel-release
sudo dnf install -y nginx

log "📦 Cài Node.js (dùng cho Flutter web tool nếu cần)..."
sudo dnf module install -y nodejs:14

log "🚀 Khởi động và bật Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

log "📂 Tạo thư mục f_web..."
sudo mkdir -p /var/www/f_web/releases
sudo mkdir -p /var/www/f_web/current
sudo chown -R $USER:$USER /var/www/f_web

log "⚙️ Tạo file config nginx cho domain..."
sudo tee /etc/nginx/conf.d/f_web.conf > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/f_web/current;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOL

log "🔍 Kiểm tra cấu hình Nginx..."
sudo nginx -t && sudo systemctl reload nginx

# Cài SSL với certbot (tùy chọn)
read -p "❓ Bạn có muốn cài HTTPS SSL (Let's Encrypt) cho $DOMAIN (y/n)? " yn
case $yn in
    [Yy]* ) 
        log "📦 Cài certbot..."
        sudo dnf install -y certbot python3-certbot-nginx
        log "🔑 Xin chứng chỉ SSL cho $DOMAIN ..."
        sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN
        ;;
    * ) log "⚠️ Bỏ qua cài SSL, website chạy HTTP";;
esac

log "✅ Setup hoàn tất! Truy cập http://$DOMAIN"



# CÁCH DÙNG:
# curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash


