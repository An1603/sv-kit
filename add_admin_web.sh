#!/bin/bash

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root"
   exit 1
fi

# Kiểm tra xem thư mục n8n có tồn tại không
N8N_DIR="/home/n8n"
if [ ! -d "$N8N_DIR" ] || [ ! -f "$N8N_DIR/docker-compose.yml" ]; then
    echo "Không tìm thấy thư mục /home/n8n hoặc file docker-compose.yml. Vui lòng đảm bảo n8n đã được cài đặt."
    exit 1
fi

# Nhận input domain cho website admin
read -p "Nhập tên miền hoặc tên miền phụ cho website admin (ví dụ: admin.eurobank.eu.com): " ADMIN_DOMAIN

# Kiểm tra DNS
SERVER_IP=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short "$ADMIN_DOMAIN" | tail -n 1)
if [[ -z "$DOMAIN_IP" || "$SERVER_IP" != "$DOMAIN_IP" ]]; then
    echo "Domain $ADMIN_DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $DOMAIN_IP)."
    echo "Vui lòng cập nhật DNS và thử lại."
    exit 1
fi

# Tạo thư mục cho website admin
ADMIN_DIR="/home/admin"
mkdir -p "$ADMIN_DIR/build"

# Tạo nội dung web tĩnh cho website admin
cat << EOF > "$ADMIN_DIR/build/index.html"
<!DOCTYPE html>
<html>
<head><title>Admin Web App</title></head>
<body><h1>Chào mừng đến với ${ADMIN_DOMAIN}!</h1><p>Triển khai website admin của bạn tại đây.</p></body>
</html>
EOF

# Đặt quyền cho thư mục admin
chown -R 1000:1000 "$ADMIN_DIR"
chmod -R 755 "$ADMIN_DIR"

# Sao lưu file docker-compose.yml hiện tại
cp "$N8N_DIR/docker-compose.yml" "$N8N_DIR/docker-compose.yml.bak_$(date +%s)"

# Cập nhật file docker-compose.yml để thêm volume cho admin
sed -i '/- \/home\/web\/build:\/home\/web\/build/a \      - /home/admin/build:/home/admin/build' "$N8N_DIR/docker-compose.yml"

# Sao lưu file Caddyfile hiện tại
cp "$N8N_DIR/Caddyfile" "$N8N_DIR/Caddyfile.bak_$(date +%s)"

# Thêm cấu hình cho website admin vào Caddyfile
cat << EOF >> "$N8N_DIR/Caddyfile"

${ADMIN_DOMAIN} {
    root * $ADMIN_DIR/build
    file_server
    encode gzip
}
EOF

# Khởi động lại các container để áp dụng thay đổi
cd "$N8N_DIR"
docker-compose down
docker-compose up -d

# Thông báo hoàn tất
echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                                                             "
echo "║  ✅ Đã bổ sung website admin thành công!                    "
echo "║  🌐 Truy cập website admin: https://${ADMIN_DOMAIN}        "
echo "║                                                             "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""