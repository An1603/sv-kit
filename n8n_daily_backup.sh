# n8n_daily_backup.sh - Backup n8n hàng ngày và upload lên Google Drive
# Chạy trên server (root@149.28.158.156), tự động cài rclone nếu cần
# Yêu cầu: SSH key, cron job (2h sáng), Google Drive folder 'n8n-backups'
# curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_daily_backup.sh > n8n_daily_backup.sh && chmod +x n8n_daily_backup.sh && sudo ./n8n_daily_backup.sh

#!/bin/bash

# n8n_daily_backup.sh - Backup n8n hàng ngày và upload lên Google Drive
# Chạy trên server (149.28.158.156), thư mục /home/n8n, xử lý volume động

set -e

echo "=== N8N DAILY BACKUP TO GOOGLE DRIVE ($(date)) ===" | tee -a /home/n8n/backup.log

# Cấu hình
BACKUP_DIR="/home/n8n/backups"
RCLONE_REMOTE="gdrive:n8n-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.tar.gz"
KEY_FILE="$BACKUP_DIR/n8n_encryption_key_$DATE.txt"
VOLUME_NAME="n8n_n8n_data"  # Tên volume mặc định

# Tạo file log
mkdir -p /home/n8n
touch /home/n8n/backup.log
chmod 644 /home/n8n/backup.log

# Kiểm tra và cài rclone
if ! command -v rclone >/dev/null 2>&1; then
    echo "📦 Cài đặt rclone..." | tee -a /home/n8n/backup.log
    curl https://rclone.org/install.sh | bash >> /home/n8n/backup.log 2>&1
fi

# Kiểm tra file rclone.conf
if [[ ! -f ~/.config/rclone/rclone.conf ]]; then
    echo "❌ Không tìm thấy rclone.conf! Chạy 'rclone config' để thiết lập." | tee -a /home/n8n/backup.log
    echo "Hướng dẫn:" | tee -a /home/n8n/backup.log
    echo "1. Chạy: rclone config" | tee -a /home/n8n/backup.log
    echo "2. Chọn 'n' (remote mới), đặt tên: 'gdrive'." | tee -a /home/n8n/backup.log
    echo "3. Chọn 'drive' (Google Drive)." | tee -a /home/n8n/backup.log
    echo "4. Để trống client_id, client_secret." | tee -a /home/n8n/backup.log
    echo "5. Chọn scope '1' (quyền truy cập đầy đủ)." | tee -a /home/n8n/backup.log
    echo "6. Để trống root_folder_id, service_account_file." | tee -a /home/n8n/backup.log
    echo "7. Chọn 'n' (không tự động xác thực), mở URL trên trình duyệt Mac." | tee -a /home/n8n/backup.log
    echo "   Dùng: ssh -L 53682:localhost:53682 root@149.28.158.156 và mở http://127.0.0.1:53682/auth trên Mac." | tee -a /home/n8n/backup.log
    echo "8. Đăng nhập Google, lấy code, dán vào terminal." | tee -a /home/n8n/backup.log
    echo "9. Chọn 'n' (không dùng team drive), 'y' (xác nhận)." | tee -a /home/n8n/backup.log
    echo "10. KHÔNG đặt mật khẩu cấu hình (để trống)." | tee -a /home/n8n/backup.log
    exit 1
fi

# Kiểm tra file rclone.conf mã hóa
if rclone listremotes >/dev/null 2>&1; then
    echo "📜 rclone.conf hợp lệ" | tee -a /home/n8n/backup.log
else
    echo "❌ rclone.conf bị mã hóa! Giải mã hoặc cấu hình lại." | tee -a /home/n8n/backup.log
    echo "Chạy 'rclone config' và nhập mật khẩu, hoặc xóa ~/.config/rclone/rclone.conf và cấu hình lại." | tee -a /home/n8n/backup.log
    exit 1
fi

# Kiểm tra remote gdrive
if ! rclone listremotes | grep -q "^gdrive:$"; then
    echo "❌ Không tìm thấy remote 'gdrive' trong rclone.conf!" | tee -a /home/n8n/backup.log
    echo "Danh sách remote hiện có:" | tee -a /home/n8n/backup.log
    rclone listremotes | tee -a /home/n8n/backup.log
    echo "Chạy 'rclone config' và làm theo hướng dẫn ở trên." | tee -a /home/n8n/backup.log
    exit 1
fi

# Tạo thư mục n8n-backups trên Google Drive
echo "📂 Kiểm tra/tạo thư mục $RCLONE_REMOTE..." | tee -a /home/n8n/backup.log
rclone mkdir "$RCLONE_REMOTE" >> /home/n8n/backup.log 2>&1 || { echo "❌ Lỗi tạo thư mục $RCLONE_REMOTE" | tee -a /home/n8n/backup.log; exit 1; }

# Tạo thư mục backup local
mkdir -p "$BACKUP_DIR"

# Kiểm tra volume n8n
echo "🔍 Kiểm tra volume n8n..." | tee -a /home/n8n/backup.log
if ! docker volume inspect "$VOLUME_NAME" > /dev/null 2>&1; then
    echo "❌ Volume $VOLUME_NAME không tồn tại. Tìm volume khác..." | tee -a /home/n8n/backup.log
    VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep -E "n8n.*data" | head -n 1)
    if [[ -z "$VOLUME_NAME" ]]; then
        echo "❌ Không tìm thấy volume n8n nào. Kiểm tra docker-compose.yml..." | tee -a /home/n8n/backup.log
        if [[ -f /home/n8n/docker-compose.yml ]]; then
            VOLUME_NAME=$(grep -A1 "volumes:" /home/n8n/docker-compose.yml | grep -v "volumes:" | grep -o "n8n[^:]*" | head -n 1)
            if [[ -z "$VOLUME_NAME" ]]; then
                echo "❌ Không tìm thấy volume trong docker-compose.yml. Khởi động n8n để tạo volume..." | tee -a /home/n8n/backup.log
                cd /home/n8n
                docker-compose up -d >> /home/n8n/backup.log 2>&1
                sleep 10
                VOLUME_NAME=$(docker volume ls --format "{{.Name}}" | grep -E "n8n.*data" | head -n 1)
                if [[ -z "$VOLUME_NAME" ]]; then
                    echo "❌ Vẫn không tìm thấy volume n8n. Kiểm tra cấu hình n8n trong /home/n8n." | tee -a /home/n8n/backup.log
                    exit 1
                fi
            fi
        else
            echo "❌ Không tìm thấy docker-compose.yml trong /home/n8n." | tee -a /home/n8n/backup.log
            exit 1
        fi
    fi
    echo "📜 Sử dụng volume: $VOLUME_NAME" | tee -a /home/n8n/backup.log
fi

# Dừng n8n
echo "🛑 Dừng n8n..." | tee -a /home/n8n/backup.log
cd /home/n8n
docker-compose down >> /home/n8n/backup.log 2>&1

# Backup volume
echo "📦 Backup volume $VOLUME_NAME..." | tee -a /home/n8n/backup.log
docker volume inspect "$VOLUME_NAME" > /dev/null || { echo "❌ Volume $VOLUME_NAME không tồn tại" | tee -a /home/n8n/backup.log; docker-compose up -d >> /home/n8n/backup.log 2>&1; exit 1; }
tar -czf "$BACKUP_FILE" -C /var/lib/docker/volumes/"$VOLUME_NAME"/_data . >> /home/n8n/backup.log 2>&1

# Lưu encryption key
echo "🔑 Lưu encryption key..." | tee -a /home/n8n/backup.log
grep N8N_ENCRYPTION_KEY docker-compose.yml | cut -d'=' -f2- > "$KEY_FILE" || echo "N8N_ENCRYPTION_KEY=your_key_here" > "$KEY_FILE"

# Khởi động lại n8n
echo "🚀 Khởi động lại n8n..." | tee -a /home/n8n/backup.log
docker-compose up -d >> /home/n8n/backup.log 2>&1

# Upload lên Google Drive
echo "📤 Upload backup lên Google Drive ($RCLONE_REMOTE)..." | tee -a /home/n8n/backup.log
rclone copy "$BACKUP_FILE" "$RCLONE_REMOTE/" --progress >> /home/n8n/backup.log 2>&1 || { echo "❌ Lỗi upload $BACKUP_FILE" | tee -a /home/n8n/backup.log; exit 1; }
rclone copy "$KEY_FILE" "$RCLONE_REMOTE/" --progress >> /home/n8n/backup.log 2>&1 || { echo "❌ Lỗi upload $KEY_FILE" | tee -a /home/n8n/backup.log; exit 1; }

# Xóa backup cũ hơn 7 ngày
echo "🗑️ Xóa backup cũ hơn 7 ngày..." | tee -a /home/n8n/backup.log
find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -mtime +7 -delete
find "$BACKUP_DIR" -name "n8n_encryption_key_*.txt" -mtime +7 -delete
rclone delete --min-age 7d "$RCLONE_REMOTE/" --rmdirs >> /home/n8n/backup.log 2>&1

echo "✅ Backup hoàn tất: $BACKUP_FILE và $KEY_FILE đã upload!" | tee -a /home/n8n/backup.log
echo "📜 Kiểm tra Google Drive: rclone ls $RCLONE_REMOTE" | tee -a /home/n8n/backup.log