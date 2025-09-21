#!/bin/bash
set -euo pipefail

echo "=== SV-KIT N8N SETUP (SAFE MODE) ==="

# === Nhập domain ===
if [ -z "${N8N_DOMAIN:-}" ]; then
    read -rp "Nhập domain cho N8N (vd: n8n.example.com): " N8N_DOMAIN
fi

NGINX_CONF="/etc/nginx/nginx.conf"
SITE_CONF="/etc/nginx/sites-enabled/$N8N_DOMAIN.conf"

# === Cài Docker + Docker Compose nếu chưa có ===
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Cài đặt Docker..."
    apt-get update
    apt-get install -y docker.io docker-compose
fi

# === Chạy N8N bằng Docker ===
echo "🚀 Chạy n8n với Docker..."
mkdir -p /opt/n8n
cat > /opt/n8n/docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - /opt/n8n:/home/node/.n8n
EOF

docker compose -f /opt/n8n/docker-compose.yml up -d

# === Backup Nginx config trước khi sửa ===
echo "📦 Backup Nginx config..."
cp "$NGINX_CONF" "$NGINX_CONF.bak.$(date +%s)"

# === Patch nginx.conf để thêm server_names_hash_bucket_size nếu chưa có ===
if ! grep -q "server_names_hash_bucket_size" "$NGINX_CONF"; then
    echo "⚙️  Thêm server_names_hash_bucket_size vào nginx.conf..."
    sed -i '/http {/a \    server_names_hash_bucket_size 128;' "$NGINX_CONF"
fi

# === Xoá config cũ nếu tồn tại ===
if [ -f "$SITE_CONF" ]; then
    echo "🧹 Xoá config cũ của $N8N_DOMAIN..."
    rm -f "$SITE_CONF"
fi

# === Tạo site config mới ===
cat > "$SITE_CONF" <<EOF
server {
    server_name $N8N_DOMAIN;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# === Kiểm tra config ===
echo "📝 Kiểm tra cấu hình Nginx..."
if nginx -t; then
    echo "🔄 Restart Nginx..."
    systemctl restart nginx || systemctl start nginx
    echo "✅ Setup hoàn tất!"
    echo "👉 N8N: http://$N8N_DOMAIN"
else
    echo "❌ Cấu hình Nginx lỗi, rollback..."
    mv "$NGINX_CONF.bak."* "$NGINX_CONF" 2>/dev/null || true
    rm -f "$SITE_CONF"
    nginx -t && systemctl restart nginx || echo "⚠️ Rollback xong nhưng Nginx vẫn lỗi, cần kiểm tra thủ công."
    exit 1
fi
