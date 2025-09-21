#!/bin/bash
set -e

# ===============================
# Domain cho Flutter web
# ===============================
if [ -z "$WEB_DOMAIN" ]; then
  read -p "👉 Nhập domain cho Flutter web (ví dụ: eurobank.eu.com): " WEB_DOMAIN
fi

if [ -z "$WEB_DOMAIN" ]; then
  echo "❌ Bạn chưa nhập domain Flutter web!"
  exit 1
fi

echo "✅ Domain Flutter web: $WEB_DOMAIN"

# ===============================
# Build Flutter web
# ===============================
LOCAL_BUILD_DIR="./build/web"
TAR_FILE="f_web.tar.gz"
REMOTE_DIR="/var/www/$WEB_DOMAIN"
REMOTE_HOST="root@46.28.69.11"

if [ ! -d "$LOCAL_BUILD_DIR" ]; then
  echo "❌ Không tìm thấy thư mục build/web. Hãy chạy: flutter build web --release"
  exit 1
fi

echo "📦 Đóng gói build/web..."
tar -czf $TAR_FILE -C $LOCAL_BUILD_DIR .

# ===============================
# Upload & giải nén trên VPS
# ===============================
echo "📤 Upload lên VPS..."
scp $TAR_FILE $REMOTE_HOST:/tmp/

echo "📂 Giải nén và deploy..."
ssh $REMOTE_HOST bash <<EOF
  set -e
  mkdir -p $REMOTE_DIR
  rm -rf $REMOTE_DIR/*
  tar -xzf /tmp/$TAR_FILE -C $REMOTE_DIR
  rm /tmp/$TAR_FILE
  chown -R www-data:www-data $REMOTE_DIR
EOF

rm $TAR_FILE

# ===============================
# Config Nginx cho Flutter web
# ===============================
echo "📝 Kiểm tra cấu hình Nginx..."
ssh $REMOTE_HOST bash <<EOF
  set -e
  NGINX_CONF="/etc/nginx/sites-available/$WEB_DOMAIN.conf"

  cat > \$NGINX_CONF <<NGINX
server {
    server_name $WEB_DOMAIN;

    root $REMOTE_DIR;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
NGINX

  ln -sf \$NGINX_CONF /etc/nginx/sites-enabled/$WEB_DOMAIN.conf
  nginx -t && systemctl reload nginx
EOF

echo "✅ Deploy thành công! Truy cập: https://$WEB_DOMAIN"
