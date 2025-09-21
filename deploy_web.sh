#!/bin/bash
set -e

# --- Config ---
SERVER_USER="root"
SERVER_IP="46.28.69.11"
SERVER_DIR="/root"
REPO_URL="https://raw.githubusercontent.com/An1603/sv-kit/main/update.sh"

# --- Build Flutter web ---
echo "🚀 Bắt đầu build Flutter Web..."
flutter build web

# --- Đóng gói ---
echo "📦 Đóng gói build/web thành f_web.tar.gz..."
tar -czf f_web.tar.gz -C build/web .

# --- Upload ---
echo "📤 Upload f_web.tar.gz lên server $SERVER_IP..."
scp f_web.tar.gz $SERVER_USER@$SERVER_IP:$SERVER_DIR/

# --- Gọi update.sh từ GitHub ---
echo "🔄 Triển khai trên server..."
ssh $SERVER_USER@$SERVER_IP "curl -s $REPO_URL | bash"

echo "✅ Deploy web thành công! Truy cập https://eurobank.eu.com/"
