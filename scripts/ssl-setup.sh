#!/bin/bash

#######################################
# SSL Certificate Setup Script
# Obtains and configures SSL certificates for n8n
#######################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

# Welcome message
clear
echo "=========================================="
echo "   n8n SSL Certificate Setup"
echo "=========================================="
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    print_error "nginx is not installed. Please run setup.sh first."
    exit 1
fi

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    print_error "certbot is not installed. Please run setup.sh first."
    exit 1
fi

# Get domain from nginx config if it exists
DOMAIN=$(grep -oP 'server_name \K[^;]+' /etc/nginx/sites-available/n8n 2>/dev/null | awk '{print $1}' || echo "")

# Prompt for configuration
if [ -z "$DOMAIN" ]; then
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
else
    print_message "Found domain in nginx config: $DOMAIN"
    read -p "Use this domain? (y/n): " USE_EXISTING
    if [ "$USE_EXISTING" != "y" ]; then
        read -p "Enter your domain name (e.g., example.com): " DOMAIN
    fi
fi

read -p "Enter your email address for SSL notifications: " EMAIL

#######################################
# 1. Verify DNS Configuration
#######################################
print_message "Verifying DNS configuration..."

# Get server's public IP
PUBLIC_IP=$(curl -s ifconfig.me)
print_message "Server public IP: $PUBLIC_IP"

# Check DNS resolution
DNS_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -n1)

if [ -z "$DNS_IP" ]; then
    print_error "DNS is not configured for $DOMAIN"
    print_warning "Please configure DNS A record to point to $PUBLIC_IP"
    exit 1
elif [ "$DNS_IP" != "$PUBLIC_IP" ]; then
    print_warning "DNS points to $DNS_IP but server IP is $PUBLIC_IP"
    read -p "Continue anyway? DNS might not be fully propagated yet. (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
else
    print_message "DNS is correctly configured!"
fi

#######################################
# 2. Prepare nginx for HTTP challenge
#######################################
print_message "Preparing nginx for SSL certificate challenge..."

# Create temporary nginx config for HTTP only
sudo tee /etc/nginx/sites-available/n8n-temp > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
    }
}
EOF

# Switch to temporary config
sudo rm -f /etc/nginx/sites-enabled/n8n
sudo ln -s /etc/nginx/sites-available/n8n-temp /etc/nginx/sites-enabled/n8n-temp

# Test nginx configuration
if ! sudo nginx -t; then
    print_error "nginx configuration test failed!"
    exit 1
fi

# Reload nginx
sudo systemctl reload nginx
print_message "nginx configured for HTTP challenge"

#######################################
# 3. Obtain SSL Certificate
#######################################
print_message "Obtaining SSL certificate from Let's Encrypt..."

# Run certbot
if sudo certbot certonly --webroot \
    -w /var/www/certbot \
    -d $DOMAIN \
    -d www.$DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --non-interactive; then
    print_message "SSL certificate obtained successfully!"
else
    print_error "Failed to obtain SSL certificate"
    print_warning "Common issues:"
    echo "  - DNS not pointing to this server"
    echo "  - Port 80 not accessible (check AWS Security Group)"
    echo "  - Domain already has certificates (try --force-renewal)"
    exit 1
fi

#######################################
# 4. Configure nginx with SSL
#######################################
print_message "Configuring nginx with SSL..."

sudo tee /etc/nginx/sites-available/n8n > /dev/null <<EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS Server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/n8n-access.log;
    error_log /var/log/nginx/n8n-error.log;

    # Proxy to n8n
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

# Remove temporary config and enable main config
sudo rm -f /etc/nginx/sites-enabled/n8n-temp
sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n

# Test nginx configuration
if ! sudo nginx -t; then
    print_error "nginx configuration test failed!"
    exit 1
fi

# Reload nginx
sudo systemctl reload nginx
print_message "nginx configured with SSL"

#######################################
# 5. Set up automatic renewal
#######################################
print_message "Setting up automatic SSL renewal..."

# Create renewal script
cat > /tmp/renew-ssl.sh <<EOF
#!/bin/bash
certbot renew --quiet && systemctl reload nginx
EOF

sudo mv /tmp/renew-ssl.sh /usr/local/bin/renew-ssl.sh
sudo chmod +x /usr/local/bin/renew-ssl.sh

# Add to crontab
(sudo crontab -l 2>/dev/null || true; echo "0 0,12 * * * /usr/local/bin/renew-ssl.sh") | sudo crontab -

print_message "Automatic SSL renewal configured (checks twice daily)"

#######################################
# 6. Test SSL Certificate
#######################################
print_message "Testing SSL certificate..."

# Test renewal
if sudo certbot renew --dry-run; then
    print_message "SSL renewal test passed!"
else
    print_warning "SSL renewal test failed - check configuration"
fi

#######################################
# 7. Start n8n if not running
#######################################
print_message "Checking n8n status..."

cd ~/n8n-production

if ! docker-compose ps | grep -q "n8n.*Up"; then
    print_message "Starting n8n..."
    docker-compose up -d
    sleep 5

    if docker-compose ps | grep -q "n8n.*Up"; then
        print_message "n8n started successfully!"
    else
        print_error "Failed to start n8n. Check logs with: docker-compose logs"
    fi
else
    print_message "n8n is already running. Restarting..."
    docker-compose restart
fi

#######################################
# 8. Final verification
#######################################
echo ""
echo "=========================================="
echo "   SSL Setup Complete!"
echo "=========================================="
echo ""
print_message "Your n8n instance should now be accessible at:"
echo "  https://$DOMAIN"
echo ""
print_message "Verifying SSL certificate..."

# Wait a moment for nginx to fully reload
sleep 3

# Test HTTPS connection
if curl -sS -o /dev/null -w "%{http_code}" https://$DOMAIN | grep -q "200\|401\|302"; then
    print_message "HTTPS is working correctly!"
else
    print_warning "Could not verify HTTPS connection. Please check manually."
fi

echo ""
print_message "Testing webhook URL format..."
echo "  Expected webhook format: https://$DOMAIN/webhook-test/[id]"
echo ""
echo "Next steps:"
echo "  1. Visit https://$DOMAIN in your browser"
echo "  2. Log in with credentials from ~/n8n-production/CREDENTIALS.txt"
echo "  3. Create a test workflow with a webhook node"
echo "  4. Verify webhook URL shows your domain (not 0.0.0.0)"
echo ""
print_message "SSL certificates will automatically renew every 90 days"
echo ""
echo "Certificate details:"
sudo certbot certificates | grep -A 5 "$DOMAIN"
echo ""
