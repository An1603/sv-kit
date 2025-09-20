#!/bin/bash
set -e
source <(curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/utils.sh)

SERVER_USER="root"
SERVER_IP="46.28.69.11"
DEPLOY_DIR="/var/www/f_web"
ARCHIVE_NAME="build_web_$(date +%Y%m%d%H%M%S).tar.gz"

log "🚀 Bắt đầu deploy Flutter Web..."

log "🛠 Build Flutter web..."
flutter build web

log "📦 Nén build thành $ARCHIVE_NAME..."
tar -czf $ARCHIVE_NAME -C build/web .

log "📤 Upload build lên VPS..."
scp $ARCHIVE_NAME $SERVER_USER@$SERVER_IP:/tmp/

log "📂 Giải nén và cập nhật trên VPS..."
ssh $SERVER_USER@$SERVER_IP << EOF
  set -e
  RELEASE_DIR="\$DEPLOY_DIR/releases/$(basename $ARCHIVE_NAME .tar.gz)"
  mkdir -p \$RELEASE_DIR
  tar -xzf /tmp/$ARCHIVE_NAME -C \$RELEASE_DIR
  rm /tmp/$ARCHIVE_NAME

  if [ -d "\$DEPLOY_DIR/current" ]; then
    mv \$DEPLOY_DIR/current \$DEPLOY_DIR/previous_$(date +%Y%m%d%H%M%S)
  fi

  ln -sfn \$RELEASE_DIR \$DEPLOY_DIR/current
  sudo systemctl reload nginx
EOF

rm $ARCHIVE_NAME

log "✅ Deploy hoàn tất! Website đã cập nhật."
