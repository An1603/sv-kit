
# deploy.sh - Deploy F Web bằng cách nén + upload + giải nén trên VPS
# Build F Web (flutter build web --release).
# Tạo file .tar.gz.
# Upload sang VPS (scp).
# Giải nén → thay thế nội dung web root → restart Nginx.
# Giữ lại bản cũ trong /var/www/releases/.

#!/bin/bash
set -e

# Import utils
source "$(dirname "$0")/utils.sh"

# Kiểm tra tham số DOMAIN
DOMAIN=$1
if [ -z "$DOMAIN" ]; then
  echo "❌ Bạn phải nhập DOMAIN khi deploy"
  echo "👉 Ví dụ: ./deploy.sh example.com"
  exit 1
fi

# Thư mục dự án local
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"
ARCHIVE="build.tar.gz"

# Thư mục đích trên VPS
REMOTE_USER="root"
REMOTE_HOST="46.28.69.11"
REMOTE_DIR="/var/www/$DOMAIN"
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_LINK_DIR="/etc/nginx/sites-enabled"

note "🚀 Bắt đầu build Flutter web..."
flutter build web

note "📦 Nén build..."
tar -czf $ARCHIVE -C $BUILD_DIR .

note "📤 Upload lên VPS..."
scp $ARCHIVE $REMOTE_USER@$REMOTE_HOST:/tmp/

note "📂 Giải nén trên VPS..."
ssh $REMOTE_USER@$REMOTE_HOST <<EOF
  mkdir -p $REMOTE_DIR
  tar -xzf /tmp/$ARCHIVE -C $REMOTE_DIR
  rm -f /tmp/$ARCHIVE
EOF

note "⚙️ Kiểm tra cấu hình Nginx cho domain: $DOMAIN"
ssh $REMOTE_USER@$REMOTE_HOST <<EOF
  if [ ! -f $NGINX_CONF_DIR/$DOMAIN ]; then
    cat > $NGINX_CONF_DIR/$DOMAIN <<CONF
server {
    listen 80;
    server_name $DOMAIN;

    root $REMOTE_DIR;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
CONF
    ln -s $NGINX_CONF_DIR/$DOMAIN $NGINX_LINK_DIR/
  fi

  nginx -t && systemctl reload nginx
EOF

note "✅ Deploy thành công cho domain: $DOMAIN"



# Cách dùng: Trên máy local build web:
# flutter build web --release

# Deploy bằng 1 lệnh:
# Đặt file này ngay trong thư mục dự án Flutter (cùng cấp với pubspec.yaml).
# ./deploy.sh

# FILE deploy.sh trên GITHUB
# curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/deploy.sh | bash
