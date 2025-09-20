#!/bin/bash
set -e
source "$(dirname "$0")/utils.sh"

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
  echo "❌ Bạn phải nhập DOMAIN để rollback"
  echo "👉 Ví dụ: ./rollback.sh example.com"
  exit 1
fi

REMOTE_USER="root"
REMOTE_HOST="46.28.69.11"
REMOTE_DIR="/var/www/$DOMAIN"

note "⏪ Rollback cho domain: $DOMAIN"

ssh $REMOTE_USER@$REMOTE_HOST <<EOF
  if [ -d "$REMOTE_DIR.bak" ]; then
    rm -rf $REMOTE_DIR
    mv $REMOTE_DIR.bak $REMOTE_DIR
    systemctl reload nginx
    echo "✅ Rollback thành công"
  else
    echo "❌ Không tìm thấy bản backup trước"
  fi
EOF
