#!/bin/bash

# n8n_daily_backup.sh - Backup n8n hàng ngày và upload lên Google Drive
# Chạy trên server (root@46.28.69.11), tự động cài rclone nếu cần
# Yêu cầu: SSH key, cron job (2h sáng), Google Drive folder 'n8n-backups'

set -e

echo "=== N8N DAILY BACKUP TO GOOGLE DRIVE ==="

# Cấu hình
BACKUP_DIR="/opt/n8n/backups"
RCLONE_REMOTE="gdrive:n8n-backups"  # Folder Google Drive
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"
KEY_FILE="$BACKUP_DIR/n8n_encryption_key_$DATE.txt"

# Kiểm tra và cài rclone nếu chưa có
if ! command -v rclone >/dev/null 2>&1; then
    echo "📦 Cài đặt rclone..."
    curl https://rclone.org/install.sh | bash
fi

# Kiểm tra cấu hình rclone
if ! rclone listremotes | grep -q "^gdrive:$"; then
    echo "❌ Remote 'gdrive' chưa được cấu hình!"
    echo "Chạy lệnh sau để cấu hình Google Drive:"
    echo "  rclone config"
    echo "Hướng dẫn:"
    echo "1. Chọn 'n' (new remote), đặt tên 'gdrive'."
    echo "2. Chọn 'drive' (Google Drive)."
    echo "3. Để trống client_id, client_secret."
    echo "4. Chọn scope '1' (full access)."
    echo "5. Để trống root_folder_id, service_account_file."
    echo "6. Chọn 'n' (no auto config), mở URL trong trình duyệt, lấy code, dán vào terminal."
    echo "7. Chọn 'n' (no team drive), xác nhận config."
    echo "Sau khi cấu hình, chạy lại script."
    exit 1
fi

# Tạo thư mục backup
mkdir -p "$BACKUP_DIR"

# Dừng n8n để backup
echo "🛑 Dừng n8n..."
cd /opt/n8n
docker-compose down

# Backup volume
echo "📦 Backup volume n8n_data..."
docker volume inspect n8n_n8n_data > /dev/null || { echo "❌ Volume n8n_n8n_data không tồn tại"; docker-compose up -d; exit 1; }
tar -czf "$BACKUP_FILE" -C /var/lib/docker/volumes/n8n_n8n_data/_data .

# Lưu encryption key
echo "🔑 Lưu encryption key..."
grep N8N_ENCRYPTION_KEY docker-compose.yml | cut -d'=' -f2- > "$KEY_FILE" || echo "N8N_ENCRYPTION_KEY=your_key_here" > "$KEY_FILE"

# Khởi động lại n8n
echo "🚀 Khởi động lại n8n..."
docker-compose up -d

# Upload lên Google Drive
echo "📤 Upload backup lên Google Drive ($RCLONE_REMOTE)..."
rclone copy "$BACKUP_FILE" "$RCLONE_REMOTE/" --progress
rclone copy "$KEY_FILE" "$RCLONE_REMOTE/" --progress

# Xóa backup cũ hơn 7 ngày (tùy chọn)
echo "🗑️ Xóa backup cũ hơn 7 ngày..."
find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "n8n_encryption_key_*.txt" -mtime +7 -delete

echo "✅ Backup hoàn tất: $BACKUP_FILE và $KEY_FILE đã upload!"
echo "📜 Kiểm tra trên Google Drive: rclone ls $RCLONE_REMOTE"