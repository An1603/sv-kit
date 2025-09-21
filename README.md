# 🚀 SV-KIT

Bộ script tự động cài đặt & cập nhật **N8N** + **Flutter Web** với **Nginx + SSL Let's Encrypt**.  
Được thiết kế **fail-safe** (có rollback), mỗi domain một file riêng trong Nginx, dễ quản lý.

---

## 📂 Cấu trúc Repo
sv-kit/
├── setup.sh # Script setup lần đầu
├── update.sh # Script update (pull image mới, reload service)
└── README.md # Hướng dẫn

---

## ⚙️ Yêu cầu hệ thống

- Ubuntu 20.04/22.04/24.04
- Quyền `sudo`
- Docker + Docker Compose
- Nginx
- Certbot

Cài nhanh:

```bash
sudo apt update && sudo apt install -y docker.io docker-compose nginx



🚀 Cài đặt lần đầu
Chạy script setup.sh trực tiếp từ GitHub:
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash

curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup_n8n.sh | bash


N8N_DOMAIN=n8n.way4.app FLUTTER_DOMAIN=eurobank.eu.com
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash


👉 Script sẽ:
Hỏi domain cho N8N và Flutter Web
Tạo file config Nginx riêng cho từng domain (/etc/nginx/sites-available/)
Backup config cũ (rollback nếu lỗi)
Cài SSL với Let's Encrypt
Khởi động/reload lại Nginx


🔄 Cập nhật (Update)
Để pull image mới & restart service:
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/update.sh | bash

👉 Script sẽ:
Pull Docker image mới
Restart container
Kiểm tra & reload lại Nginx


🛠 Rollback (Khôi phục config cũ)
Nếu trong lúc setup có lỗi, script sẽ tự động rollback về config cũ (*.bak).
Trong trường hợp cần rollback thủ công:

cd /etc/nginx/sites-available/
sudo mv yourdomain.conf.bak yourdomain.conf
sudo systemctl reload nginx

📜 Log & Debug
Kiểm tra Nginx:
sudo nginx -t
sudo systemctl status nginx


Log Nginx:
journalctl -xeu nginx.service


Log Docker:
docker ps
docker logs <container_id>

✅ Ưu điểm
Mỗi domain 1 file riêng → tránh conflict
Có backup & rollback tự động
SSL Let's Encrypt tự động
Chạy nhanh chỉ với 1 lệnh curl

📧 Liên hệ
Người phát triển: Nguyễn An
Ứng dụng: Way4 / SV-KIT
---










# sv-kit 🚀
Bộ cài đặt nhanh cho **n8n + Flutter Web + Nginx Proxy Manager** trên Ubuntu 22.04 LTS

## 1. Cài đặt lần đầu
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/cleanup.sh | bash

Cách 1: Dùng ENV trước khi chạy
Bạn set biến môi trường rồi chạy script:

export N8N_DOMAIN=n8n.way4.app
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash


Tương tự cho update.sh:
export WEB_DOMAIN=eurobank.eu.com
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/update.sh | bash

Cách 2: Cho phép nhập khi pipe qua bash
Bạn đổi lệnh thành:
bash <(curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh)


Cách này cho phép read -p hoạt động bình thường vì script được chạy trong một file tạm thay vì stdin.
👉 Mình khuyên dùng Cách 1 (ENV) vì sau này bạn chỉ cần export một lần (thậm chí viết vào ~/.bashrc) → script chạy luôn, không phải nhập lại.
Bạn muốn mình sửa luôn setup.sh để nếu không có ENV thì thoát ngay với hướng dẫn export, thay vì read -p, để chạy qua curl | bash chuẩn hơn không?



Sau khi chạy xong:
Vào http://<server-ip>:81
Tài khoản mặc định: admin@example.com / changeme
Tạo Proxy Host:
way4.app → http://n8n:5678
eurobank.eu.com → http://flutter-web:80

Bật SSL Let’s Encrypt để chạy HTTPS.


Update website Flutter Web

Copy file build f_web.tar.gz vào server:

scp f_web.tar.gz root@<server-ip>:/opt/way4/
ssh root@<server-ip> "cd /opt/way4 && ./update.sh"

1. Update n8n
ssh root@<server-ip> "cd /opt/way4 && ./update.sh"

1. Thư mục dữ liệu

n8n_data/ → dữ liệu workflows của n8n

flutter_web/ → source web Flutter đã build

data/ + letsencrypt/ → cấu hình và SSL cho nginx-proxy-manager


---

👉 Với repo này bạn chỉ cần:

```bash
git clone https://github.com/An1603/sv-kit.git
cd sv-kit
./setup.sh


Là có đủ môi trường.
Update về sau cực gọn chỉ cần ./update.sh.





WEB NEW
Cách dùng
Trên máy local, lưu file này thành deploy_web.sh
nano deploy_web.sh
(dán code vào rồi CTRL+O, CTRL+X)

Cấp quyền chạy:
chmod +x deploy_web.sh

Mỗi lần muốn deploy web:
./deploy_web.sh



👉 Cách chạy:
export WEB_DOMAIN=eurobank.eu.com
./update.sh

hoặc chỉ cần chạy trực tiếp:
./update.sh


(nếu không có WEB_DOMAIN thì nó sẽ hỏi bạn nhập domain).
Bạn có muốn mình gom luôn bước Certbot SSL cho Flutter web (tự cấp HTTPS như với n8n) không, hay bạn định chỉ trỏ DNS rồi dùng reverse proxy của Cloudflare?