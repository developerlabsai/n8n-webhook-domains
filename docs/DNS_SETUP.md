# DNS Setup Guide for n8n

## Overview
To use a custom domain with your n8n installation, you need to configure DNS records that point your domain to your EC2 instance's public IP address.

## Prerequisites
- Domain name registered (from any registrar: Namecheap, GoDaddy, Google Domains, etc.)
- EC2 instance with a public IP address (preferably Elastic IP)
- Access to your domain's DNS management panel

## Step 1: Get Your EC2 Public IP

### Option A: AWS Console
1. Go to EC2 → Instances
2. Select your n8n instance
3. Find "Public IPv4 address" in the details

### Option B: From EC2 Instance
```bash
# SSH into your instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Get public IP
curl ifconfig.me
```

### Option C: AWS CLI
```bash
aws ec2 describe-instances \
  --instance-ids i-xxxxxxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

**Important:** Note this IP address. Example: `54.123.45.67`

## Step 2: Recommended - Allocate Elastic IP

Regular public IPs change when you stop/start your instance. Use an Elastic IP for a permanent address.

### Allocate Elastic IP

**AWS Console:**
1. Go to EC2 → Elastic IPs
2. Click "Allocate Elastic IP address"
3. Click "Allocate"
4. Select the new IP → Actions → Associate Elastic IP address
5. Choose your n8n instance
6. Click "Associate"

**AWS CLI:**
```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Note the AllocationId from the output
# Associate with your instance
aws ec2 associate-address \
  --instance-id i-xxxxxxxxx \
  --allocation-id eipalloc-xxxxxxxxx
```

**Cost:** Free while attached to a running instance. $0.005/hour if not attached.

## Step 3: Configure DNS Records

### Common Domain Registrars

#### Namecheap

1. Log in to Namecheap
2. Go to "Domain List" → Click "Manage" next to your domain
3. Click "Advanced DNS"
4. Add/Edit the following records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | @ | Your.EC2.IP | 300 |
| A Record | www | Your.EC2.IP | 300 |

5. Delete any existing A records for @ and www
6. Click "Save Changes"

#### GoDaddy

1. Log in to GoDaddy
2. Go to "My Products" → Click "DNS" next to your domain
3. Add/Edit these records:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | Your.EC2.IP | 600 seconds |
| A | www | Your.EC2.IP | 600 seconds |

4. Delete any default A records
5. Click "Save"

#### Google Domains

1. Log in to Google Domains
2. Click "Manage" next to your domain
3. Click "DNS" in the left menu
4. Scroll to "Custom resource records"
5. Add:

| Name | Type | TTL | Data |
|------|------|-----|------|
| @ | A | 5 minutes | Your.EC2.IP |
| www | A | 5 minutes | Your.EC2.IP |

6. Click "Add"

#### Cloudflare (Advanced)

1. Add your domain to Cloudflare (if not already)
2. Update your domain's nameservers to Cloudflare's
3. In Cloudflare Dashboard → DNS
4. Add records:

| Type | Name | Content | Proxy Status | TTL |
|------|------|---------|--------------|-----|
| A | @ | Your.EC2.IP | Proxied (orange) | Auto |
| A | www | Your.EC2.IP | Proxied (orange) | Auto |

**Benefits:** Free SSL, DDoS protection, CDN

**Note:** If using Cloudflare proxy, set SSL/TLS mode to "Full (strict)"

#### AWS Route 53

1. Go to Route 53 → Hosted zones
2. Click "Create hosted zone"
3. Enter your domain name
4. Click "Create hosted zone"
5. Create record:

```bash
# Or use CLI
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "yourdomain.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "YOUR.EC2.IP"}]
      }
    }]
  }'
```

6. Update your domain registrar to use Route 53 nameservers

### Generic Instructions (Any Registrar)

1. Log into your domain registrar
2. Find "DNS Settings", "DNS Management", or "Nameserver Settings"
3. Look for "A Record" or "Host Records" section
4. Create/Edit these records:

**Record 1 (root domain):**
- Type: A
- Name/Host: @ (or leave blank, or use your domain)
- Value/Points to: Your EC2 IP (e.g., 54.123.45.67)
- TTL: 300 (or 5 minutes)

**Record 2 (www subdomain):**
- Type: A
- Name/Host: www
- Value/Points to: Your EC2 IP (e.g., 54.123.45.67)
- TTL: 300 (or 5 minutes)

5. Save changes
6. Delete any conflicting A records

## Step 4: Verify DNS Configuration

DNS changes can take 5 minutes to 48 hours to propagate. Typically, it's 5-10 minutes with a low TTL.

### Check DNS Propagation

**Method 1: nslookup (Local)**
```bash
nslookup yourdomain.com
```

Expected output:
```
Server:     8.8.8.8
Address:    8.8.8.8#53

Non-authoritative answer:
Name:   yourdomain.com
Address: 54.123.45.67
```

**Method 2: dig (More detailed)**
```bash
dig yourdomain.com +short
```

Expected output:
```
54.123.45.67
```

**Method 3: Online Tools**
- https://www.whatsmydns.net
- https://dnschecker.org
- Enter your domain and check A record

**Method 4: Host Command**
```bash
host yourdomain.com
```

### Test Both Records

```bash
# Test root domain
nslookup yourdomain.com

# Test www subdomain
nslookup www.yourdomain.com

# Both should return your EC2 IP
```

## Step 5: Verify Connectivity

Once DNS is propagated:

```bash
# Test HTTP connection (before SSL)
curl -I http://yourdomain.com

# Test HTTPS (after SSL setup)
curl -I https://yourdomain.com

# Ping test
ping yourdomain.com
```

## Common DNS Record Types

| Type | Purpose | Example |
|------|---------|---------|
| A | Points domain to IPv4 address | yourdomain.com → 54.123.45.67 |
| AAAA | Points domain to IPv6 address | yourdomain.com → 2001:0db8::1 |
| CNAME | Alias one domain to another | www → yourdomain.com |
| MX | Mail server records | For email |
| TXT | Text records | For verification, SPF, etc. |

## Advanced Configurations

### Using CNAME for www

Instead of a second A record, you can use CNAME:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | @ | 54.123.45.67 | 300 |
| CNAME | www | yourdomain.com | 300 |

### Subdomain for n8n

If you want to use a subdomain (e.g., n8n.yourdomain.com):

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | n8n | 54.123.45.67 | 300 |

Update nginx and docker-compose.yml to use `n8n.yourdomain.com` instead of `yourdomain.com`.

### Multiple Subdomains

For dev/staging/production:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | n8n | 54.123.45.67 | 300 |
| A | n8n-staging | 54.123.45.68 | 300 |
| A | n8n-dev | 54.123.45.69 | 300 |

### Wildcard DNS

For dynamic subdomains:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | * | 54.123.45.67 | 300 |

**Note:** *.yourdomain.com will match any subdomain.

## Troubleshooting

### DNS Not Propagating

**Issue:** DNS lookup still returns old IP or no result.

**Solutions:**
1. Wait longer (can take up to 48 hours)
2. Clear local DNS cache:
   ```bash
   # macOS
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

   # Windows
   ipconfig /flushdns

   # Linux
   sudo systemd-resolve --flush-caches
   ```
3. Use different DNS server for testing:
   ```bash
   nslookup yourdomain.com 8.8.8.8  # Google DNS
   nslookup yourdomain.com 1.1.1.1  # Cloudflare DNS
   ```
4. Check registrar DNS management panel for errors
5. Verify nameservers are correct

### Wrong IP Returned

**Issue:** DNS returns incorrect IP address.

**Solutions:**
1. Check for conflicting A records
2. Verify you updated the correct domain
3. Check if domain uses custom nameservers
4. Wait for TTL to expire on old record

### Can't Access Site After DNS Update

**Issue:** DNS resolves correctly but site doesn't load.

**Solutions:**
1. Verify EC2 instance is running
2. Check security group allows ports 80 and 443
3. Ensure nginx is running: `sudo systemctl status nginx`
4. Test direct IP access: `curl http://YOUR_EC2_IP`
5. Check nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Nameserver Issues

**Issue:** Domain not using correct nameservers.

**Check current nameservers:**
```bash
dig NS yourdomain.com
```

**Update nameservers at registrar** to match DNS provider (e.g., Route 53, Cloudflare).

## Security Considerations

### DNSSEC (Optional but Recommended)

Enable DNSSEC at your registrar for additional security:

1. Check if registrar supports DNSSEC
2. Enable in DNS settings
3. Add DS records if using Route 53 or Cloudflare

### CAA Records (Optional)

Restrict which Certificate Authorities can issue SSL certificates:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| CAA | @ | 0 issue "letsencrypt.org" | 3600 |

```bash
# Add via AWS CLI
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "yourdomain.com",
        "Type": "CAA",
        "TTL": 3600,
        "ResourceRecords": [{"Value": "0 issue \"letsencrypt.org\""}]
      }
    }]
  }'
```

## DNS Migration Checklist

Moving from old server to new n8n server:

- [ ] Note current DNS records (backup)
- [ ] Reduce TTL to 300 seconds (24-48 hours before migration)
- [ ] Set up new EC2 instance and verify it works via IP
- [ ] Update A record to new EC2 IP
- [ ] Monitor old server logs for traffic drop
- [ ] Verify new server receives traffic
- [ ] Wait 24-48 hours before decommissioning old server
- [ ] Increase TTL back to 3600+ seconds

## DNS Providers Comparison

| Provider | Ease of Use | Features | Cost | TTL Control |
|----------|-------------|----------|------|-------------|
| Namecheap | Easy | Basic | Free with domain | Yes (300s min) |
| GoDaddy | Easy | Basic | Free with domain | Limited |
| Cloudflare | Medium | Advanced (proxy, SSL, DDoS) | Free tier available | Auto |
| Route 53 | Advanced | AWS integration | $0.50/hosted zone/month | Yes (60s min) |
| Google Domains | Easy | Clean interface | Free with domain | Yes |

## Quick Reference

### Essential DNS Records for n8n

```
# Minimum configuration
A     @       54.123.45.67    300
A     www     54.123.45.67    300

# Alternative with CNAME
A     @       54.123.45.67    300
CNAME www     yourdomain.com  300

# With subdomain
A     n8n     54.123.45.67    300
```

### Verification Commands

```bash
# Check A record
dig yourdomain.com A +short

# Check with specific DNS server
dig @8.8.8.8 yourdomain.com A +short

# Full DNS info
dig yourdomain.com ANY

# Check propagation globally
curl https://dns.google/resolve?name=yourdomain.com&type=A

# Trace DNS query
dig yourdomain.com +trace
```

---

**Next Steps:** After DNS is configured and verified, proceed to [SETUP_GUIDE.md](../SETUP_GUIDE.md) to continue with nginx and SSL setup.
