
# deploy.sh - Deploy F Web bằng cách nén + upload + giải nén trên VPS
# Build F Web (flutter build web --release).
# Tạo file .tar.gz.
# Upload sang VPS (scp).
# Giải nén → thay thế nội dung web root → restart Nginx.
# Giữ lại bản cũ trong /var/www/releases/.

#!/bin/bash
set -e

LOCAL_BUILD_DIR="./build/web"
ARCHIVE_NAME="f_web_$(date +%Y%m%d%H%M%S).tar.gz"
REMOTE_DIR="/var/www/f_web"
REMOTE_HOST="root@46.28.69.11"

# 1. Kiểm tra thư mục build/web
if [ ! -d "$LOCAL_BUILD_DIR" ]; then
  echo "❌ Không tìm thấy thư mục build/web. Hãy chạy: flutter build web --release"
  exit 1
fi

echo "👉 Tạo gói nén..."
tar -czf $ARCHIVE_NAME -C $LOCAL_BUILD_DIR .

echo "👉 Upload gói nén lên server..."
scp $ARCHIVE_NAME $REMOTE_HOST:/tmp/

echo "👉 Giải nén gói trên server..."
ssh $REMOTE_HOST << EOF
  mkdir -p $REMOTE_DIR
  tar -xzf /tmp/$ARCHIVE_NAME -C $REMOTE_DIR
  rm -f /tmp/$ARCHIVE_NAME
  chown -R nginx:nginx $REMOTE_DIR
  systemctl restart nginx
EOF

echo "👉 Xóa gói nén local..."
rm -f $ARCHIVE_NAME

echo "✅ Deploy thành công!"



# Cách dùng: Trên máy local build web:
# flutter build web --release

# Deploy bằng 1 lệnh:
# Đặt file này ngay trong thư mục dự án Flutter (cùng cấp với pubspec.yaml).
# ./deploy.sh

# FILE deploy.sh trên GITHUB
# curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/deploy.sh | bash
