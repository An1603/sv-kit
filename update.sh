#!/bin/bash
set -euo pipefail

echo "=== SV-KIT UPDATE SCRIPT ==="

# Update docker images
echo "🐳 Update Docker..."
docker compose pull
docker compose up -d

# Reload nginx nếu có thay đổi
echo "🔄 Reload Nginx..."
nginx -t && systemctl reload nginx

echo "✅ Update hoàn tất!"
