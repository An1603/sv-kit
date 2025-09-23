# Restore n8n từ Google Drive trên server mới
# Chạy trên server mới, yêu cầu rclone và SSH key
# ssh -L 53682:localhost:53682 root@46.28.69.11
# curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_restore_gdrive.sh > n8n_restore_gdrive.sh && chmod +x n8n_restore_gdrive.sh && sudo ./n8n_restore_gdrive.sh

#!/bin/bash

# n8n_restore_gdrive.sh - Restore n8n từ Google Drive trên server 46.28.69.11
# Chạy trực tiếp trên server, thư mục /home/n8n
# Tự động lấy file backup mới nhất từ gdrive:n8n-backups

set -e

echo "=== RESTORE N8N FROM GOOGLE DRIVE ($(date)) ===" | tee -a /home/n8n/restore.log

# Cấu hình
RCLONE_REMOTE="gdrive:n8n-backups"
BACKUP_DIR="/tmp/n8n_restore"
RESTORE_LOG="/home/n8n/restore.log"
N8N_DIR="/home/n8n"
TEMP_BACKUP_FILE="$BACKUP_DIR/n8n_backup_latest.tar.gz"
TEMP_KEY_FILE="$BACKUP_DIR/n8n_encryption_key_latest.txt"

# Tạo file log
mkdir -p /home/n8n
touch "$RESTORE_LOG"
chmod 644 "$RESTORE_LOG"

# Kiểm tra rclone
if ! command -v rclone >/dev/null 2>&1; then
    echo "📦 Cài rclone..." | tee -a "$RESTORE_LOG"
    curl https://rclone.org/install.sh | bash >> "$RESTORE_LOG" 2>&1
fi

# Kiểm tra remote gdrive
if ! rclone listremotes | grep -q "^gdrive:$"; then
    echo "❌ Remote 'gdrive' không tồn tại! Chạy 'rclone config'." | tee -a "$RESTORE_LOG"
    echo "Danh sách remote hiện có:" | tee -a "$RESTORE_LOG"
    rclone listremotes | tee -a "$RESTORE_LOG"
    exit 1
fi

# Check file list và lấy file mới nhất
echo "🔍 Kiểm tra file list trong $RCLONE_REMOTE..." | tee -a "$RESTORE_LOG"
rclone ls "$RCLONE_REMOTE" >> "$RESTORE_LOG" 2>&1

# Lấy file backup mới nhất (định dạng n8n_backup_YYYYMMDD_HHMMSS.tar.gz)
BACKUP_DATE=$(rclone ls "$RCLONE_REMOTE" | grep "n8n_backup_" | sort -r | head -n 1 | awk '{print $NF}' | grep -o '[0-9]\{8\}_[0-9]\{6\}' | head -n 1)

if [[ -z "$BACKUP_DATE" ]]; then
    echo "❌ Không tìm thấy file backup nào trong $RCLONE_REMOTE!" | tee -a "$RESTORE_LOG"
    echo "Danh sách file:" | tee -a "$RESTORE_LOG"
    rclone ls "$RCLONE_REMOTE" | tee -a "$RESTORE_LOG"
    exit 1
fi

BACKUP_FILE_NAME="n8n_backup_$BACKUP_DATE.tar.gz"
KEY_FILE_NAME="n8n_encryption_key_$BACKUP_DATE.txt"

echo "📁 File backup mới nhất: $BACKUP_FILE_NAME" | tee -a "$RESTORE_LOG"
echo "📁 File key mới nhất: $KEY_FILE_NAME" | tee -a "$RESTORE_LOG"

# Tạo thư mục tạm
mkdir -p "$BACKUP_DIR"

# Tải file từ Google Drive
echo "📥 Tải backup từ Google Drive..." | tee -a "$RESTORE_LOG"
rclone copy "$RCLONE_REMOTE/$BACKUP_FILE_NAME" "$BACKUP_DIR/" --progress >> "$RESTORE_LOG" 2>&1 || { echo "❌ Lỗi tải backup" | tee -a "$RESTORE_LOG"; exit 1; }
rclone copy "$RCLONE_REMOTE/$KEY_FILE_NAME" "$BACKUP_DIR/" --progress >> "$RESTORE_LOG" 2>&1 || { echo "❌ Lỗi tải key" | tee -a "$RESTORE_LOG"; exit 1; }



# Restore dữ liệu
echo "🔄 Restore dữ liệu..." | tee -a "$RESTORE_LOG"
cd "$N8N_DIR"
docker-compose down || true
docker volume rm n8n_data || true
docker volume create n8n_data
tar -xzf "$BACKUP_DIR/$BACKUP_FILE_NAME" -C /var/lib/docker/volumes/n8n_data/_data . >> "$RESTORE_LOG" 2>&1
KEY=$(cat "$BACKUP_DIR/$KEY_FILE_NAME" | cut -d'=' -f2-)
sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$KEY/" docker-compose.yml
rm "$BACKUP_DIR/$BACKUP_FILE_NAME" "$BACKUP_DIR/$KEY_FILE_NAME"
docker-compose up -d >> "$RESTORE_LOG" 2>&1

# Dọn dẹp
rm -rf "$BACKUP_DIR"

echo "✅ Restore hoàn tất!" | tee -a "$RESTORE_LOG"
echo "👉 Kiểm tra n8n: https://n8n.way4.app" | tee -a "$RESTORE_LOG"
echo "📜 Log: cat $RESTORE_LOG" | tee -a "$RESTORE_LOG"