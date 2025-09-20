
# setup.sh - Cài môi trường để chạy Flutter Web trên CentOS 8.3
# Cài Nginx + Certbot.
# Tạo thư mục /var/www/flutter_web.
# Cấu hình Nginx với rule cho SPA (try_files $uri /index.html).
# Restart dịch vụ.

#!/bin/bash
set -e
source <(curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/utils.sh)

log "🔄 Bắt đầu cài đặt môi trường VPS..."

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

log "⚙️ Cấu hình Nginx..."
sudo tee /etc/nginx/conf.d/f_web.conf > /dev/null <<EOL
server {
    listen 80;
    server_name _;

    root /var/www/f_web/current;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOL

log "🔍 Kiểm tra cấu hình Nginx..."
sudo nginx -t && sudo systemctl reload nginx

log "✅ Setup hoàn tất! Web sẽ chạy từ /var/www/f_web/current"


# CÁCH DÙNG:
# curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash


