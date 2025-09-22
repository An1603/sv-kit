# 🚀 SV-KIT
## ⚙️ Yêu cầu hệ thống

- Ubuntu 20.04/22.04/24.04
- Quyền `sudo`


```bash
🚀 Cài đặt lần đầu
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/cleanup4caddy.sh > cleanup4caddy.sh && chmod +x cleanup4caddy.sh && sudo ./cleanup4caddy.sh


Chạy script setup.sh trực tiếp từ GitHub:
curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/setup_n8n.sh > setup_n8n.sh && chmod +x setup_n8n.sh && sudo ./setup_n8n.sh

curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/update_flutter.sh > update_flutter.sh && chmod +x update_flutter.sh && sudo ./update_flutter.sh


N8N_DOMAIN=n8n.way4.app FLUTTER_DOMAIN=eurobank.eu.com
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash



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