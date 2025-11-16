# Complete n8n Setup Guide with Domain and SSL

This guide will walk you through fixing your n8n webhook URLs and setting up a production-ready instance.

## Table of Contents
1. [Prerequisites Check](#prerequisites-check)
2. [Domain and DNS Setup](#domain-and-dns-setup)
3. [AWS Security Group Configuration](#aws-security-group-configuration)
4. [Server Preparation](#server-preparation)
5. [Docker and Docker Compose Installation](#docker-and-docker-compose-installation)
6. [n8n Configuration](#n8n-configuration)
7. [nginx Reverse Proxy Setup](#nginx-reverse-proxy-setup)
8. [SSL Certificate Setup](#ssl-certificate-setup)
9. [Final Configuration](#final-configuration)
10. [Verification and Testing](#verification-and-testing)

---

## Prerequisites Check

Before starting, ensure you have:
- [ ] AWS EC2 instance running (Ubuntu 20.04/22.04 or Amazon Linux 2 recommended)
- [ ] SSH access to your EC2 instance
- [ ] Domain name registered and accessible
- [ ] EC2 instance public IP address or Elastic IP
- [ ] Root or sudo access on the EC2 instance

**Note your details:**
```bash
EC2 Public IP: ________________
Domain Name: ________________
EC2 Instance Type: ________________
```

---

## Domain and DNS Setup

### Step 1: Get Your EC2 Public IP

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Get your public IP
curl ifconfig.me
```

### Step 2: Configure DNS Records

Go to your domain registrar's DNS management panel and create an A record:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | Your.EC2.Public.IP | 300 |
| A | www | Your.EC2.Public.IP | 300 |

**Example for yourdomain.com:**
- Type: A
- Host: @ (or leave blank)
- Points to: 54.123.45.67 (your EC2 IP)
- TTL: 300 (5 minutes)

**Wait 5-10 minutes for DNS propagation**, then verify:

```bash
# From your local machine
nslookup yourdomain.com
# Should return your EC2 IP address
```

---

## AWS Security Group Configuration

### Step 1: Access Security Groups

1. Log into AWS Console
2. Navigate to EC2 → Security Groups
3. Find your instance's security group
4. Click "Edit inbound rules"

### Step 2: Add Required Rules

Add these inbound rules:

| Type | Protocol | Port Range | Source | Description |
|------|----------|------------|--------|-------------|
| HTTP | TCP | 80 | 0.0.0.0/0 | Allow HTTP traffic |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Allow HTTPS traffic |
| SSH | TCP | 22 | Your.IP/32 | SSH access (restrict to your IP) |

**IMPORTANT:** Remove or restrict any rules allowing port 5678 from 0.0.0.0/0 (n8n should NOT be directly accessible)

### Step 3: Verify Rules

Your final security group should look like:
```
Inbound:
- Port 22 (SSH) from your IP only
- Port 80 (HTTP) from anywhere (0.0.0.0/0)
- Port 443 (HTTPS) from anywhere (0.0.0.0/0)

Outbound:
- All traffic (default)
```

---

## Server Preparation

### Step 1: Update System

```bash
# For Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# For Amazon Linux 2
sudo yum update -y
```

### Step 2: Install Basic Tools

```bash
# Ubuntu/Debian
sudo apt install -y curl wget git nano

# Amazon Linux 2
sudo yum install -y curl wget git nano
```

---

## Docker and Docker Compose Installation

### Step 1: Install Docker

**For Ubuntu:**
```bash
# Remove old versions
sudo apt remove docker docker-engine docker.io containerd runc

# Install dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Add your user to docker group
sudo usermod -aG docker $USER
```

**For Amazon Linux 2:**
```bash
sudo yum install -y docker
sudo service docker start
sudo usermod -aG docker ec2-user
```

### Step 2: Install Docker Compose

```bash
# Download Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make executable
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### Step 3: Enable Docker at Boot

```bash
# Ubuntu
sudo systemctl enable docker

# Amazon Linux 2
sudo chkconfig docker on
```

**IMPORTANT:** Log out and log back in for group changes to take effect:
```bash
exit
# SSH back in
ssh -i your-key.pem ubuntu@your-ec2-ip
```

---

## n8n Configuration

### Step 1: Create Project Directory

```bash
mkdir -p ~/n8n-production
cd ~/n8n-production
```

### Step 2: Create docker-compose.yml

```bash
nano docker-compose.yml
```

Paste this configuration:

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"  # Only accessible from localhost
    environment:
      - N8N_HOST=yourdomain.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://yourdomain.com/
      - GENERIC_TIMEZONE=America/New_York  # Change to your timezone
      - N8N_EMAIL_MODE=smtp
      - N8N_METRICS=false
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    networks:
      - n8n-network

volumes:
  n8n_data:
    driver: local

networks:
  n8n-network:
    driver: bridge
```

**IMPORTANT:** Replace:
- `yourdomain.com` with your actual domain
- `America/New_York` with your timezone (see: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

Save and exit (Ctrl+X, Y, Enter)

### Step 3: Create Environment File (Optional but Recommended)

```bash
nano .env
```

Add sensitive configuration:

```bash
# n8n Credentials
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-strong-password-here

# Encryption key (generate with: openssl rand -hex 32)
N8N_ENCRYPTION_KEY=your-encryption-key-here

# Database (optional - SQLite is default)
# DB_TYPE=postgresdb
# DB_POSTGRESDB_HOST=localhost
# DB_POSTGRESDB_PORT=5432
# DB_POSTGRESDB_DATABASE=n8n
# DB_POSTGRESDB_USER=n8n
# DB_POSTGRESDB_PASSWORD=n8n
```

Generate an encryption key:
```bash
openssl rand -hex 32
```

Update docker-compose.yml to use .env file:

```yaml
    env_file:
      - .env
```

---

## nginx Reverse Proxy Setup

### Step 1: Install nginx

```bash
# Ubuntu/Debian
sudo apt install -y nginx

# Amazon Linux 2
sudo amazon-linux-extras install nginx1 -y
```

### Step 2: Create nginx Configuration

```bash
sudo nano /etc/nginx/sites-available/n8n
```

Paste this configuration:

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;

    # Allow Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS Server (will be enabled after SSL setup)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    # SSL certificates (will be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/n8n-access.log;
    error_log /var/log/nginx/n8n-error.log;

    # Proxy settings for n8n
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;

        # Important for webhooks
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;

        # Timeouts for long-running workflows
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
```

**IMPORTANT:** Replace all instances of `yourdomain.com` with your actual domain.

### Step 3: Enable the Configuration

**For Ubuntu/Debian:**
```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Remove default config if exists
sudo rm /etc/nginx/sites-enabled/default
```

**For Amazon Linux 2:**
```bash
# Edit main nginx.conf
sudo nano /etc/nginx/nginx.conf

# Add this line in the http block:
include /etc/nginx/sites-enabled/*;

# Create directories
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled

# Now create the symlink
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
```

### Step 4: Create certbot directory

```bash
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot  # Ubuntu
# OR
sudo chown -R nginx:nginx /var/www/certbot  # Amazon Linux
```

### Step 5: Test nginx Configuration (will fail until SSL is set up)

```bash
sudo nginx -t
```

---

## SSL Certificate Setup

### Step 1: Install Certbot

**For Ubuntu:**
```bash
sudo apt install -y certbot python3-certbot-nginx
```

**For Amazon Linux 2:**
```bash
sudo yum install -y certbot python-certbot-nginx
```

### Step 2: Temporarily Configure nginx for HTTP Only

Create a temporary configuration:

```bash
sudo nano /etc/nginx/sites-available/n8n-temp
```

Paste:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://localhost:5678;
    }
}
```

Enable it:

```bash
sudo rm /etc/nginx/sites-enabled/n8n
sudo ln -s /etc/nginx/sites-available/n8n-temp /etc/nginx/sites-enabled/n8n-temp
sudo nginx -t
sudo systemctl reload nginx
```

### Step 3: Obtain SSL Certificate

```bash
sudo certbot certonly --webroot -w /var/www/certbot -d yourdomain.com -d www.yourdomain.com
```

Follow the prompts:
- Enter your email address
- Agree to terms of service
- Choose whether to share email with EFF

### Step 4: Switch to Full Configuration

```bash
sudo rm /etc/nginx/sites-enabled/n8n-temp
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/n8n
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Set Up Auto-Renewal

```bash
# Test renewal
sudo certbot renew --dry-run

# Set up automatic renewal
sudo crontab -e
```

Add this line:
```
0 0,12 * * * certbot renew --quiet && systemctl reload nginx
```

---

## Final Configuration

### Step 1: Start n8n

```bash
cd ~/n8n-production
docker-compose up -d
```

Check logs:
```bash
docker-compose logs -f
```

Press Ctrl+C to exit logs.

### Step 2: Enable nginx at Boot

```bash
sudo systemctl enable nginx
```

### Step 3: Create Backup Script

```bash
nano ~/backup-n8n.sh
```

Paste:

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/$USER/n8n-backups"
mkdir -p $BACKUP_DIR

# Backup n8n data
docker run --rm \
  -v n8n-production_n8n_data:/data \
  -v $BACKUP_DIR:/backup \
  ubuntu tar czf /backup/n8n-backup-$DATE.tar.gz /data

echo "Backup created: $BACKUP_DIR/n8n-backup-$DATE.tar.gz"

# Keep only last 7 backups
cd $BACKUP_DIR
ls -t | tail -n +8 | xargs rm -f
```

Make executable:
```bash
chmod +x ~/backup-n8n.sh
```

Add to crontab (daily at 2 AM):
```bash
crontab -e
# Add:
0 2 * * * /home/ubuntu/backup-n8n.sh
```

---

## Verification and Testing

### Step 1: Check All Services

```bash
# Check nginx
sudo systemctl status nginx

# Check Docker
docker ps

# Check n8n logs
cd ~/n8n-production
docker-compose logs --tail=50
```

### Step 2: Access n8n

Open your browser and go to:
```
https://yourdomain.com
```

You should see the n8n interface with a valid SSL certificate.

### Step 3: Test Webhook URL

1. Log into n8n
2. Create a new workflow
3. Add a "Webhook" node
4. Click "Test URL" or "Production URL"

You should see:
```
https://yourdomain.com/webhook-test/[unique-id]
```

NOT `http://0.0.0.0:5678/...`

### Step 4: Test External Webhook

```bash
# From your local machine, test the webhook
curl -X POST https://yourdomain.com/webhook-test/your-webhook-id \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

---

## Troubleshooting

### Webhooks Still Show 0.0.0.0

1. Check environment variables:
```bash
docker-compose exec n8n env | grep WEBHOOK
```

2. Restart n8n:
```bash
docker-compose down
docker-compose up -d
```

### Cannot Access n8n via Domain

1. Check DNS:
```bash
nslookup yourdomain.com
```

2. Check nginx:
```bash
sudo nginx -t
sudo systemctl status nginx
```

3. Check firewall:
```bash
sudo ufw status  # Ubuntu
```

### SSL Certificate Errors

1. Check certificate:
```bash
sudo certbot certificates
```

2. Renew manually:
```bash
sudo certbot renew --force-renewal
```

---

## Next Steps

1. Configure n8n authentication (if not using basic auth)
2. Set up monitoring (optional)
3. Configure backups to S3 (optional)
4. Review [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues
5. Join n8n community for support

---

## Maintenance Checklist

- [ ] Weekly: Check n8n logs for errors
- [ ] Monthly: Review disk space usage
- [ ] Monthly: Test backup restoration
- [ ] Quarterly: Update n8n (`docker-compose pull && docker-compose up -d`)
- [ ] Quarterly: Update system packages
- [ ] Semi-annually: Review security group rules
- [ ] Annually: Review and rotate credentials

---

## Quick Reference Commands

```bash
# View n8n logs
docker-compose logs -f

# Restart n8n
docker-compose restart

# Stop n8n
docker-compose down

# Start n8n
docker-compose up -d

# Update n8n
docker-compose pull
docker-compose up -d

# Reload nginx
sudo systemctl reload nginx

# Check nginx config
sudo nginx -t

# View SSL certificate info
sudo certbot certificates

# Manual SSL renewal
sudo certbot renew
```

---

**Congratulations!** Your n8n instance is now properly configured with a custom domain, SSL encryption, and working webhooks.
