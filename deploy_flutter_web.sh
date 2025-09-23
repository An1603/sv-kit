#!/bin/bash

# deploy_flutter_web.sh - Build và deploy Flutter Web lên server (nén/giải nén)
# Chạy trên Mac, từ thư mục root dự án Flutter
# Yêu cầu: Flutter, SSH key cho root@46.28.69.11

set -e

echo "=== DEPLOY FLUTTER WEB TO SERVER (NÉN/GIẢI NÉN) ==="

# Cấu hình server
SERVER_IP="46.28.69.11"
SERVER_USER="root"
SERVER_PATH="/home/web/build"
DOMAIN="eu.way4.app"
TEMP_TAR="/tmp/flutter_web_build.tar.gz"

# Kiểm tra Flutter
if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Flutter không được cài đặt. Hãy cài Flutter SDK và thêm vào PATH."
    exit 1
fi

echo "🦋 Kiểm tra Flutter..."
flutter --version

# Kiểm tra dự án Flutter
if [[ ! -f "pubspec.yaml" ]]; then
    echo "❌ Không tìm thấy pubspec.yaml. Hãy chạy script từ thư mục root dự án Flutter."
    exit 1
fi

# Build Flutter Web
echo "🔨 Build Flutter Web (release mode)..."
flutter clean
flutter pub get
flutter build web --release

# Kiểm tra build
if [[ ! -d "build/web" ]]; then
    echo "❌ Build thất bại. Kiểm tra lỗi Flutter."
    exit 1
fi

# Nén thư mục build/web
echo "📦 Nén build/web thành $TEMP_TAR..."
rm -f "$TEMP_TAR"  # Xóa file nén cũ nếu có
tar -czf "$TEMP_TAR" -C build/web .

# Upload file nén
echo "📤 Upload $TEMP_TAR lên $SERVER_USER@$SERVER_IP:/tmp..."
scp "$TEMP_TAR" "$SERVER_USER@$SERVER_IP:/tmp/"

# SSH để giải nén, sửa quyền, và reload Caddy
echo "🔧 Giải nén và reload Caddy trên server..."
ssh "$SERVER_USER@$SERVER_IP" "
    rm -rf $SERVER_PATH/* &&
    mkdir -p $SERVER_PATH &&
    tar -xzf /tmp/flutter_web_build.tar.gz -C $SERVER_PATH/ &&
    rm /tmp/flutter_web_build.tar.gz &&
    chown -R caddy:caddy $SERVER_PATH &&
    chmod -R 755 $SERVER_PATH &&
    systemctl reload caddy
"

if [[ $? -ne 0 ]]; then
    echo "⚠️ Lỗi xử lý trên server (kiểm tra SSH hoặc log Caddy: journalctl -xeu caddy.service)"
    exit 1
fi

# Xóa file nén tạm trên local
rm -f "$TEMP_TAR"

echo "✅ Deploy hoàn tất!"
echo "👉 Web sẵn sàng tại: https://$DOMAIN"
echo "📜 Kiểm tra log Caddy trên server: ssh root@$SERVER_IP 'journalctl -xeu caddy.service'"
echo "⚠️ Nếu lỗi SSH, thiết lập key: ssh-keygen && ssh-copy-id root@$SERVER_IP"