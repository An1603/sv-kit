#!/bin/bash
set -e

echo "=== SV-KIT FLUTTER WEB SETUP ==="

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo "Script này phải được chạy với quyền root."
    exit 1
fi

# Nhập domain
read -rp "Nhập domain cho Flutter Web (vd: flutter.example.com): " FLUTTER_DOMAIN
if [[ -z "$FLUTTER_DOMAIN" ]]; then
    echo "Domain không được để trống!"
    exit 1
fi

# Nhập email cho SSL (tùy chọn)
read -rp "Nhập email admin cho SSL (để trống để dùng Let’s Encrypt tự động): " ADMIN_EMAIL
if [[ -z "$ADMIN_EMAIL" ]]; then
    echo "Không cung cấp email, sử dụng Let’s Encrypt tự động."
else
    echo "Sử dụng email: $ADMIN_EMAIL"
fi

# Kiểm tra domain trỏ về server
SERVER_IP=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short "$FLUTTER_DOMAIN" | tail -n 1)
if [[ -z "$DOMAIN_IP" || "$SERVER_IP" != "$DOMAIN_IP" ]]; then
    echo "Domain $FLUTTER_DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $DOMAIN_IP)."
    echo "Vui lòng cập nhật DNS và thử lại."
    exit 1
fi

# Kiểm tra cổng 80 và 443
if ss -tuln | grep -q ':80\|:443'; then
    echo "Cổng 80 hoặc 443 đang được sử dụng. Vui lòng dừng các dịch vụ xung đột (như Apache, Nginx)."
    echo "Kiểm tra: sudo ss -tuln | grep ':80\|:443'"
    exit 1
fi

# Cài đặt các gói cần thiết
echo "📦 Cập nhật và cài đặt các gói cần thiết..."
apt update -y && apt upgrade -y
apt install -y curl

# Cài đặt Caddy nếu chưa có
if ! command -v caddy >/dev/null 2>&1; then
    echo "🛡 Cài đặt Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
fi

# Tạo thư mục cho Flutter Web và file index.html mẫu
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
    <p>Đây là trang placeholder. Vui lòng deploy dự án Flutter Web của bạn vào /opt/flutter_web/build/web.</p>
</body>
</html>
EOF

# Sửa quyền thư mục Flutter Web
chown -R caddy:caddy /opt/flutter_web
chmod -R 755 /opt/flutter_web

# Sao lưu Caddyfile hiện tại
CADDYFILE="/etc/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
    cp "$CADDYFILE" "${CADDYFILE}.bak_$(date +%s)"
fi

# Tạo Caddyfile mới cho Flutter Web
echo "Tạo Caddyfile mới..."
cat > "$CADDYFILE" <<EOF
$FLUTTER_DOMAIN {
    root * /opt/flutter_web/build/web
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

echo "✅ Cài đặt hoàn tất!"
echo "👉 Flutter Web: https://$FLUTTER_DOMAIN"
echo "📜 Kiểm tra log Caddy: journalctl -xeu caddy.service"
echo "⚠️ Để deploy dự án Flutter Web, sao chép build web vào /opt/flutter_web/build/web"