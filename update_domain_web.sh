#!/bin/bash

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root"
   exit 1
fi

# Kiểm tra xem thư mục n8n có tồn tại không
N8N_DIR="/home/n8n"
if [ ! -d "$N8N_DIR" ] || [ ! -f "$N8N_DIR/Caddyfile" ]; then
    echo "Không tìm thấy thư mục /home/n8n hoặc file Caddyfile. Vui lòng đảm bảo hệ thống đã được cài đặt."
    exit 1
fi

# Hỏi người dùng muốn sửa tên miền nào
echo "Bạn muốn sửa tên miền của:"
echo "1. Website chính"
echo "2. Website admin"
read -p "Chọn 1 hoặc 2: " CHOICE

case $CHOICE in
  1)
    WEB_TYPE="web"
    WEB_DIR="/home/web"
    ;;
  2)
    WEB_TYPE="admin"
    WEB_DIR="/home/admin"
    ;;
  *)
    echo "Lựa chọn không hợp lệ. Vui lòng chọn 1 hoặc 2."
    exit 1
    ;;
esac

# Kiểm tra xem thư mục web/admin có tồn tại không
if [ ! -d "$WEB_DIR" ]; then
    echo "Thư mục $WEB_DIR không tồn tại. Vui lòng đảm bảo website $WEB_TYPE đã được cài đặt."
    exit 1
fi

# Nhận input tên miền mới
read -p "Nhập tên miền mới cho website $WEB_TYPE (ví dụ: new.$WEB_TYPE.eu.com): " NEW_DOMAIN

# Kiểm tra DNS
SERVER_IP=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short "$NEW_DOMAIN" | tail -n 1)
if [[ -z "$DOMAIN_IP" || "$SERVER_IP" != "$DOMAIN_IP" ]]; then
    echo "Tên miền $NEW_DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $DOMAIN_IP)."
    echo "Vui lòng cập nhật DNS và thử lại."
    exit 1
fi

# Sao lưu file Caddyfile hiện tại
cp "$N8N_DIR/Caddyfile" "$N8N_DIR/Caddyfile.bak_$(date +%s)"

# Lấy tên miền cũ từ Caddyfile
if [ "$WEB_TYPE" = "web" ]; then
    OLD_DOMAIN=$(grep -B1 "root * $WEB_DIR/build" "$N8N_DIR/Caddyfile" | head -n1 | awk '{print $1}')
elif [ "$WEB_TYPE" = "admin" ]; then
    OLD_DOMAIN=$(grep -B1 "root * $WEB_DIR/build" "$N8N_DIR/Caddyfile" | head -n1 | awk '{print $1}')
fi

if [ -z "$OLD_DOMAIN" ]; then
    echo "Không tìm thấy tên miền cũ cho website $WEB_TYPE trong Caddyfile."
    exit 1
fi

# Cập nhật Caddyfile với tên miền mới
sed -i "s/${OLD_DOMAIN}/${NEW_DOMAIN}/" "$N8N_DIR/Caddyfile"

# Cập nhật nội dung index.html với tên miền mới
# cat << EOF > "$WEB_DIR/build/index.html"
# <!DOCTYPE html>
# <html>
# <head><title>${WEB_TYPE^} Web App</title></head>
# <body><h1>Chào mừng đến với ${NEW_DOMAIN}!</h1><p>Triển khai website ${WEB_TYPE} của bạn tại đây.</p></body>
# </html>
# EOF

# Đặt lại quyền cho thư mục
chown -R 1000:1000 "$WEB_DIR"
chmod -R 755 "$WEB_DIR"

# Khởi động lại các container để áp dụng thay đổi
cd "$N8N_DIR"
docker-compose down
docker-compose up -d

# Thông báo hoàn tất
echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                                                             "
echo "║  ✅ Đã cập nhật tên miền cho website $WEB_TYPE thành công!  "
echo "║  🌐 Truy cập website $WEB_TYPE: https://${NEW_DOMAIN}      "
echo "║                                                             "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""