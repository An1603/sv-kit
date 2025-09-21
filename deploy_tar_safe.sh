#!/bin/bash
# deploy_tar_safe.sh - Safe deploy Flutter web trên CentOS Stream 9

set -euo pipefail

LOCAL_BUILD_DIR="./build/web"
REMOTE_DIR="/var/www/f_web"
REMOTE_HOST="root@46.28.69.11"
TAR_NAME="f_web.tar.gz"

if [ ! -d "$LOCAL_BUILD_DIR" ]; then
  echo "❌ Không tìm thấy thư mục build/web. Hãy chạy: flutter build web --release"
  exit 1
fi

# Nén project local
echo "👉 Nén project..."
tar -czf $TAR_NAME -C $LOCAL_BUILD_DIR .

# Upload tar.gz
echo "👉 Upload tar.gz..."
scp $TAR_NAME $REMOTE_HOST:/tmp/

# Deploy trên VPS
ssh $REMOTE_HOST bash -s << 'ENDSSH'
set -euo pipefail

REMOTE_DIR="/var/www/f_web"
TAR_FILE="/tmp/f_web.tar.gz"
BACKUP_DIR="/tmp/f_web_backup_$(date +%s)"

echo "🔹 Kiểm tra nginx..."
if ! command -v nginx &>/dev/null; then
  echo "Nginx không tồn tại, cài đặt bằng dnf..."
  dnf install -y nginx
  systemctl enable nginx --now
fi

echo "🔹 Kiểm tra firewalld và mở port 80 nếu cần..."
if command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-service=http || true
  firewall-cmd --reload || true
fi

echo "🔹 Backup build cũ..."
if [ -d "$REMOTE_DIR" ]; then
  mkdir -p $BACKUP_DIR
  cp -r $REMOTE_DIR/* $BACKUP_DIR/
fi

echo "🔹 Backup config nginx mặc định..."
if [ -f /etc/nginx/conf.d/default.conf ]; then
  cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak.$(date +%s)
fi

echo "🔹 Tạo config nginx cho Flutter web..."
cat > /etc/nginx/conf.d/f_web.conf <<'NGINXCONF'
server {
    listen 80;
    server_name _;

    root /var/www/f_web;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    error_page 500 502 503 504 /index.html;
}
NGINXCONF

echo "🔹 Chuẩn bị thư mục web..."
mkdir -p $REMOTE_DIR
# Chỉ xóa file, giữ .well-known
find "$REMOTE_DIR" -mindepth 1 -maxdepth 1 ! -name '.well-known' -exec rm -rf {} +

echo "🔹 Giải nén build mới..."
tar -xzf $TAR_FILE -C $REMOTE_DIR
rm -f $TAR_FILE

echo "🔹 Set quyền..."
if id nginx &>/dev/null; then
  chown -R nginx:nginx $REMOTE_DIR
fi
chmod -R 755 $REMOTE_DIR

echo "🔹 Restart nginx..."
systemctl restart nginx || systemctl start nginx
systemctl enable nginx --now

echo "✅ Deploy an toàn hoàn tất!"
ENDSSH

echo "✅ Deploy hoàn tất! Truy cập: http://46.28.69.11"
