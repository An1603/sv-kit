#!/bin/bash
set -euo pipefail

echo "=== LOCAL DEPLOY SCRIPT (Flutter Web) ==="

# --- Config ---
SERVER_USER="root"
SERVER_IP="46.28.69.11"     # thay bằng IP server của bạn
SERVER_PATH="/root"         # nơi upload f_web.tar.gz
UPDATE_SCRIPT_URL="https://raw.githubusercontent.com/An1603/sv-kit/main/update.sh"

# --- Hỏi domain nếu chưa có ---
if [ -z "${FLUTTER_DOMAIN:-}" ]; then
  read -rp "Nhập domain Flutter Web (vd: eurobank.eu.com): " FLUTTER_DOMAIN
fi
echo "📌 Flutter domain: $FLUTTER_DOMAIN"

# --- Build web ---
echo "🏗️ Build Flutter web..."
flutter build web

# --- Đóng gói ---
echo "📦 Tạo gói f_web.tar.gz..."
tar -czf f_web.tar.gz -C build/web .

# --- Upload ---
echo "🚀 Upload f_web.tar.gz lên server $SERVER_IP ..."
scp f_web.tar.gz ${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/

# --- Gọi update.sh trên server ---
echo "🔄 Triển khai trên server..."
ssh ${SERVER_USER}@${SERVER_IP} "FLUTTER_DOMAIN=$FLUTTER_DOMAIN curl -s $UPDATE_SCRIPT_URL | bash"

echo "✅ Deploy thành công! Mở https://$FLUTTER_DOMAIN để kiểm tra."


# Cách dùng:
# Chỉnh SERVER_IP và SERVER_USER trong script.
# Chạy từ local:
# bash deploy_local.sh

# Nó sẽ tự động build → nén → upload → update web trên server.
# Bạn có muốn mình gom setup.sh, update.sh, deploy_local.sh vào repo sv-kit để bạn clone 1 lần là đủ không?