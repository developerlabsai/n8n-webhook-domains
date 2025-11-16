# n8n Webhook and Domain Configuration

> Complete setup guide for fixing n8n webhook URLs on AWS EC2 with custom domain and SSL/TLS

## The Problem

Your n8n instance is generating webhook URLs like:
```
http://0.0.0.0:5678/webhook-test/54f98dcd-6c03-480f-bdb9-b2a551010f5a
```

This won't work for external services trying to send webhooks to your n8n instance.

## The Solution

This project provides everything you need to fix this issue and set up a production-ready n8n instance with:

- ✅ Custom domain (e.g., `yourdomain.com`)
- ✅ SSL/TLS encryption (HTTPS)
- ✅ nginx reverse proxy
- ✅ Automatic SSL certificate renewal
- ✅ Proper webhook URLs: `https://yourdomain.com/webhook-test/...`
- ✅ Security best practices
- ✅ Automated setup scripts

## Quick Start

### Prerequisites

- AWS EC2 instance (Ubuntu/Amazon Linux)
- Domain name registered
- SSH access to your server
- Basic Linux command-line knowledge

### 1. Clone This Repository

On your **local machine**:
```bash
git clone https://github.com/yourusername/n8n-webhook-domains.git
cd n8n-webhook-domains
```

### 2. Configure DNS

Point your domain to your EC2 instance's public IP:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | Your.EC2.IP | 300 |
| A | www | Your.EC2.IP | 300 |

See [docs/DNS_SETUP.md](docs/DNS_SETUP.md) for detailed instructions.

### 3. Configure AWS Security Groups

Ensure these ports are open:
- Port 22 (SSH) - Your IP only
- Port 80 (HTTP) - 0.0.0.0/0
- Port 443 (HTTPS) - 0.0.0.0/0

See [docs/AWS_SECURITY_GROUPS.md](docs/AWS_SECURITY_GROUPS.md) for details.

### 4. Upload Setup Files to Server

From your **local machine**:
```bash
scp -r scripts your-key.pem ubuntu@your-ec2-ip:~/
```

### 5. Run Setup Script

SSH into your **EC2 instance**:
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
cd ~/scripts
chmod +x *.sh
./setup.sh
```

Follow the prompts to:
- Install Docker, Docker Compose, nginx, and certbot
- Configure your domain and email
- Generate secure passwords

### 6. Log Out and Back In

```bash
exit
ssh -i your-key.pem ubuntu@your-ec2-ip
```

This is required for Docker group permissions.

### 7. Run SSL Setup

```bash
cd ~/scripts
./ssl-setup.sh
```

This will:
- Obtain SSL certificate from Let's Encrypt
- Configure nginx with SSL
- Start n8n with proper configuration

### 8. Access Your n8n Instance

Open your browser and go to:
```
https://yourdomain.com
```

Log in with credentials from `~/n8n-production/CREDENTIALS.txt`

## Verify Webhook URLs

1. Create a test workflow in n8n
2. Add a "Webhook" node
3. Check the webhook URL

It should now show:
```
https://yourdomain.com/webhook-test/[unique-id]
```

NOT `http://0.0.0.0:5678/...` ✅

## Project Structure

```
n8n-webhook-and-domains/
├── README.md                       # This file
├── PROJECT_OVERVIEW.md             # Detailed project overview
├── SETUP_GUIDE.md                  # Step-by-step setup guide
├── MCP_SERVERS.md                  # MCP server recommendations
├── docker-compose.yml              # n8n Docker configuration
├── .env.example                    # Environment variables template
├── nginx/
│   └── sites-available/
│       └── n8n.conf                # nginx configuration
├── scripts/
│   ├── setup.sh                    # Initial setup script
│   ├── ssl-setup.sh                # SSL certificate setup
│   └── deploy.sh                   # Deployment management
└── docs/
    ├── AWS_SECURITY_GROUPS.md      # Security group configuration
    ├── DNS_SETUP.md                # DNS configuration guide
    └── TROUBLESHOOTING.md          # Common issues and solutions
```

## Documentation

### Essential Guides
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete step-by-step setup instructions
- **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)** - Project architecture and details
- **[MCP_SERVERS.md](MCP_SERVERS.md)** - Recommended MCP servers to speed up setup

### Configuration Guides
- **[docs/DNS_SETUP.md](docs/DNS_SETUP.md)** - Configure domain DNS records
- **[docs/AWS_SECURITY_GROUPS.md](docs/AWS_SECURITY_GROUPS.md)** - AWS firewall configuration

### Maintenance
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## MCP Servers (Optional but Recommended)

To make this setup even faster, install these Model Context Protocol (MCP) servers:

### Essential MCP Servers
1. **AWS MCP Server** - Manage AWS resources directly
2. **SSH MCP Server** - Execute commands on EC2
3. **Docker MCP Server** - Manage Docker containers
4. **File System MCP Server** - Manage configuration files

See [MCP_SERVERS.md](MCP_SERVERS.md) for complete installation and configuration instructions.

With MCP servers, the entire setup can be completed in **15-20 minutes** instead of 2-3 hours!

## Management Commands

### Start/Stop/Restart n8n

```bash
cd ~/n8n-production

# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View logs
docker-compose logs -f
```

### Using Deploy Script

```bash
cd ~/n8n-production
../scripts/deploy.sh
```

This interactive script can:
- Start/Stop/Restart n8n
- Update to latest version
- View logs and status
- Create backups
- Full deployment

### Update n8n

```bash
cd ~/n8n-production
docker-compose pull
docker-compose up -d
```

### Backup n8n Data

```bash
docker run --rm \
  -v n8n-production_n8n_data:/data \
  -v ~/n8n-backups:/backup \
  ubuntu tar czf /backup/n8n-backup-$(date +%Y%m%d_%H%M%S).tar.gz /data
```

### View Logs

```bash
# n8n logs
cd ~/n8n-production
docker-compose logs -f

# nginx logs
sudo tail -f /var/log/nginx/n8n-access.log
sudo tail -f /var/log/nginx/n8n-error.log
```

## Architecture

```
Internet
    ↓
AWS Security Group (Ports 80/443 open)
    ↓
EC2 Instance (yourdomain.com)
    ↓
nginx Reverse Proxy (SSL termination)
    ↓
n8n Docker Container (localhost:5678)
```

## Security Features

- ✅ SSL/TLS encryption (HTTPS only)
- ✅ Automatic certificate renewal
- ✅ n8n not directly exposed (localhost only)
- ✅ nginx reverse proxy with security headers
- ✅ AWS Security Groups (firewall)
- ✅ Basic authentication for n8n
- ✅ Encrypted data at rest

## Cost Estimate

| Service | Cost (Monthly) |
|---------|----------------|
| EC2 t3.small | ~$15-20 |
| Domain name | ~$1-3 |
| SSL Certificate | Free (Let's Encrypt) |
| Data transfer | Varies by usage |
| **Total** | **~$16-25/month** |

## Troubleshooting

### Webhooks still show 0.0.0.0

Check environment variables:
```bash
docker-compose exec n8n env | grep WEBHOOK
```

Should show: `WEBHOOK_URL=https://yourdomain.com/`

Restart if needed:
```bash
docker-compose restart
```

### Cannot access via domain

1. Check DNS: `nslookup yourdomain.com`
2. Check Security Groups (ports 80, 443)
3. Check nginx: `sudo systemctl status nginx`
4. Check n8n: `docker ps`

### SSL certificate errors

```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

## Maintenance

### Regular Tasks

**Weekly:**
- Check disk space
- Review logs for errors

**Monthly:**
- Update system packages
- Clean Docker: `docker system prune -a`
- Verify backups

**Quarterly:**
- Update n8n to latest version
- Review security configurations
- Rotate credentials

### Automatic Tasks

- SSL certificates renew automatically every 90 days
- Backups can be automated via cron (see setup script)

## Support

- **n8n Documentation:** https://docs.n8n.io
- **n8n Community:** https://community.n8n.io
- **GitHub Issues:** https://github.com/n8n-io/n8n/issues
- **This Project Issues:** [Create an issue](https://github.com/yourusername/n8n-webhook-domains/issues)

## Resources

- [n8n Official Site](https://n8n.io)
- [nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Docker Documentation](https://docs.docker.com/)

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is provided as-is for educational and production use.

## Acknowledgments

- [n8n.io](https://n8n.io) - Workflow automation platform
- [Let's Encrypt](https://letsencrypt.org) - Free SSL certificates
- [nginx](https://nginx.org) - High-performance web server

---

## Quick Reference

### Essential Commands

```bash
# Start n8n
cd ~/n8n-production && docker-compose up -d

# Stop n8n
cd ~/n8n-production && docker-compose down

# View logs
docker-compose logs -f

# Restart n8n
docker-compose restart

# Update n8n
docker-compose pull && docker-compose up -d

# Reload nginx
sudo systemctl reload nginx

# Check SSL
sudo certbot certificates

# Backup
docker run --rm -v n8n-production_n8n_data:/data -v ~/n8n-backups:/backup ubuntu tar czf /backup/n8n-backup-$(date +%Y%m%d_%H%M%S).tar.gz /data
```

### Important Files

- Credentials: `~/n8n-production/CREDENTIALS.txt`
- Docker config: `~/n8n-production/docker-compose.yml`
- nginx config: `/etc/nginx/sites-available/n8n`
- SSL certs: `/etc/letsencrypt/live/yourdomain.com/`

---

**Ready to get started?** Go to [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions!

**Questions?** Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) or create an issue.
