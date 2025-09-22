#!/bin/bash
set -e

echo "=== SETUP N8N VÀ WEB VỚI CADDY (KHÔNG XUNG ĐỘT) ==="

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "Script này phải được chạy với quyền root."
    exit 1
fi

# Nhập email cho SSL (tùy chọn)
read -rp "Nhập email admin cho SSL (để trống để dùng Let’s Encrypt tự động): " ADMIN_EMAIL
if [[ -z "$ADMIN_EMAIL" ]]; then
    echo "Không cung cấp email, sử dụng Let’s Encrypt tự động."
else
    echo "Sử dụng email: $ADMIN_EMAIL"
fi

# Kiểm tra cổng 80/443 (phải trống để Caddy dùng)
if ss -tuln | grep -q ':80\|:443'; then
    echo "Cổng 80 hoặc 443 đang được sử dụng. Dừng dịch vụ xung đột:"
    sudo lsof -i :80
    sudo lsof -i :443
    echo "Dừng bằng: sudo kill -9 <PID> hoặc sudo systemctl stop <dịch_vụ>"
    exit 1
fi

# Cập nhật hệ thống và xử lý xung đột gói
echo "📦 Cập nhật hệ thống và xử lý xung đột gói..."
apt update
apt upgrade -y
apt autoremove -y
apt install -f

# Xóa containerd cũ để tránh xung đột với containerd.io
if dpkg -l | grep -q containerd; then
    echo "Xóa containerd cũ để tránh xung đột..."
    apt remove -y containerd
    apt autoremove -y
fi

# Bỏ giữ gói nếu có
if dpkg --get-selections | grep -q hold; then
    echo "Bỏ giữ các gói bị hold..."
    dpkg --get-selections | grep hold | awk '{print $1}' | xargs -r apt-mark unhold
fi

# Cài Docker nếu chưa có
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Cài Docker..."
    apt install -y docker.io docker-compose
    systemctl enable docker --now
fi

# Cài Caddy nếu chưa có
if ! command -v caddy >/dev/null 2>&1; then
    echo "🛡 Cài Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
fi

# Setup n8n với Docker Compose (cổng nội bộ 5678)
echo "🚀 Setup n8n trên localhost:5678..."
mkdir -p /opt/n8n
cat > /opt/n8n/docker-compose.yml <<EOL
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"  # Nội bộ, không bind 80/443
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 12)
      - N8N_HOST=n8n.way4.app
      - N8N_PROTOCOL=https
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOL

docker-compose -f /opt/n8n/docker-compose.yml up -d

# Tạo thư mục web (cho eu.way4.app, placeholder)
echo "📂 Tạo thư mục web cho eu.way4.app..."
mkdir -p /opt/web/build
cat > /opt/web/build/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Web App</title></head>
<body><h1>Chào mừng đến eu.way4.app!</h1><p>Deploy web của bạn vào đây.</p></body>
</html>
EOF
chown -R caddy:caddy /opt/web
chmod -R 755 /opt/web

# Sao lưu Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
    cp "$CADDYFILE" "${CADDYFILE}.bak_$(date +%s)"
fi

# Tạo Caddyfile cho nhiều subdomain
echo "Tạo Caddyfile..."
cat > "$CADDYFILE" <<EOF
# Base domain
way4.app {
    # n8n trên subdomain
    n8n.way4.app {
        reverse_proxy localhost:5678
        encode gzip
        $( [[ -n "$ADMIN_EMAIL" ]] && echo "tls $ADMIN_EMAIL" || echo "tls" )
    }

    # Web tĩnh trên subdomain
    eu.way4.app {
        root * /opt/web/build
        file_server
        encode gzip
        $( [[ -n "$ADMIN_EMAIL" ]] && echo "tls $ADMIN_EMAIL" || echo "tls" )
    }
}
EOF

# Sửa quyền Caddyfile
chown caddy:caddy "$CADDYFILE"
chmod 644 "$CADDYFILE"
chown -R caddy:caddy /etc/caddy
chmod 755 /etc/caddy

# Xác thực và chạy Caddy
if ! caddy validate --config "$CADDYFILE"; then
    echo "❌ Cấu hình Caddy lỗi. Khôi phục backup..."
    mv "${CADDYFILE}.bak_*" "$CADDYFILE" 2>/dev/null || true
    exit 1
fi

systemctl enable caddy --now
systemctl reload caddy || { echo "❌ Lỗi Caddy. Kiểm tra: journalctl -xeu caddy.service"; exit 1; }

# Hiển thị mật khẩu n8n
N8N_PASS=$(grep N8N_BASIC_AUTH_PASSWORD /opt/n8n/docker-compose.yml | cut -d'=' -f2-)
echo "✅ Hoàn tất!"
echo "👉 n8n: https://n8n.way4.app (User: admin, Pass: $N8N_PASS)"
echo "👉 Web: https://eu.way4.app"
echo "📜 Log Caddy: journalctl -xeu caddy.service"
echo "⚠️ Deploy web: cp -r build/web/* /opt/web/build/ && chown -R caddy:caddy /opt/web && systemctl reload caddy"