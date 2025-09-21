#!/bin/bash
set -euo pipefail

echo "=== UPDATE FLUTTER WEB ON SERVER ==="

# Nhập domain Flutter Web (có thể cố định sẵn nếu muốn)
read -rp "Nhập domain Flutter Web (vd: app.example.com): " FLUTTER_DOMAIN

APP_DIR="/var/www/$FLUTTER_DOMAIN"
BACKUP_DIR="${APP_DIR}_backup_$(date +%Y%m%d%H%M%S)"

# Kiểm tra thư mục tồn tại
if [ ! -d "$APP_DIR" ]; then
  echo "❌ Thư mục $APP_DIR chưa tồn tại. Hãy chạy setup.sh trước."
  exit 1
fi

# Backup thư mục cũ
echo "📦 Backup thư mục cũ -> $BACKUP_DIR"
mv "$APP_DIR" "$BACKUP_DIR"

# Tạo thư mục mới
mkdir -p "$APP_DIR"

# Nhận file zip từ local (scp đã upload vào /tmp trước đó)
if [ -f "/tmp/flutter_build.zip" ]; then
  echo "📂 Giải nén Flutter build mới..."
  unzip -q -o /tmp/flutter_build.zip -d "$APP_DIR"
  rm -f /tmp/flutter_build.zip
else
  echo "❌ Không tìm thấy /tmp/flutter_build.zip"
  exit 1
fi

# Restart nginx
echo "🔄 Restart Nginx..."
nginx -t && systemctl restart nginx

echo "✅ Update thành công!"
echo "👉 Truy cập: http://$FLUTTER_DOMAIN"
