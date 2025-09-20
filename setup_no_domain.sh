#!/bin/bash
# setup.sh - Cài môi trường để chạy Flutter Web trên CentOS 8.3
# Cài Nginx + Certbot.
# Tạo thư mục /var/www/flutter_web.
# Cấu hình Nginx với rule cho SPA (try_files $uri /index.html).
# Restart dịch vụ.


set -e
log "🔄 Bắt đầu cài đặt môi trường VPS..."

# Cập nhật hệ thống
log "📦 Cập nhật hệ thống..."
sudo dnf update -y

# Cài Nginx
log "📦 Cài Nginx..."
sudo dnf install -y epel-release
sudo dnf install -y nginx

# Cài Node.js (nếu cần chạy tool hỗ trợ Flutter web)
log "📦 Cài Node.js (dùng cho Flutter web tool nếu cần)..."
sudo dnf module install -y nodejs:14

# Bật và khởi động nginx
log "🚀 Khởi động và bật Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

# Tạo thư mục chứa web
log "📂 Tạo thư mục f_web..."
sudo mkdir -p /var/www/f_web
sudo chown -R $USER:$USER /var/www/f_web

# Cấu hình Nginx
log "⚙️ Cấu hình Nginx..."
sudo tee /etc/nginx/conf.d/f_web.conf > /dev/null <<EOL
server {
    listen 80;
    server_name _;

    root /var/www/f_web;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOL

# Kiểm tra và reload nginx
log "🔍 Kiểm tra cấu hình Nginx..."
sudo nginx -t && sudo systemctl reload nginx


echo "✅ Setup hoàn tất. Web sẽ chạy từ thư mục /var/www/f_web"
log "✅ Setup hoàn tất! Web sẽ chạy từ /var/www/f_web/current"


# CÁCH DÙNG:
# curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash


