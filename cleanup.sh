
# Cleanup an toàn trước setup.sh

# Dừng và xóa Apache (nếu có)
systemctl stop apache2 2>/dev/null
systemctl disable apache2 2>/dev/null
apt purge -y apache2* 2>/dev/null
apt autoremove -y

# Dọn config nginx cũ
rm -f /etc/nginx/sites-enabled/* 
rm -f /etc/nginx/sites-available/*

# Xóa default config
rm -f /etc/nginx/sites-enabled/default
