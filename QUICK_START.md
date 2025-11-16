# Quick Start Guide - n8n on AWS with Custom Domain

> Get your n8n instance up and running with proper webhooks in 30 minutes

## Prerequisites Checklist

- [ ] AWS EC2 instance running (Ubuntu 20.04+ or Amazon Linux 2)
- [ ] Domain name registered
- [ ] SSH key (.pem file) for EC2 access
- [ ] EC2 public IP address or Elastic IP
- [ ] Your email address for SSL certificates

## Step 1: Configure DNS (5 minutes)

Point your domain to your EC2 instance:

1. Get your EC2 public IP:
   - AWS Console → EC2 → Instances → Select your instance → Copy "Public IPv4 address"

2. Add DNS A records at your domain registrar:

   | Type | Name | Value | TTL |
   |------|------|-------|-----|
   | A | @ | YOUR_EC2_IP | 300 |
   | A | www | YOUR_EC2_IP | 300 |

3. Wait 5-10 minutes for DNS propagation

4. Verify DNS:
   ```bash
   nslookup yourdomain.com
   ```

## Step 2: Configure AWS Security Groups (2 minutes)

1. AWS Console → EC2 → Security Groups
2. Find your instance's security group
3. Edit inbound rules - Add:

   | Type | Port | Source | Description |
   |------|------|--------|-------------|
   | SSH | 22 | My IP | SSH access |
   | HTTP | 80 | 0.0.0.0/0 | HTTP |
   | HTTPS | 443 | 0.0.0.0/0 | HTTPS |

4. Remove any rules for port 5678 (if present)

## Step 3: SSH to Your Server (1 minute)

```bash
ssh -i /path/to/your-key.pem ubuntu@your-ec2-ip
```

Replace:
- `/path/to/your-key.pem` with your actual key file path
- `your-ec2-ip` with your EC2 public IP
- `ubuntu` with `ec2-user` if using Amazon Linux

## Step 4: Run Initial Setup (10 minutes)

```bash
# Download setup script
curl -o setup.sh https://raw.githubusercontent.com/yourusername/n8n-webhook-domains/main/scripts/setup.sh

# Make executable
chmod +x setup.sh

# Run setup
./setup.sh
```

The script will:
- Install Docker, Docker Compose, nginx, certbot
- Ask for your domain name and email
- Generate secure passwords
- Configure n8n

**Save the credentials shown at the end!**

## Step 5: Log Out and Back In (1 minute)

```bash
exit
ssh -i /path/to/your-key.pem ubuntu@your-ec2-ip
```

This is required for Docker permissions.

## Step 6: Setup SSL Certificate (5 minutes)

```bash
# Download SSL setup script
curl -o ssl-setup.sh https://raw.githubusercontent.com/yourusername/n8n-webhook-domains/main/scripts/ssl-setup.sh

# Make executable
chmod +x ssl-setup.sh

# Run SSL setup
./ssl-setup.sh
```

The script will:
- Verify your DNS configuration
- Obtain SSL certificate from Let's Encrypt
- Configure nginx with HTTPS
- Start n8n

## Step 7: Access n8n (1 minute)

Open your browser and go to:
```
https://yourdomain.com
```

Log in with credentials from:
```bash
cat ~/n8n-production/CREDENTIALS.txt
```

## Step 8: Verify Webhook URLs (2 minutes)

1. In n8n, create a new workflow
2. Add a "Webhook" node
3. Check the webhook URL

**Expected:** `https://yourdomain.com/webhook-test/[id]`

**Not:** `http://0.0.0.0:5678/...`

If correct, you're done! ✅

## What You Have Now

✅ n8n running with Docker
✅ Custom domain with HTTPS
✅ nginx reverse proxy
✅ Automatic SSL renewal
✅ Proper webhook URLs
✅ Production-ready setup

## Common Issues

### DNS not resolving
**Wait longer** (up to 48 hours, usually 5-10 minutes)
```bash
# Check current status
nslookup yourdomain.com 8.8.8.8
```

### Cannot access via HTTPS
**Check Security Groups:**
- Ensure ports 80 and 443 are open to 0.0.0.0/0

**Check nginx:**
```bash
sudo systemctl status nginx
```

### SSL certificate failed
**Ensure:**
- DNS points to your server
- Port 80 is accessible
- No firewall blocking

**Retry:**
```bash
./ssl-setup.sh
```

### Webhooks still show 0.0.0.0
**Restart n8n:**
```bash
cd ~/n8n-production
docker-compose restart
```

**Check environment:**
```bash
docker-compose exec n8n env | grep WEBHOOK
```

## Essential Commands

```bash
# View n8n logs
cd ~/n8n-production && docker-compose logs -f

# Restart n8n
docker-compose restart

# Stop n8n
docker-compose down

# Start n8n
docker-compose up -d

# Check status
docker-compose ps

# View credentials
cat ~/n8n-production/CREDENTIALS.txt

# Reload nginx
sudo systemctl reload nginx

# Check SSL certificate
sudo certbot certificates
```

## Next Steps

1. **Secure your credentials:**
   - Copy credentials from CREDENTIALS.txt to a password manager
   - Delete the file: `rm ~/n8n-production/CREDENTIALS.txt`

2. **Create a backup:**
   ```bash
   docker run --rm \
     -v n8n-production_n8n_data:/data \
     -v ~/n8n-backups:/backup \
     ubuntu tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz /data
   ```

3. **Set up monitoring (optional):**
   - Configure CloudWatch alarms
   - Set up uptime monitoring

4. **Read full documentation:**
   - [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed instructions
   - [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Problem solving

## Getting Help

- **Full Documentation:** See [README.md](README.md)
- **Troubleshooting:** See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **n8n Community:** https://community.n8n.io
- **n8n Documentation:** https://docs.n8n.io

## Estimated Time

| Step | Time |
|------|------|
| DNS Configuration | 5 min |
| Security Groups | 2 min |
| SSH Connection | 1 min |
| Initial Setup | 10 min |
| Re-login | 1 min |
| SSL Setup | 5 min |
| Access & Verify | 3 min |
| **Total** | **~27 minutes** |

Plus DNS propagation time (0-48 hours, usually 5-10 minutes)

---

**That's it!** You now have a production-ready n8n instance with working webhooks!

For detailed explanations and advanced configurations, see the [complete setup guide](SETUP_GUIDE.md).
