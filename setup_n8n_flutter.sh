#!/bin/bash
set -e

echo "=== SETUP N8N VÀ FLUTTER WEB VỚI CADDY (KHÔNG XUNG ĐỘT) ==="

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "Script này phải được chạy với quyền root."
    exit 1
fi

# Nhập email cho SSL (tùy chọn)
ADMIN_EMAIL=""
read -rp "Nhập email admin cho SSL (để trống để dùng Let’s Encrypt tự động, hoặc giữ giá trị cũ nếu đã có): " ADMIN_EMAIL
if [[ -z "$ADMIN_EMAIL" ]]; then
    echo "Không cung cấp email, sử dụng Let’s Encrypt tự động."
fi

# Kiểm tra DNS
SERVER_IP=$(curl -s https://api.ipify.org)
for DOMAIN in n8n.way4.app eu.way4.app; do
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n 1)
    if [[ -z "$DOMAIN_IP" || "$SERVER_IP" != "$DOMAIN_IP" ]]; then
        echo "Domain $DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $DOMAIN_IP)."
        echo "Vui lòng cập nhật DNS và thử lại."
        exit 1
    fi
done

# Kiểm tra cổng 80/443
if ss -tuln | grep -q ':80\|:443'; then
    echo "Cổng 80 hoặc 443 đang được sử dụng. Dừng dịch vụ xung đột:"
    sudo lsof -i :80
    sudo lsof -i :443
    echo "Dừng bằng: sudo kill -9 <PID> hoặc sudo systemctl stop <dịch_vụ>"
    exit 1
fi

# Cập nhật hệ thống và xử lý xung đột gói (chạy an toàn ngay cả khi đã có)
echo "📦 Cập nhật hệ thống và xử lý xung đột gói (an toàn nếu đã có)..."
apt update
apt upgrade -y
apt autoremove -y
apt install -f

# Xóa containerd cũ nếu có để tránh xung đột
if dpkg -l | grep -q containerd; then
    echo "Xóa containerd cũ..."
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
else
    echo "Docker đã có, bỏ qua cài đặt."
fi

# Cài Caddy nếu chưa có
if ! command -v caddy >/dev/null 2>&1; then
    echo "🛡 Cài Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
else
    echo "Caddy đã có, bỏ qua cài đặt."
fi

# Setup n8n nếu chưa có
if [[ ! -d "/opt/n8n" || ! -f "/opt/n8n/docker-compose.yml" ]]; then
    echo "🚀 Setup n8n trên localhost:5678..."
    mkdir -p /opt/n8n
    cat > /opt/n8n/docker-compose.yml <<EOL
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
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
else
    echo "n8n đã setup, kiểm tra và khởi động lại nếu cần."
    docker-compose -f /opt/n8n/docker-compose.yml up -d
fi

# Tạo thư mục web nếu chưa có
if [[ ! -d "/opt/web/build" ]]; then
    echo "📂 Tạo thư mục web cho eu.way4.app..."
    mkdir -p /opt/web/build
    cat > /opt/web/build/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Web App</title></head>
<body><h1>Chào mừng đến eu.way4.app!</h1><p>Deploy web của bạn vào đây.</p></body>
</html>
EOF
fi
chown -R caddy:caddy /opt/web 2>/dev/null || true
chmod -R 755 /opt/web 2>/dev/null || true

# Sao lưu Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
    cp "$CADDYFILE" "${CADDYFILE}.bak_$(date +%s)"
fi

# Tạo hoặc cập nhật Caddyfile với cú pháp đúng
echo "Tạo hoặc cập nhật Caddyfile..."
cat > "$CADDYFILE" <<EOF
n8n.way4.app {
    reverse_proxy localhost:5678
    encode gzip
    $( [[ -n "$ADMIN_EMAIL" ]] && echo "tls $ADMIN_EMAIL" || echo "tls" )
}

eu.way4.app {
    root * /opt/web/build
    file_server
    encode gzip
    $( [[ -n "$ADMIN_EMAIL" ]] && echo "tls $ADMIN_EMAIL" || echo "tls" )
}
EOF

# Sửa quyền Caddyfile
chown caddy:caddy "$CADDYFILE"
chmod 644 "$CADDYFILE"
chown -R caddy:caddy /etc/caddy
chmod 755 /etc/caddy

# Xác thực Caddyfile
if ! caddy validate --config "$CADDYFILE"; then
    echo "❌ Cấu hình Caddy lỗi. Khôi phục bản sao lưu..."
    mv "${CADDYFILE}.bak_$(date +%s)" "$CADDYFILE" || true
    exit 1
fi

# Khởi động Caddy
echo "🚀 Khởi động Caddy..."
systemctl enable caddy --now
systemctl reload caddy || { echo "❌ Không thể reload Caddy. Kiểm tra log: journalctl -xeu caddy.service"; exit 1; }

# Hiển thị mật khẩu n8n
N8N_PASS=$(grep N8N_BASIC_AUTH_PASSWORD /opt/n8n/docker-compose.yml | cut -d'=' -f2- 2>/dev/null || echo "changeme")
echo "✅ Setup hoàn tất!"
echo "👉 N8N: https://n8n.way4.app"
echo "👤 Username: admin"
echo "🔑 Password: $N8