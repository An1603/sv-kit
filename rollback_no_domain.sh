#!/bin/bash
set -e
source <(curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/utils.sh)

DEPLOY_DIR="/var/www/f_web"

log "🔄 Bắt đầu rollback..."

if [ -L "$DEPLOY_DIR/current" ]; then
  CURRENT_TARGET=$(readlink $DEPLOY_DIR/current)
  PREVIOUS_DIR=$(ls -td $DEPLOY_DIR/previous_* 2>/dev/null | head -n 1)

  if [ -n "$PREVIOUS_DIR" ]; then
    log "⏪ Đang rollback sang $PREVIOUS_DIR..."
    ln -sfn $PREVIOUS_DIR $DEPLOY_DIR/current
    sudo systemctl reload nginx
    log "✅ Rollback thành công!"
  else
    warn "Không tìm thấy bản previous nào để rollback"
  fi
else
  warn "Không tìm thấy current để rollback"
fi
