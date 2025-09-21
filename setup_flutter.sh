#!/bin/bash
set -euo pipefail

echo "=== SV-KIT FLUTTER SETUP ==="

read -rp "Nhập domain cho Flutter Web (vd: app.example.com): " FLUTTER_DOMAIN

WEB_DIR="/var/www/${FLUTTER_DOMAIN}"
NGINX_CONF="/etc/nginx/sites-available/${FLUTTER_DOMAIN}.conf"

# Xóa config cũ
rm -f "$NGINX_CONF" /etc/nginx/sites-enabled/${FLUTTER_DOMAIN}.conf

# Tạo thư mục web
mkdir -p "$WEB_DIR"

# Nếu có file f_web.tar.gz thì giải nén
if [ -f f_web.tar.gz ]; then
    tar -xzf f_web.tar.gz -C "$WEB_DIR" --strip-components=1
fi

# Nginx config
cat > "$NGINX_CONF" <<EOF
server {
    server_name ${FLUTTER_DOMAIN};
    root ${WEB_DIR};
    index index.html;
    location / {
        try_files \$uri /index.html;
    }
}
EOF

ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/

# Fix nginx.conf nếu thiếu
if ! grep -q "server_names_hash_bucket_size" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    server_names_hash_bucket_size 128;' /etc/nginx/nginx.conf
fi

# Kiểm tra và restart
if nginx -t; then
    systemctl restart nginx
else
    echo "❌ Cấu hình Nginx lỗi, rollback..."
    rm -f "$NGINX_CONF" /etc/nginx/sites-enabled/${FLUTTER_DOMAIN}.conf
    systemctl reload nginx
    exit 1
fi

echo "✅ Flutter web setup xong!"
echo "👉 Truy cập: http://${FLUTTER_DOMAIN}"
