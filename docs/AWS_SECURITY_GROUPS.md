# AWS Security Group Configuration for n8n

## Overview
Security groups act as virtual firewalls for your EC2 instance. Proper configuration is critical for both security and functionality of your n8n installation.

## Required Ports

### Inbound Rules

| Port | Protocol | Source | Purpose | Priority |
|------|----------|--------|---------|----------|
| 22 | TCP | Your IP/32 | SSH access | HIGH |
| 80 | TCP | 0.0.0.0/0 | HTTP (redirects to HTTPS) | HIGH |
| 443 | TCP | 0.0.0.0/0 | HTTPS (n8n access) | HIGH |

### Outbound Rules
- **All traffic** to **0.0.0.0/0** (default - allows n8n to connect to external services)

## Step-by-Step Configuration

### Option 1: AWS Console (Web Interface)

1. **Navigate to Security Groups:**
   - Log in to AWS Console
   - Go to EC2 Dashboard
   - Click "Security Groups" in the left sidebar
   - Find your instance's security group (check instance details if unsure)

2. **Edit Inbound Rules:**
   - Click on your security group
   - Click "Edit inbound rules"
   - Click "Add rule" for each of the following:

3. **Add SSH Rule:**
   ```
   Type: SSH
   Protocol: TCP
   Port Range: 22
   Source: My IP (or specify your static IP)
   Description: SSH access from my location
   ```

4. **Add HTTP Rule:**
   ```
   Type: HTTP
   Protocol: TCP
   Port Range: 80
   Source: Anywhere-IPv4 (0.0.0.0/0)
   Description: HTTP access for Let's Encrypt and redirects
   ```

5. **Add HTTPS Rule:**
   ```
   Type: HTTPS
   Protocol: TCP
   Port Range: 443
   Source: Anywhere-IPv4 (0.0.0.0/0)
   Description: HTTPS access for n8n
   ```

6. **Remove Direct n8n Access (if exists):**
   - If you see any rules for port 5678, **DELETE THEM**
   - Port 5678 should NEVER be exposed to the internet
   - nginx will handle all external access

7. **Save Changes:**
   - Click "Save rules"
   - Wait a few seconds for changes to apply

### Option 2: AWS CLI

If you prefer command-line configuration:

```bash
# Set your variables
SECURITY_GROUP_ID="sg-xxxxxxxxx"  # Your security group ID
YOUR_IP="1.2.3.4"  # Your current IP address

# Add SSH rule (restricted to your IP)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 22 \
  --cidr $YOUR_IP/32 \
  --description "SSH access from my location"

# Add HTTP rule (for Let's Encrypt and redirects)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --description "HTTP access for Let's Encrypt"

# Add HTTPS rule (for n8n access)
aws ec2 authorize-security-group-ingress \
  --group-id $SECURITY_GROUP_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0 \
  --description "HTTPS access for n8n"
```

### Option 3: Using MCP AWS Server

If you have the AWS MCP server configured:

Ask Claude:
```
"Configure my EC2 security group for n8n with:
- SSH from my IP only
- HTTP from anywhere (port 80)
- HTTPS from anywhere (port 443)
- Remove any rules for port 5678"
```

## Find Your Security Group ID

### Method 1: EC2 Console
1. Go to EC2 → Instances
2. Click on your instance
3. Look at the "Security" tab
4. Note the "Security groups" value (e.g., sg-0123456789abcdef)

### Method 2: AWS CLI
```bash
# List all instances with their security groups
aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,SecurityGroups[*].GroupId]' \
  --output table
```

### Method 3: From EC2 Instance
```bash
# SSH into your instance and run:
curl http://169.254.169.254/latest/meta-data/security-groups
```

## Get Your Current IP Address

```bash
# From your local machine:
curl ifconfig.me

# Or visit:
# https://whatismyipaddress.com
```

## Verify Security Group Configuration

### AWS Console
1. Go to EC2 → Security Groups
2. Select your security group
3. Check "Inbound rules" tab
4. Verify all three rules are present:
   - Port 22 (SSH) from your IP
   - Port 80 (HTTP) from 0.0.0.0/0
   - Port 443 (HTTPS) from 0.0.0.0/0

### AWS CLI
```bash
# View all inbound rules
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx \
  --query 'SecurityGroups[*].IpPermissions'
```

### Test Connectivity
```bash
# Test SSH (should work)
ssh -i your-key.pem ubuntu@your-ec2-ip

# Test HTTP (after nginx is installed)
curl -I http://your-domain.com

# Test HTTPS (after SSL is configured)
curl -I https://your-domain.com

# Test n8n port directly (should FAIL/timeout)
curl -I http://your-ec2-ip:5678
# This should NOT work - that's correct!
```

## Security Best Practices

### 1. Restrict SSH Access

**DON'T:**
```
Port 22 from 0.0.0.0/0  ❌ (allows SSH from anywhere)
```

**DO:**
```
Port 22 from YOUR_IP/32  ✅ (allows SSH only from your IP)
```

If your IP changes frequently, consider:
- Using a VPN with a static IP
- AWS Systems Manager Session Manager (no port 22 needed)
- Bastion host with key-based authentication

### 2. Never Expose n8n Directly

**DON'T:**
```
Port 5678 from 0.0.0.0/0  ❌ (exposes n8n directly)
```

**DO:**
```
Only expose ports 80 and 443  ✅ (nginx handles all access)
```

### 3. Use Elastic IP (Optional but Recommended)

Benefits:
- Static IP address (doesn't change on instance restart)
- Can be moved between instances
- Free if attached to a running instance

```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc

# Associate with instance
aws ec2 associate-address \
  --instance-id i-xxxxxxxxx \
  --allocation-id eipalloc-xxxxxxxxx
```

### 4. Enable VPC Flow Logs (Optional)

Monitor all traffic to/from your instance:

```bash
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxxxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs
```

### 5. Regular Security Audits

Create a monthly checklist:
- [ ] Review security group rules
- [ ] Check for unused rules
- [ ] Verify SSH is restricted to known IPs
- [ ] Review VPC flow logs for suspicious activity
- [ ] Update system packages
- [ ] Rotate SSH keys

## Common Issues and Solutions

### Issue 1: Can't SSH to Instance

**Symptoms:**
```bash
ssh: connect to host x.x.x.x port 22: Connection timed out
```

**Solutions:**
1. Check security group allows port 22 from your IP
2. Verify your public IP hasn't changed: `curl ifconfig.me`
3. Check EC2 instance is running
4. Verify you're using the correct key file
5. Check VPC/subnet route tables

### Issue 2: Can't Access n8n via Domain

**Symptoms:**
- Browser shows "connection refused" or "timeout"
- `curl https://yourdomain.com` fails

**Solutions:**
1. Verify security group allows ports 80 and 443 from 0.0.0.0/0
2. Check nginx is running: `sudo systemctl status nginx`
3. Verify DNS points to correct IP: `nslookup yourdomain.com`
4. Check n8n container is running: `docker ps`
5. Review nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Issue 3: Let's Encrypt Fails

**Symptoms:**
```
Certbot failed to authenticate some domains
```

**Solutions:**
1. Ensure port 80 is open in security group
2. Verify DNS is correctly configured
3. Check nginx is serving on port 80
4. Verify firewall isn't blocking port 80:
   ```bash
   sudo ufw status  # Ubuntu
   sudo iptables -L  # General
   ```

### Issue 4: Webhooks Not Reachable

**Symptoms:**
- External services can't send webhooks to n8n
- Webhook test fails

**Solutions:**
1. Verify port 443 is open in security group
2. Check nginx is proxying correctly to n8n
3. Verify WEBHOOK_URL in docker-compose.yml is correct
4. Test webhook URL manually:
   ```bash
   curl -X POST https://yourdomain.com/webhook-test/xxx \
     -H "Content-Type: application/json" \
     -d '{"test":"data"}'
   ```

## Advanced: Multiple Environments

If running dev/staging/production environments:

```bash
# Create separate security groups
aws ec2 create-security-group \
  --group-name n8n-production \
  --description "n8n production environment" \
  --vpc-id vpc-xxxxxxxxx

aws ec2 create-security-group \
  --group-name n8n-staging \
  --description "n8n staging environment" \
  --vpc-id vpc-xxxxxxxxx

# Different rules for each environment
# Production: Ports 80, 443 open to all
# Staging: Ports 80, 443 only from office IP
```

## CloudFormation Template (Optional)

For infrastructure-as-code approach:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Security Group for n8n'

Resources:
  N8NSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: n8n-security-group
      GroupDescription: Security group for n8n server
      VpcId: !Ref VpcId
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref SSHLocation
          Description: SSH access
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
          Description: HTTP access
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
          Description: HTTPS access
      Tags:
        - Key: Name
          Value: n8n-security-group

Parameters:
  VpcId:
    Type: AWS::EC2::VPC::Id
    Description: VPC ID
  SSHLocation:
    Type: String
    Description: IP address range for SSH access
    Default: 0.0.0.0/0
```

## Summary

Your final security group configuration should look like:

```
Inbound Rules:
┌──────┬──────────┬──────────────┬─────────────────────┐
│ Port │ Protocol │ Source       │ Description         │
├──────┼──────────┼──────────────┼─────────────────────┤
│ 22   │ TCP      │ YOUR_IP/32   │ SSH access          │
│ 80   │ TCP      │ 0.0.0.0/0    │ HTTP (Let's Encrypt)│
│ 443  │ TCP      │ 0.0.0.0/0    │ HTTPS (n8n)         │
└──────┴──────────┴──────────────┴─────────────────────┘

Outbound Rules:
┌──────┬──────────┬──────────────┬─────────────────────┐
│ Port │ Protocol │ Destination  │ Description         │
├──────┼──────────┼──────────────┼─────────────────────┤
│ All  │ All      │ 0.0.0.0/0    │ Allow all outbound  │
└──────┴──────────┴──────────────┴─────────────────────┘
```

**CRITICAL:** Never expose port 5678 directly to the internet. Always use nginx as a reverse proxy for security and SSL termination.
