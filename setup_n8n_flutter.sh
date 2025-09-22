#!/bin/bash
set -e

echo "=== SV-KIT N8N & FLUTTER WEB SETUP ==="

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "Script này phải được chạy với quyền root."
    exit 1
fi

# Định nghĩa domain
N8N_DOMAIN="n8n.way4.app"
FLUTTER_DOMAIN="eu.way4.app"

# Nhập email cho SSL (tùy chọn)
read -rp "Nhập email admin cho SSL (để trống để dùng Let’s Encrypt tự động): " ADMIN_EMAIL
if [[ -z "$ADMIN_EMAIL" ]]; then
    echo "Không cung cấp email, sử dụng Let’s Encrypt tự động."
else
    echo "Sử dụng email: $ADMIN_EMAIL"
fi

# Kiểm tra domain trỏ về server
SERVER_IP=$(curl -s https://api.ipify.org)
N8N_DOMAIN_IP=$(dig +short "$N8N_DOMAIN" | tail -n 1)
FLUTTER_DOMAIN_IP=$(dig +short "$FLUTTER_DOMAIN" | tail -n 1)
if [[ -z "$N8N_DOMAIN_IP" || "$SERVER_IP" != "$N8N_DOMAIN_IP" ]]; then
    echo "Domain $N8N_DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $N8N_DOMAIN_IP)."
    echo "Vui lòng cập nhật DNS và thử lại."
    exit 1
fi
if [[ -z "$FLUTTER_DOMAIN_IP" || "$SERVER_IP" != "$FLUTTER_DOMAIN_IP" ]]; then
    echo "Domain $FLUTTER_DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $FLUTTER_DOMAIN_IP)."
    echo "Vui lòng cập nhật DNS và thử lại."
    exit 1
fi

# Kiểm tra cổng 80 và 443
if ss -tuln | grep -q ':80\|:443'; then
    echo "Cổng 80 hoặc 443 đang được sử dụng. Đang kiểm tra tiến trình..."
    lsof -i :80 -i :443
    echo "Vui lòng dừng các dịch vụ xung đột (như Apache, Nginx, hoặc Docker container)."
    echo "Gợi ý: Dùng 'docker ps' để tìm container chiếm cổng, sau đó 'docker stop <container_id>'."
    exit 1
fi

# Cài đặt các gói cần thiết
echo "📦 Cập nhật và cài đặt các gói cần thiết..."
apt update -y && apt upgrade -y
apt install -y curl docker.io docker-compose net-tools

# Khởi động Docker
systemctl enable docker --now

# Cài đặt Caddy nếu chưa có
if ! command -v caddy >/dev/null 2>&1; then
    echo "🛡 Cài đặt Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
fi

# Tạo thư mục và file index.html mẫu cho Flutter Web
echo "📂 Tạo thư mục và file index.html mẫu cho Flutter Web..."
mkdir -p /opt/flutter_web/build/web
cat > /opt/flutter_web/build/web/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Flutter Web Placeholder</title>
</head>
<body>
    <h1>Chào mừng đến với Flutter Web!</h1>
    <p>Đây là trang placeholder cho $FLUTTER_DOMAIN. Vui lòng deploy dự án Flutter Web vào /opt/flutter_web/build/web.</p>
</body>
</html>
EOF

# Sửa quyền thư mục Flutter Web
chown -R caddy:caddy /opt/flutter_web
chmod -R 755 /opt/flutter_web

# C