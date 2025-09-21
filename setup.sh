#!/bin/bash
# setup.sh - Cài đặt hoặc update môi trường n8n + Flutter Web + Nginx Proxy Manager
# Dùng với: curl -s https://raw.githubusercontent.com/An1603/sv-kit/main/setup.sh | bash

set -e

REPO_URL="https://github.com/An1603/sv-kit.git"
INSTALL_DIR="/opt/way4"

if [ -d "$INSTALL_DIR" ]; then
    echo "=== Phát hiện đã có cài đặt trước đó tại $INSTALL_DIR ==="
    cd $INSTALL_DIR

    echo "=== Pull code mới nhất từ repo ==="
    git pull origin main

    echo "=== Update Docker images và restart containers ==="
    docker compose pull
    docker compose up -d

    echo "✅ Update hoàn tất!"
else
    echo "=== Cập nhật hệ thống lần đầu ==="
    apt-get update -y && apt-get upgrade -y

    echo "=== Cài Docker & Docker Compose lần đầu ==="
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git

    mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    echo "=== Clone repo sv-kit về $INSTALL_DIR ==="
    git clone $REPO_URL $INSTALL_DIR

    cd $INSTALL_DIR

    echo "=== Khởi động Docker Compose lần đầu ==="
    docker compose up -d

    echo "=== Setup hoàn tất lần đầu ==="
    echo "👉 Truy cập http://<server-ip>:81 để vào Nginx Proxy Manager"
    echo "   Mặc định: admin@example.com / changeme"
fi
