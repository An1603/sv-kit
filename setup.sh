#!/bin/bash
set -euo pipefail

echo "=== SV-KIT SETUP SCRIPT ==="

# Nhập domain
read -rp "Nhập domain cho N8N (vd: n8n.example.com): " N8N_DOMAIN
read -rp "Nhập domain cho Flutter Web (vd: app.example.com): " FLUTTER_DOMAIN

# Thư mục config
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Tạo config function
create_nginx_config() {
    local domain=$1
    local service=$2
    local port=$3

    local config_file="$NGINX_AVAILABLE/$domain.conf"

    # Nếu đã tồn tại thì backup
    if [ -f "$config_file" ]; then
        echo "🔄 Backup config cũ: $config_file -> $config_file.bak"
        mv "$config_file" "$config_file.bak"
    fi

    echo "📄 Tạo config cho $domain ($service:$port)"
    cat > "$config_file" <<EOF
server {
    server_name $domain;
    location / {
        proxy_pass http://localhost:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    ln -sf "$config_file" "$NGINX_ENABLED/$domain.conf"
}

# Xoá config cũ (rollback)
rollback() {
    echo "⚠️ Có lỗi xảy ra. Khôi phục config cũ..."
    for file in $NGINX_AVAILABLE/*.bak; do
        [ -f "$file" ] || continue
        orig="${file%.bak}"
        mv "$file" "$orig"
        ln -sf "$orig" "$NGINX_ENABLED/$(basename "$orig")"
    done
    systemctl reload nginx || true
}
trap rollback ERR

# Tạo config
create_nginx_config "$N8N_DOMAIN" "n8n" "5678"
create_nginx_config "$FLUTTER_DOMAIN" "flutter" "8080"

# Kiểm tra & reload
echo "🔍 Kiểm tra Nginx..."
nginx -t

echo "🔄 Restart Nginx..."
systemctl restart nginx

# SSL bằng certbot
echo "🔐 Cài SSL Let’s Encrypt..."
apt-get update -y && apt-get install -y certbot python3-certbot-nginx
certbot --nginx -d "$N8N_DOMAIN" -d "$FLUTTER_DOMAIN" --non-interactive --agree-tos -m admin@$N8N_DOMAIN

echo "✅ Setup hoàn tất!"
