# curl -sSL https://raw.githubusercontent.com/An1603/sv-kit/main/install_n8n_and_web.sh > install_n8n_and_web.sh && chmod +x install_n8n_and_web.sh && sudo ./install_n8n_and_web.sh
#!/bin/bash

# Kiểm tra xem script có được chạy với quyền root không
if [[ $EUID -ne 0 ]]; then
   echo "Script này cần được chạy với quyền root" 
   exit 1
fi

# Dọn dẹp Caddy cài trực tiếp trên hệ thống (nếu có)
if command -v caddy >/dev/null 2>&1; then
    echo "Phát hiện Caddy cài trực tiếp trên hệ thống. Đang dọn dẹp..."
    systemctl stop caddy
    systemctl disable caddy
    if [ -f /etc/caddy/Caddyfile ]; then
        cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak_$(date +%s)
        rm /etc/caddy/Caddyfile
    fi
    echo "Caddy trên hệ thống đã được vô hiệu hóa."
fi

# Nhận input domain từ người dùng
read -p "Nhập tên miền hoặc tên miền phụ cho n8n (ví dụ: n8n.way4.app): " N8N_DOMAIN
read -p "Nhập tên miền hoặc tên miền phụ cho website (ví dụ: eu.way4.app): " WEB_DOMAIN

# Kiểm tra DNS
SERVER_IP=$(curl -s https://api.ipify.org)
for DOMAIN in "$N8N_DOMAIN" "$WEB_DOMAIN"; do
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n 1)
    if [[ -z "$DOMAIN_IP" || "$SERVER_IP" != "$DOMAIN_IP" ]]; then
        echo "Domain $DOMAIN không trỏ về IP server $SERVER_IP (IP nhận được: $DOMAIN_IP)."
        echo "Vui lòng cập nhật DNS và thử lại."
        exit 1
    fi
done


# Sử dụng thư mục /home trực tiếp
N8N_DIR="/home/n8n"
WEB_DIR="/home/web"

# Cài đặt Docker và Docker Compose nếu chưa có
if ! command -v docker >/dev/null 2>&1 || ! command -v docker-compose >/dev/null 2>&1; then
    echo "Cài đặt Docker và Docker Compose..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose
else
    echo "Docker và Docker Compose đã có, bỏ qua cài đặt."
fi

# Tạo thư mục cho n8n
mkdir -p "$N8N_DIR"

# Tạo file docker-compose.yml
cat << EOF > "$N8N_DIR/docker-compose.yml"
version: "3"
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${N8N_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${N8N_DOMAIN}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
    volumes:
      - $N8N_DIR:/home/node/.n8n
    networks:
      - n8n_network
    dns:
      - 8.8.8.8
      - 1.1.1.1

  caddy:
    image: caddy:2
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - $N8N_DIR/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n
    networks:
      - n8n_network

networks:
  n8n_network:
    driver: bridge

volumes:
  caddy_data:
  caddy_config:
EOF

# Tạo thư mục và nội dung web tĩnh
mkdir -p "$WEB_DIR/build"
cat << EOF > "$WEB_DIR/build/index.html"
<!DOCTYPE html>
<html>
<head><title>Web App</title></head>
<body><h1>Chào mừng đến với ${WEB_DOMAIN}!</h1><p>Triển khai website của bạn tại đây.</p></body>
</html>
EOF

# Tạo file Caddyfile
cat << EOF > "$N8N_DIR/Caddyfile"
${N8N_DOMAIN} {
    reverse_proxy n8n:5678
    encode gzip
}

${WEB_DOMAIN} {
    root * $WEB_DIR/build
    file_server
    encode gzip
}
EOF

# Đặt quyền cho các thư mục
chown -R 1000:1000 "$N8N_DIR"
chmod -R 755 "$N8N_DIR"
chown -R 1000:1000 "$WEB_DIR"
chmod -R 755 "$WEB_DIR"

# Khởi động các container
cd "$N8N_DIR"
docker-compose up -d

# Thông báo hoàn tất
echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                                                             "
echo "║  ✅ Cài đặt n8n và website thành công!                      "
echo "║  🌐 Truy cập n8n: https://${N8N_DOMAIN}                    "
echo "║  🌐 Truy cập website: https://${WEB_DOMAIN}                "
echo "║                                                             "
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""