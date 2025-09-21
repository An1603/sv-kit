#!/bin/bash
set -euo pipefail

echo "=== SV-KIT N8N SETUP ==="

read -rp "Nhập domain cho n8n (vd: n8n.example.com): " N8N_DOMAIN

# Cài Docker & Docker Compose nếu chưa có
if ! command -v docker &>/dev/null; then
    echo "⚙️ Cài Docker..."
    apt-get update
    apt-get install -y docker.io docker-compose
    systemctl enable docker --now
fi

# Tạo thư mục
mkdir -p /opt/n8n
cd /opt/n8n

# File docker-compose
cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    volumes:
      - .n8n:/home/node/.n8n
EOF

docker compose up -d

# Cấu hình Nginx
NGINX_CONF="/etc/nginx/sites-available/${N8N_DOMAIN}.conf"

# Xóa config cũ nếu có
rm -f "$NGINX_CONF" /etc/nginx/sites-enabled/${N8N_DOMAIN}.conf

cat > "$NGINX_CONF" <<EOF
server {
    server_name ${N8N_DOMAIN};
    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/

# Fix nginx.conf nếu thiếu server_names_hash_bucket_size
if ! grep -q "server_names_hash_bucket_size" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    server_names_hash_bucket_size 128;' /etc/nginx/nginx.conf
fi

# Kiểm tra và restart nginx
if nginx -t; then
    systemctl restart nginx
else
    echo "❌ Cấu hình Nginx lỗi, rollback..."
    rm -f "$NGINX_CONF" /etc/nginx/sites-enabled/${N8N_DOMAIN}.conf
    systemctl reload nginx
    exit 1
fi

echo "✅ N8N setup xong!"
echo "👉 Truy cập: http://${N8N_DOMAIN}"
