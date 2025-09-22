#!/bin/bash
set -e

# Nhập thông tin server
read -rp "Nhập user@server: " SERVER
read -rp "Nhập domain Flutter Web: " FLUTTER_DOMAIN

# Build Flutter web
flutter build web --release

# Tạo file tar.gz
tar -czf f_web.tar.gz -C build web

# Upload lên server
scp f_web.tar.gz "$SERVER":/root/

# Gọi script update trên server
ssh "$SERVER" "FLUTTER_DOMAIN=$FLUTTER_DOMAIN bash -s" < update_flutter.sh

echo "✅ Đã upload và deploy Flutter Web lên $SERVER"
