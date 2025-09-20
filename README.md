# 🚀 sv-kit

Bộ script để setup, deploy và rollback cho Flutter Web trên VPS.

## 📂 Cấu trúc
- `setup.sh` – Cài môi trường Nginx, Node.js, và thư mục `f_web` trên VPS.
- `deploy.sh` – Build Flutter web từ local, upload và deploy lên VPS.
- `rollback.sh` – Rollback về bản deploy trước.
- `utils.sh` – Các hàm dùng chung (logging, timestamp...).

## ⚙️ 1. Setup VPS lần đầu
SSH vào VPS rồi chạy:

```bash
curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash


//------------------------------------
2. Deploy web (chạy trên local)
Trong thư mục dự án Flutter:

curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh

⏪ 3. Rollback (nếu cần)
SSH vào VPS:

curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/rollback.sh -o rollback.sh
chmod +x rollback.sh
./rollback.sh

📌 Lưu ý
deploy.sh phải chạy từ local vì cần build Flutter web.
Server sẽ lưu nhiều bản trong /var/www/f_web/releases/.
rollback.sh chỉ chuyển symbolic link current sang bản trước.