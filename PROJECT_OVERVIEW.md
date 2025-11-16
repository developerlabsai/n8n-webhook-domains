# n8n Webhook and Domain Configuration Project

## Project Purpose
This project provides complete documentation and configuration files to fix your self-hosted n8n server on AWS, resolving the `0.0.0.0:5678` webhook URL issue and setting up production-ready infrastructure with proper domain configuration and SSL/TLS encryption.

## Problem Statement
Your n8n instance is generating webhook URLs like:
```
http://0.0.0.0:5678/webhook-test/54f98dcd-6c03-480f-bdb9-b2a551010f5a
```

This internal binding address won't work for external services. The solution involves:
1. Configuring a proper domain name
2. Setting up nginx as a reverse proxy
3. Enabling SSL/TLS with Let's Encrypt
4. Configuring n8n's WEBHOOK_URL environment variable

## Architecture Overview

```
Internet
    ↓
AWS Security Group (Port 80/443 open)
    ↓
EC2 Instance (Your Domain: yourdomain.com)
    ↓
nginx Reverse Proxy (Port 80/443)
    ↓
n8n Container (Internal: localhost:5678)
```

## Target Webhook URL Format
After setup, your webhooks will look like:
```
https://yourdomain.com/webhook-test/54f98dcd-6c03-480f-bdb9-b2a551010f5a
```

## Prerequisites
- AWS EC2 instance running (Ubuntu/Amazon Linux recommended)
- Domain name registered (e.g., from Route53, Namecheap, GoDaddy)
- SSH access to your EC2 instance
- Basic familiarity with Docker and Linux commands

## Project Structure
```
n8n-webhook-and-domains/
├── PROJECT_OVERVIEW.md          # This file
├── SETUP_GUIDE.md              # Step-by-step setup instructions
├── MCP_SERVERS.md              # MCP server recommendations
├── docker-compose.yml          # n8n Docker configuration
├── nginx/
│   ├── nginx.conf              # Main nginx configuration
│   └── sites-available/
│       └── n8n.conf            # n8n-specific nginx config
├── scripts/
│   ├── setup.sh                # Initial setup script
│   ├── ssl-setup.sh            # SSL certificate setup
│   └── deploy.sh               # Deployment script
├── docs/
│   ├── AWS_SECURITY_GROUPS.md  # AWS configuration guide
│   ├── DNS_SETUP.md            # DNS configuration
│   └── TROUBLESHOOTING.md      # Common issues and fixes
└── .env.example                # Environment variables template
```

## Quick Start
1. Clone/download this project to your local machine
2. Review the [SETUP_GUIDE.md](SETUP_GUIDE.md)
3. Configure your domain's DNS to point to your EC2 instance
4. SSH into your EC2 instance
5. Run the setup scripts
6. Configure n8n with your domain

## Key Components

### 1. nginx Reverse Proxy
- Handles SSL/TLS termination
- Forwards requests to n8n container
- Manages HTTP to HTTPS redirects
- Provides security headers

### 2. Docker Compose
- Runs n8n in a container
- Manages persistent data volumes
- Configures environment variables
- Easy start/stop/restart

### 3. Let's Encrypt SSL
- Free SSL/TLS certificates
- Automatic renewal with certbot
- Industry-standard encryption

### 4. AWS Infrastructure
- EC2 instance hosting
- Security group configuration
- Optional: Route53 for DNS
- Optional: Elastic IP for static addressing

## Security Considerations
- SSL/TLS encryption for all traffic
- Firewall rules limiting access
- Regular security updates
- Strong authentication for n8n
- Environment variable protection

## Cost Estimate (Monthly)
- EC2 t3.small instance: ~$15-20
- Domain name: ~$1-3/month (if annual)
- Let's Encrypt SSL: Free
- Data transfer: Varies by usage
- **Estimated Total: $16-25/month**

## Next Steps
1. Read [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions
2. Review [MCP_SERVERS.md](MCP_SERVERS.md) for recommended MCP servers
3. Check [AWS_SECURITY_GROUPS.md](docs/AWS_SECURITY_GROUPS.md) for AWS configuration
4. Follow the setup process step-by-step

## Support and Resources
- n8n Documentation: https://docs.n8n.io
- n8n Community: https://community.n8n.io
- nginx Documentation: https://nginx.org/en/docs/
- Let's Encrypt: https://letsencrypt.org/docs/
- AWS EC2 Documentation: https://docs.aws.amazon.com/ec2/

## Maintenance
- SSL certificates auto-renew via certbot
- Keep n8n updated: `docker-compose pull && docker-compose up -d`
- Monitor disk space for n8n data
- Regular backups of n8n data volume
- Keep system packages updated

## License
This configuration project is provided as-is for educational and production use.
