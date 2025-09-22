#!/bin/bash

# Script tự động build Flutter Web và deploy lên server cho domain eu.way4.app
# Chạy từ thư mục root dự án Flutter (nơi có pubspec.yaml)
# Yêu cầu: SSH key đã setup cho root@46.28.69.11

set -e  # Dừng nếu có lỗi

SERVER_IP="46.28.69.11"
SERVER_USER="root"
SERVER_PATH="/opt/web/build"
DOMAIN="eu.way4.app"

echo "=== DEPLOY FLUTTER WEB TO SERVER ($DOMAIN) ==="

# Kiểm tra Flutter có sẵn
if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Flutter không được cài đặt. Hãy cài Flutter SDK và thêm vào PATH."
    exit 1
fi

echo "🦋 Kiểm tra Flutter..."
flutter --version

# Kiểm tra dự án Flutter (phải có pubspec.yaml)
if [[ ! -f "pubspec.yaml" ]]; then
    echo "❌ Không tìm thấy pubspec.yaml. Hãy chạy script từ thư mục root dự án Flutter."
    exit 1
fi

# Build Flutter Web
echo "🔨 Build Flutter Web (release mode)..."
flutter pub get  # Cập nhật dependencies nếu cần
flutter build web --release

# Kiểm tra build thành công
if [[ ! -d "build/web" ]]; then
    echo "❌ Build thất bại. Kiểm tra lỗi Flutter."
    exit 1
fi

echo "📤 Upload build/web lên server $SERVER_USER@$SERVER_IP:$SERVER_PATH..."

# Upload thư mục build/web (xóa nội dung cũ và copy mới)
ssh $SERVER_USER@$SERVER_IP "rm -rf $SERVER_PATH/* && mkdir -p $SERVER_PATH"
scp -r build/web/* $SERVER_USER@$SERVER_IP:$SERVER_PATH/

# SSH để sửa quyền và reload Caddy
echo "🔑 Sửa quyền và reload Caddy trên server..."
ssh $SERVER_USER@$SERVER_IP "
    chown -R caddy:caddy $SERVER_PATH
    systemctl reload caddy
"

echo "✅ Deploy hoàn tất!"
echo "👉 Web mới đã sẵn sàng tại: https://$DOMAIN"
echo "📜 Kiểm tra log Caddy trên server: ssh root@$SERVER_IP 'journalctl -xeu caddy.service'"
echo "⚠️ Nếu cần cập nhật, chạy script lại từ dự án Flutter."