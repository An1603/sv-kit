#!/bin/bash
set -e

echo "=== UPDATE FLUTTER WEB ==="

# Kiểm tra root
if [[ $EUID -ne 0 ]]; then
    echo "Phải chạy với quyền root!"
    exit 1
fi

# Nhập domain
read -rp "Nhập domain Flutter Web (vd: app.example.com): " FLUTTER_DOMAIN
if [[ -z "$FLUTTER_DOMAIN" ]]; then
    echo "Bạn chưa nhập domain!"
    exit 1
fi

# Kiểm tra file nén
if [[ ! -f "./f_web.tar.gz" ]]; then
    echo "❌ f_web.tar.gz không tồn tại!"
    exit 1
fi

WEB_DIR="/var/www/$FLUTTER_DOMAIN"

# Backup cũ nếu tồn tại
if [[ -d "$WEB_DIR" ]]; then
    mv "$WEB_DIR" "${WEB_DIR}_backup_$(date +%s)"
fi

mkdir -p "$WEB_DIR"

# Giải nén
tar -xzf f_web.tar.gz -C "$WEB_DIR" --strip-components=1

# Set quyền
chown -R www-data:www-data "$WEB_DIR"

# Cập nhật Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
if ! grep -q "$FLUTTER_DOMAIN" "$CADDYFILE"; then
    echo "$FLUTTER_DOMAIN {" >> "$CADDYFILE"
    echo "    root * $WEB_DIR" >> "$CADDYFILE"
    echo "    file_server" >> "$CADDYFILE"
    echo "    encode gzip" >> "$CADDYFILE"
    echo "    tls admin@$FLUTTER_DOMAIN" >> "$CADDYFILE"
    echo "}" >> "$CADDYFILE"
fi

# Reload Caddy
caddy validate --config "$CADDYFILE"
systemctl reload caddy

echo "✅ Flutter Web đã được deploy!"
echo "👉 URL: https://$FLUTTER_DOMAIN"
