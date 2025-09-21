#!/bin/bash
# deploy_tar.sh - upload Flutter web bằng tar.gz

set -e

LOCAL_BUILD_DIR="./build/web"
REMOTE_DIR="/var/www/f_web"
REMOTE_HOST="root@46.28.69.11"

if [ ! -d "$LOCAL_BUILD_DIR" ]; then
  echo "❌ Không tìm thấy thư mục build/web. Hãy chạy: flutter build web --release"
  exit 1
fi

echo "👉 Nén project..."
tar -czf web_build.tar.gz -C $LOCAL_BUILD_DIR .

echo "👉 Upload tar.gz..."
scp web_build.tar.gz $REMOTE_HOST:/tmp/

echo "👉 Giải nén trên VPS..."
ssh $REMOTE_HOST "rm -rf $REMOTE_DIR/* && mkdir -p $REMOTE_DIR && tar -xzf /tmp/web_build.tar.gz -C $REMOTE_DIR && rm /tmp/web_build.tar.gz && systemctl restart nginx"

echo "✅ Deploy thành công!"

# CẦN CÀI tar
# dnf install -y tar
# chmod +x deploy_tar.sh
# ./deploy_tar.sh
