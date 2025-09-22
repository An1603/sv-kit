#!/bin/bash
set -e

echo "=== SV-KIT N8N SETUP ==="

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Input domain
read -rp "Enter domain for n8n (e.g., n8n.example.com): " N8N_DOMAIN
if [[ -z "$N8N_DOMAIN" ]]; then
    echo "Domain cannot be empty!"
    exit 1
fi

# Input admin email for SSL
read -rp "Enter admin email for SSL (leave blank for automatic Let’s Encrypt): " ADMIN_EMAIL
if [[ -z "$ADMIN_EMAIL" ]]; then
    ADMIN_EMAIL=""
    echo "No email provided, using automatic Let’s Encrypt."
else
    echo "Using email: $ADMIN_EMAIL"
fi

# Check if domain resolves to server IP
SERVER_IP=$(curl -s https://api.ipify.org)
DOMAIN_IP=$(dig +short "$N8N_DOMAIN" | tail -n 1)
if [[ -z "$DOMAIN_IP" || "$SERVER_IP" != "$DOMAIN_IP" ]]; then
    echo "Domain $N8N_DOMAIN does not resolve to server IP $SERVER_IP (resolved IP: $DOMAIN_IP)."
    echo "Please update DNS records and try again."
    exit 1
fi

# Check for port conflicts
if netstat -tuln | grep -q ':80\|:443'; then
    echo "Port 80 or 443 is already in use. Please stop conflicting services (e.g., Apache, Nginx)."
    exit 1
fi

echo "📦 Updating server..."
apt update -y && apt upgrade -y

# Install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Installing Docker..."
    apt install -y docker.io
    systemctl enable docker --now
fi

# Install Docker Compose if not present
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "🐳 Installing Docker Compose..."
    apt install -y docker-compose
fi

# Install Caddy if not present
if ! command -v caddy >/dev/null 2>&1; then
    echo "🛡 Installing Caddy..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
fi

# Backup existing Caddyfile
CADDYFILE="/etc/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
    cp "$CADDYFILE" "${CADDYFILE}.bak_$(date +%s)"
fi

# Generate Caddyfile
echo "Creating Caddyfile..."
cat > "$CADDYFILE" <<EOF
$N8N_DOMAIN {
    reverse_proxy localhost:5678
    encode gzip
    $( [[ -n "$ADMIN_EMAIL" ]] && echo "tls $ADMIN_EMAIL" || echo "tls" )
}
EOF

# Validate Caddyfile
if ! caddy validate --config "$CADDYFILE"; then
    echo "❌ Invalid Caddy configuration. Restoring backup..."
    mv "${CADDYFILE}.bak_$(date +%s)" "$CADDYFILE" || true
    exit 1
fi

# Generate random password for n8n
N8N_PASSWORD=$(openssl rand -base64 12)
echo "Generated n8n password: $N8N_PASSWORD"

# Create Docker Compose file for n8n
echo "🚀 Setting up n8n..."
mkdir -p /opt/n8n
cat > /opt/n8n/docker-compose.yml <<EOL
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      - N8N_HOST=$N8N_DOMAIN
      - N8N_PROTOCOL=https
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
EOL

# Start n8n container
docker-compose -f /opt/n8n/docker-compose.yml up -d

# Start and enable Caddy
echo "Starting Caddy..."
systemctl enable caddy --now
systemctl reload caddy || { echo "❌ Failed to reload Caddy. Check logs with 'journalctl -xeu caddy.service'."; exit 1; }

echo "✅ Setup completed successfully!"
echo "👉 n8n is available at: https://$N8N_DOMAIN"
echo "👤 Username: admin"
echo "🔑 Password: $N8N_PASSWORD"
echo "⚠️ Save the password above! Update it in /opt/n8n/docker-compose.yml for production."
echo "📜 To check Caddy logs: journalctl -xeu caddy.service"
echo "📜 To check n8n logs: docker logs n8n-n8n-1"