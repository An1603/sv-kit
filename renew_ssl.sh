
#!/bin/bash
set -e

echo "🔄 Gia hạn chứng chỉ SSL với Let's Encrypt..."
sudo certbot renew --quiet --nginx

echo "🔄 Reload Nginx sau khi gia hạn..."
sudo systemctl reload nginx

echo "✅ Hoàn tất gia hạn SSL ($(date))"
