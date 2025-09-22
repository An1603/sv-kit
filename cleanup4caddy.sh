#!/bin/bash
set -e

echo "=== CLEANUP OLD WEB SERVERS ==="

# Hàm dừng và gỡ gói
cleanup_service() {
    local service_name=$1
    if systemctl list-units --full -all | grep -Fq "$service_name.service"; then
        echo "🔹 Stopping $service_name..."
        sudo systemctl stop $service_name
        sudo systemctl disable $service_name
        echo "🔹 Removing $service_name packages..."
        if dpkg -l | grep -Fq "$service_name"; then
            sudo apt remove --purge -y $service_name $service_name-common
        fi
    else
        echo "🔹 $service_name not installed."
    fi
}

# Dừng và gỡ Nginx
cleanup_service nginx

# Dừng và gỡ Apache2
cleanup_service apache2

# Giải phóng port 80 và 443
echo "🔹 Checking ports 80 and 443..."
sudo fuser -k 80/tcp || true
sudo fuser -k 443/tcp || true

# Xóa cấu hình cũ (nếu có)
if [ -d /etc/nginx ]; then
    echo "🔹 Removing old Nginx configuration..."
    sudo rm -rf /etc/nginx
fi
if [ -d /etc/apache2 ]; then
    echo "🔹 Removing old Apache2 configuration..."
    sudo rm -rf /etc/apache2
fi

echo "✅ Cleanup completed. Ports 80/443 are now free for Caddy."
