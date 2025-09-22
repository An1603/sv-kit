# 🚀 SV-KIT
## ⚙️ Yêu cầu hệ thống
- Ubuntu 20.04/22.04/24.04
- ssh root@46.28.69.11
- n8n.way4.app
- eu.way4.app
- kythuat360@gmail.com
- Quyền `sudo`


```bash
🚀 Cài đặt lần đầu
Chạy script setup.sh trực tiếp từ GitHub:

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/cleanup4caddy.sh > cleanup4caddy.sh && chmod +x cleanup4caddy.sh && sudo ./cleanup4caddy.sh

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/setup_n8n.sh > setup_n8n.sh && chmod +x setup_n8n.sh && sudo ./setup_n8n.sh

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/setup_flutter_web.sh > setup_flutter_web.sh && chmod +x setup_flutter_web.sh && sudo ./setup_flutter_web.sh

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/setup_n8n_flutter.sh > setup_n8n_flutter.sh && chmod +x setup_n8n_flutter.sh && sudo ./setup_n8n_flutter.sh


n8n.way4.app
eu.way4.app
kythuat360@gmail.com


UP WEB TỪ LOCAL: 
Để tải về Mac:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/deploy_flutter_web.sh > deploy_flutter_web.sh && chmod +x deploy_flutter_web.sh

CHẠY:
./deploy_flutter_web.sh


BACKUP N8N DATA:
Tải về Mac:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_backup_migrate.sh > n8n_backup_migrate.sh && chmod +x n8n_backup_migrate.sh

chmod +x n8n_backup_migrate.sh
./n8n_backup_migrate.sh


curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_daily_backup.sh > /opt/n8n/n8n_daily_backup.sh
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/n8n_restore.sh > /opt/n8n/n8n_restore.sh
chmod +x /opt/n8n/n8n_*.sh



Cấu hình cron job (2h sáng hàng ngày):
bashcrontab -e
Thêm:
text0 2 * * * /opt/n8n/n8n_daily_backup.sh >> /opt/n8n/backup.log 2>&1
Kiểm tra: crontab -l.
Kiểm tra backup trên Google Drive:
bashrclone ls gdrive:n8n-backups



Cấu hình rclone (nếu cần):
bashrclone config
Theo hướng dẫn trong script để thiết lập remote gdrive.

Kiểm tra:
n8n: https://n8n.way4.app (admin + pass từ script).
Web: https://eurobank.eu.com.
Backup: rclone ls gdrive:n8n-backups.
Log: tail /opt/n8n/backup.log.


Khắc Phục Lỗi
rclone config:
bashrclone config
Copy ~/.config/rclone/rclone.conf từ server cũ nếu migrate.
Cron lỗi:
bashgrep CRON /var/log/syslog
tail /opt/n8n/backup.log

Caddy lỗi:
bashjournalctl -xeu caddy.service

DNS:
bashdig +short n8n.way4.app
dig +short eurobank.eu.com


Khuyến Nghị
Tùy chỉnh thời gian: Nếu muốn giờ khác (ví dụ: 3h sáng), sửa cron job trong script (0 2 * * * thành 0 3 * * *).