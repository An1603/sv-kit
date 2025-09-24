# 🚀 SV-KIT
## ⚙️ Yêu cầu hệ thống
- Ubuntu 20.04/22.04/24.04
- ssh root@46.28.69.11
- n8n.way4.app
- eu.way4.app
- kythuat360@gmail.com

# 🚀 Cài đặt lần đầu
# Chạy script setup.sh trực tiếp từ GitHub:

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/cleanup4caddy.sh > cleanup4caddy.sh && chmod +x cleanup4caddy.sh && sudo ./cleanup4caddy.sh

# CÀI ĐẶT:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/install_n8n_and_web.sh > install_n8n_and_web.sh && chmod +x install_n8n_and_web.sh && sudo ./install_n8n_and_web.sh

# THEM WEB - Chay tren sever:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/add_admin_web.sh > add_admin_web.sh && chmod +x add_admin_web.sh && sudo ./add_admin_web.sh

# NÂNG CẤP N8N:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/upgrade-n8n.sh > upgrade-n8n.sh && chmod +x upgrade-n8n.sh && sudo ./upgrade-n8n.sh


n8n.way4.app
eu.way4.app
kythuat360@gmail.com

# UP WEB TỪ LOCAL: 
# Để tải về Mac:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/deploy_flutter_web.sh > deploy_flutter_web.sh && chmod +x deploy_flutter_web.sh && sudo ./deploy_flutter_web.sh

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/deploy_flutter_nobuild.sh > deploy_flutter_nobuild.sh && chmod +x deploy_flutter_nobuild.sh && sudo ./deploy_flutter_nobuild.sh

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/deploy_admin_nobuild.sh > deploy_admin_nobuild.sh && chmod +x deploy_admin_nobuild.sh && sudo ./deploy_admin_nobuild.sh




# CHẠY:
./deploy_admin_nobuild.sh




------------------------------------------------------------------------------------------
# BACKUP N8N DATA với Google Drive:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_daily_backup.sh > n8n_daily_backup.sh && chmod +x n8n_daily_backup.sh && sudo ./n8n_daily_backup.sh

# Cấu hình rclone với Google Drive
rclone config
- Chọn n (new remote), đặt tên gdrive.
- Chọn drive (Google Drive).
- Để trống client_id và client_secret.
- Chọn 1 (scope: full access).
- Để trống root_folder_id và service_account_file.
- Chọn n (không dùng auto config), sau đó y (yes) để mở trình duyệt trên máy khác (nếu server không có GUI, dùng máy local để lấy code xác thực).
- Dán code xác thực vào terminal server.
- Chọn n (không dùng team drive).
- Xác nhận config: y.

# Kiểm tra
rclone ls gdrive: (liệt kê file trên Google Drive).

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_daily_backup.sh > /home/n8n/n8n_daily_backup.sh
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_restore.sh > /opt/n8n/n8n_restore.sh
chmod +x /opt/n8n/n8n_*.sh



# Cấu hình cron job (2h sáng hàng ngày):
bashcrontab -e
Thêm:
text0 2 * * * /opt/n8n/n8n_daily_backup.sh >> /opt/n8n/backup.log 2>&1
Kiểm tra: crontab -l.
Kiểm tra backup trên Google Drive:
bashrclone ls gdrive:n8n-backups



# Cấu hình rclone (nếu cần):
bashrclone config
Theo hướng dẫn trong script để thiết lập remote gdrive.

# Kiểm tra:
n8n: https://n8n.way4.app (admin + pass từ script).
Web: https://eurobank.eu.com.
Backup: rclone ls gdrive:n8n-backups.
Log: tail /opt/n8n/backup.log.


# Khắc Phục Lỗi
rclone config:
bashrclone config
Copy ~/.config/rclone/rclone.conf từ server cũ nếu migrate.
Cron lỗi:
bashgrep CRON /var/log/syslog
tail /opt/n8n/backup.log

# Caddy lỗi:
bashjournalctl -xeu caddy.service

# DNS:
bashdig +short n8n.way4.app
dig +short eurobank.eu.com


# Khuyến Nghị
Tùy chỉnh thời gian: Nếu muốn giờ khác (ví dụ: 3h sáng), sửa cron job trong script (0 2 * * * thành 0 3 * * *).




# BACKUP N8N: ------------------------------------------------------------------------------------------
cd /home/n8n
cp backup_workflow.json ./n8n_data/backups/
docker compose exec -u node n8n n8n import:workflow --input=/home/node/.n8n/backups/backup_workflow.json

Copy JSON vào backup_workflow.json.
Copy vào volume:
textcp backup_workflow.json /home/n8n/backups/

Import:
textdocker compose exec -u node n8n n8n import:workflow --input=/home/node/.n8n/backups/backup_workflow.json

docker compose exec -u node n8n n8n import:workflow --input=/home/node/.n8n/backups/workflows_20250924.json
docker compose exec -u node n8n n8n import:credentials --input=/home/node/.n8n/backups/credentials_20250924.json