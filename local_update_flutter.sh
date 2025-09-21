#!/bin/bash
set -euo pipefail

echo "=== LOCAL UPDATE FLUTTER WEB ==="

# Config server
SERVER_USER="root"
SERVER_IP="your.server.ip"   # ⚠️ sửa lại
SERVER_PATH="/tmp/flutter_build.zip"

# Domain Flutter Web (trùng với setup.sh & server)
FLUTTER_DOMAIN="app.example.com"  # ⚠️ sửa lại nếu cần

# Build Flutter Web
echo "🏗️ Build Flutter Web..."
flutter build web --release

# Nén build
cd build/web
zip -rq flutter_build.zip .
cd ../..

# Upload lên server
echo "📤 Upload build lên server..."
scp build/web/flutter_build.zip $SERVER_USER@$SERVER_IP:$SERVER_PATH

# Gọi update script trên server
echo "🚀 Triển khai trên server..."
ssh $SERVER_USER@$SERVER_IP "bash /opt/sv-kit/update_flutter.sh <<EOF
$FLUTTER_DOMAIN
EOF"

echo "✅ Update hoàn tất!"
echo "👉 Truy cập: http://$FLUTTER_DOMAIN"



# Quy trình chạy
# Trên server: copy update_flutter.sh vào /opt/sv-kit/update_flutter.sh
# chmod +x /opt/sv-kit/update_flutter.sh

# Trên máy cá nhân: copy local_update_flutter.sh về repo, sửa SERVER_IP + SERVER_USER + FLUTTER_DOMAIN, sau đó:
# chmod +x local_update_flutter.sh
# ./local_update_flutter.sh

# → Tự động build Flutter Web → nén → scp → gọi script server → deploy.