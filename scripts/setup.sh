#!/bin/bash

#######################################
# n8n Server Setup Script
# This script automates the initial setup of n8n on AWS EC2
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root. Run as normal user with sudo access."
    exit 1
fi

# Welcome message
clear
echo "=========================================="
echo "   n8n Production Setup Script"
echo "=========================================="
echo ""
print_message "This script will install and configure:"
echo "  - Docker and Docker Compose"
echo "  - nginx web server"
echo "  - Certbot for SSL certificates"
echo "  - n8n automation platform"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

# Detect OS
print_message "Detecting operating system..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_error "Cannot detect OS. This script supports Ubuntu and Amazon Linux 2."
    exit 1
fi

print_message "Detected: $OS $VERSION"

#######################################
# 1. Update System
#######################################
print_message "Updating system packages..."
if [ "$OS" = "ubuntu" ]; then
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl wget git nano software-properties-common apt-transport-https ca-certificates
elif [ "$OS" = "amzn" ]; then
    sudo yum update -y
    sudo yum install -y curl wget git nano
else
    print_error "Unsupported OS: $OS"
    exit 1
fi

#######################################
# 2. Install Docker
#######################################
print_message "Installing Docker..."

if command -v docker &> /dev/null; then
    print_warning "Docker is already installed. Skipping..."
else
    if [ "$OS" = "ubuntu" ]; then
        # Remove old versions
        sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Set up repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io

    elif [ "$OS" = "amzn" ]; then
        sudo yum install -y docker
        sudo service docker start
        sudo chkconfig docker on
    fi

    # Add current user to docker group
    sudo usermod -aG docker $USER

    # Enable Docker service
    sudo systemctl enable docker || true
    sudo systemctl start docker || true

    print_message "Docker installed successfully!"
fi

#######################################
# 3. Install Docker Compose
#######################################
print_message "Installing Docker Compose..."

if command -v docker-compose &> /dev/null; then
    print_warning "Docker Compose is already installed. Skipping..."
else
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Verify installation
    docker-compose --version
    print_message "Docker Compose installed successfully!"
fi

#######################################
# 4. Install nginx
#######################################
print_message "Installing nginx..."

if command -v nginx &> /dev/null; then
    print_warning "nginx is already installed. Skipping..."
else
    if [ "$OS" = "ubuntu" ]; then
        sudo apt install -y nginx
    elif [ "$OS" = "amzn" ]; then
        sudo amazon-linux-extras install nginx1 -y
    fi

    # Enable and start nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx

    print_message "nginx installed successfully!"
fi

#######################################
# 5. Install Certbot
#######################################
print_message "Installing Certbot..."

if command -v certbot &> /dev/null; then
    print_warning "Certbot is already installed. Skipping..."
else
    if [ "$OS" = "ubuntu" ]; then
        sudo apt install -y certbot python3-certbot-nginx
    elif [ "$OS" = "amzn" ]; then
        sudo yum install -y certbot python-certbot-nginx
    fi

    print_message "Certbot installed successfully!"
fi

#######################################
# 6. Create directories
#######################################
print_message "Creating project directories..."

mkdir -p ~/n8n-production
mkdir -p /var/www/certbot || sudo mkdir -p /var/www/certbot

# Set permissions for certbot directory
if [ "$OS" = "ubuntu" ]; then
    sudo chown -R www-data:www-data /var/www/certbot
elif [ "$OS" = "amzn" ]; then
    sudo chown -R nginx:nginx /var/www/certbot
fi

#######################################
# 7. Configure Firewall (if enabled)
#######################################
print_message "Checking firewall configuration..."

if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
    print_warning "UFW firewall is active. Configuring rules..."
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    print_message "Firewall rules configured."
elif command -v firewall-cmd &> /dev/null; then
    print_warning "firewalld is active. Configuring rules..."
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
    print_message "Firewall rules configured."
else
    print_message "No active firewall detected. Using AWS Security Groups only."
fi

#######################################
# 8. Get user input for configuration
#######################################
echo ""
echo "=========================================="
echo "   Configuration"
echo "=========================================="
echo ""

read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
read -p "Enter your email for SSL certificates: " EMAIL_ADDRESS
read -p "Enter your timezone (e.g., America/New_York): " TIMEZONE

# Generate random passwords
N8N_PASSWORD=$(openssl rand -base64 16)
ENCRYPTION_KEY=$(openssl rand -hex 32)

echo ""
print_message "Generated credentials (SAVE THESE SECURELY!):"
echo "  n8n Admin Username: admin"
echo "  n8n Admin Password: $N8N_PASSWORD"
echo "  Encryption Key: $ENCRYPTION_KEY"
echo ""
read -p "Press Enter to continue..."

#######################################
# 9. Create docker-compose.yml
#######################################
print_message "Creating docker-compose.yml..."

cat > ~/n8n-production/docker-compose.yml <<EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=$DOMAIN_NAME
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://$DOMAIN_NAME/
      - GENERIC_TIMEZONE=$TIMEZONE
      - NODE_ENV=production
      - N8N_EDITOR_BASE_URL=https://$DOMAIN_NAME/
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$N8N_PASSWORD
      - N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
      - N8N_METRICS=false
      - N8N_LOG_LEVEL=info
      - EXECUTIONS_PROCESS=main
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    networks:
      - n8n-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  n8n_data:
    driver: local

networks:
  n8n-network:
    driver: bridge
EOF

# Save credentials
cat > ~/n8n-production/CREDENTIALS.txt <<EOF
n8n Credentials
================
Domain: https://$DOMAIN_NAME
Username: admin
Password: $N8N_PASSWORD
Encryption Key: $ENCRYPTION_KEY

KEEP THIS FILE SECURE AND DELETE AFTER SAVING CREDENTIALS ELSEWHERE!
EOF

chmod 600 ~/n8n-production/CREDENTIALS.txt

#######################################
# 10. Create nginx configuration
#######################################
print_message "Creating nginx configuration..."

sudo tee /etc/nginx/sites-available/n8n > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

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
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

# Create sites-enabled directory if it doesn't exist
sudo mkdir -p /etc/nginx/sites-enabled

# Enable the site
if [ "$OS" = "ubuntu" ]; then
    sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
elif [ "$OS" = "amzn" ]; then
    # Add include directive if not present
    if ! grep -q "include /etc/nginx/sites-enabled/\*" /etc/nginx/nginx.conf; then
        sudo sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
    fi
    sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
fi

#######################################
# 11. Final Instructions
#######################################
echo ""
echo "=========================================="
echo "   Setup Complete!"
echo "=========================================="
echo ""
print_message "Installation completed successfully!"
echo ""
echo "IMPORTANT: You need to log out and log back in for Docker group changes to take effect:"
echo "  exit"
echo "  ssh -i your-key.pem ubuntu@your-ec2-ip"
echo ""
echo "Next steps:"
echo "  1. Ensure DNS for $DOMAIN_NAME points to this server's IP"
echo "  2. Run the SSL setup script:"
echo "     cd ~/n8n-production"
echo "     bash ../ssl-setup.sh"
echo "  3. Your credentials are saved in: ~/n8n-production/CREDENTIALS.txt"
echo ""
print_warning "SECURITY: Save your credentials and delete CREDENTIALS.txt file!"
echo ""
print_message "For full documentation, see: https://github.com/yourusername/n8n-webhook-domains"
echo ""
