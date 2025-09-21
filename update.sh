#!/bin/bash
set -euo pipefail

echo "=== SV-KIT UPDATE SCRIPT (Flutter Web) ==="

# --- Hỏi domain nếu chưa có ENV ---
if [ -z "${FLUTTER_DOMAIN:-}" ]; then
  read -rp "Nhập domain Flutter Web (vd: app.example.com): " FLUTTER_DOMAIN
fi
echo "📌 Flutter domain: $FLUTTER_DOMAIN"

# --- Kiểm tra file build ---
if [ ! -f "f_web.tar.gz" ]; then
  echo "❌ Không tìm thấy file f_web.tar.gz trong thư mục hiện tại!"
  echo "👉 Hãy chạy: flutter build web && tar -czf f_web.tar.gz -C build/web ."
  exit 1
fi

# --- Upload web ---
TARGET_DIR="/var/www/$FLUTTER_DOMAIN"
echo "📂 Deploy web vào $TARGET_DIR ..."
sudo mkdir -p "$TARGET_DIR"
sudo tar -xzf f_web.tar.gz -C "$TARGET_DIR"
sudo chown -R www-data:www-data "$TARGET_DIR"

# --- Reload Nginx ---
echo "🔄 Reload Nginx..."
sudo nginx -t && sudo systemctl reload nginx

echo "✅ Update Flutter web thành công!"
echo "👉 Truy cập: http://$FLUTTER_DOMAIN"
