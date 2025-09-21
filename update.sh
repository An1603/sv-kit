#!/bin/bash
set -e

WEB_DIR="/var/www/eurobank"
NGINX_CONF="/etc/nginx/sites-available/eurobank"

echo "🔄 Bắt đầu update Flutter Web..."

# Kiểm tra file f_web.tar.gz có tồn tại không
if [ ! -f "f_web.tar.gz" ]; then
  echo "❌ Không tìm thấy file f_web.tar.gz trong thư mục hiện tại!"
  exit 1
fi

# Tạo thư mục web nếu chưa có
if [ ! -d "$WEB_DIR" ]; then
  echo "📂 Tạo thư mục $WEB_DIR..."
  sudo mkdir -p $WEB_DIR
fi

# Giải nén web vào thư mục
echo "📦 Giải nén f_web.tar.gz vào $WEB_DIR..."
sudo tar -xzf f_web.tar.gz -C $WEB_DIR --strip-components=1

# Đặt quyền cho thư mục web
echo "🔑 Đặt quyền cho $WEB_DIR..."
sudo chown -R www-data:www-data $WEB_DIR
sudo chmod -R 755 $WEB_DIR

# Kiểm tra config nginx (phòng khi lỗi config)
echo "📝 Kiểm tra cấu hình Nginx..."
sudo nginx -t

# Reload Nginx
echo "🔄 Reload Nginx..."
sudo systemctl reload nginx

echo "✅ Update Flutter Web hoàn tất!"
