# sv-kit 🚀
Bộ cài đặt nhanh cho **n8n + Flutter Web + Nginx Proxy Manager** trên Ubuntu 22.04 LTS

## 1. Cài đặt lần đầu
```bash
git clone https://github.com/An1603/sv-kit.git
cd sv-kit
chmod +x setup.sh update.sh
./setup.sh

HOẶC NHANH NHẤT:
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash



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

3. Update n8n
ssh root@<server-ip> "cd /opt/way4 && ./update.sh"

4. Thư mục dữ liệu

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