# n8n Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: Webhooks Still Show `0.0.0.0:5678`

**Symptoms:**
- Webhook URLs display as `http://0.0.0.0:5678/webhook-test/...`
- External services cannot reach webhooks

**Solutions:**

1. **Check environment variables:**
   ```bash
   cd ~/n8n-production
   docker-compose exec n8n env | grep -E "(WEBHOOK|N8N_HOST|N8N_PROTOCOL)"
   ```

   Should show:
   ```
   WEBHOOK_URL=https://yourdomain.com/
   N8N_HOST=yourdomain.com
   N8N_PROTOCOL=https
   ```

2. **Verify docker-compose.yml configuration:**
   ```bash
   grep -A 20 "environment:" docker-compose.yml
   ```

3. **Restart n8n after configuration changes:**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

4. **Clear browser cache and refresh n8n:**
   - Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)

5. **Check n8n logs for errors:**
   ```bash
   docker-compose logs -f | grep -i webhook
   ```

---

### Issue 2: Cannot Access n8n via Domain

**Symptoms:**
- Browser shows "This site can't be reached"
- Connection timeout or refused

**Diagnostic Steps:**

1. **Check DNS resolution:**
   ```bash
   nslookup yourdomain.com
   dig yourdomain.com +short
   ```
   Should return your EC2 public IP.

2. **Verify EC2 Security Group:**
   - Port 80 (HTTP): 0.0.0.0/0
   - Port 443 (HTTPS): 0.0.0.0/0
   - Port 22 (SSH): Your IP only

3. **Check nginx status:**
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

4. **Verify nginx is listening:**
   ```bash
   sudo netstat -tlnp | grep nginx
   ```
   Should show ports 80 and 443.

5. **Check n8n container:**
   ```bash
   docker ps
   docker-compose logs --tail=50
   ```

6. **Test from server itself:**
   ```bash
   curl -I http://localhost
   curl -I https://yourdomain.com
   ```

7. **Check nginx error logs:**
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

**Solutions:**

- If DNS not resolving: Wait for propagation or check DNS configuration
- If nginx not running: `sudo systemctl start nginx`
- If ports not open: Check AWS Security Groups
- If SSL errors: Verify certificates exist

---

### Issue 3: SSL Certificate Errors

**Symptoms:**
- "Your connection is not private" in browser
- Certificate errors in logs
- Let's Encrypt certificate failed

**Solutions:**

1. **Check certificate status:**
   ```bash
   sudo certbot certificates
   ```

2. **Verify certificate files exist:**
   ```bash
   sudo ls -la /etc/letsencrypt/live/yourdomain.com/
   ```

3. **Test certificate renewal:**
   ```bash
   sudo certbot renew --dry-run
   ```

4. **Common certificate issues:**

   a) **DNS not pointing to server:**
   ```bash
   dig yourdomain.com +short
   curl ifconfig.me
   # These should match
   ```

   b) **Port 80 blocked:**
   ```bash
   sudo netstat -tlnp | grep :80
   # Check AWS Security Group allows port 80
   ```

   c) **nginx configuration error:**
   ```bash
   sudo nginx -t
   ```

5. **Manually obtain certificate:**
   ```bash
   sudo certbot certonly --webroot \
     -w /var/www/certbot \
     -d yourdomain.com \
     -d www.yourdomain.com \
     --force-renewal
   ```

6. **If certificate expired:**
   ```bash
   sudo certbot renew --force-renewal
   sudo systemctl reload nginx
   ```

---

### Issue 4: n8n Container Won't Start

**Symptoms:**
- `docker ps` doesn't show n8n
- Container exits immediately
- Error in logs

**Diagnostic Steps:**

1. **Check container status:**
   ```bash
   cd ~/n8n-production
   docker-compose ps
   ```

2. **View logs:**
   ```bash
   docker-compose logs
   ```

3. **Try starting in foreground:**
   ```bash
   docker-compose up
   # Watch for errors
   ```

**Common Causes & Solutions:**

a) **Port 5678 already in use:**
```bash
sudo netstat -tlnp | grep 5678
# Kill the process using the port
sudo kill -9 <PID>
```

b) **Volume permission issues:**
```bash
docker-compose down
docker volume ls
docker volume rm n8n-production_n8n_data
docker-compose up -d
```

c) **Invalid environment variables:**
```bash
# Check for syntax errors in docker-compose.yml
docker-compose config
```

d) **Out of disk space:**
```bash
df -h
docker system prune -a
```

---

### Issue 5: Workflow Execution Fails

**Symptoms:**
- Workflows stop unexpectedly
- Timeout errors
- "Execution timed out" messages

**Solutions:**

1. **Check timeout settings:**
   Edit docker-compose.yml:
   ```yaml
   environment:
     - EXECUTIONS_TIMEOUT=3600  # 1 hour
     - EXECUTIONS_TIMEOUT_MAX=7200  # 2 hours
   ```

2. **Increase nginx timeout:**
   Edit `/etc/nginx/sites-available/n8n`:
   ```nginx
   proxy_read_timeout 600s;  # 10 minutes
   proxy_connect_timeout 600s;
   ```

3. **Check container resources:**
   ```bash
   docker stats n8n
   ```

4. **Increase Docker memory limit:**
   Edit docker-compose.yml:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 4G  # Increase if needed
   ```

5. **Check n8n logs:**
   ```bash
   docker-compose logs -f | grep -i error
   ```

---

### Issue 6: Cannot SSH to EC2 Instance

**Symptoms:**
- Connection timeout
- Permission denied
- Connection refused

**Solutions:**

1. **Verify instance is running:**
   - Check AWS Console → EC2 → Instances
   - Instance state should be "running"

2. **Check Security Group:**
   - Port 22 must be open from your IP
   - Get your IP: `curl ifconfig.me`

3. **Verify SSH key permissions:**
   ```bash
   chmod 400 /path/to/your-key.pem
   ```

4. **Test with verbose mode:**
   ```bash
   ssh -vvv -i your-key.pem ubuntu@your-ec2-ip
   ```

5. **Check if using correct username:**
   - Ubuntu AMI: `ubuntu`
   - Amazon Linux 2: `ec2-user`
   - Red Hat: `ec2-user`

6. **Use EC2 Instance Connect (alternative):**
   - AWS Console → EC2 → Select Instance → Connect → EC2 Instance Connect

---

### Issue 7: High CPU/Memory Usage

**Symptoms:**
- Slow response
- Container crashes
- Out of memory errors

**Diagnostic Steps:**

1. **Check resource usage:**
   ```bash
   docker stats n8n
   top
   htop
   ```

2. **Check disk usage:**
   ```bash
   df -h
   du -sh ~/n8n-production/*
   docker system df
   ```

**Solutions:**

1. **Optimize workflow executions:**
   - Reduce concurrency in docker-compose.yml:
   ```yaml
   environment:
     - N8N_CONCURRENCY_PRODUCTION_LIMIT=5
   ```

2. **Clean up Docker:**
   ```bash
   docker system prune -a
   docker volume prune
   ```

3. **Clean up old executions:**
   - In n8n: Settings → Executions → Set retention limit

4. **Upgrade EC2 instance type:**
   - Stop instance
   - Actions → Instance Settings → Change Instance Type
   - Choose larger instance (e.g., t3.medium → t3.large)

5. **Monitor with CloudWatch:**
   - Set up alarms for high CPU/memory usage

---

### Issue 8: Webhook Receives 502 Bad Gateway

**Symptoms:**
- External services get 502 error when sending webhooks
- nginx returns "Bad Gateway"

**Solutions:**

1. **Check if n8n is running:**
   ```bash
   docker ps | grep n8n
   ```

2. **Verify nginx can reach n8n:**
   ```bash
   curl http://localhost:5678
   ```

3. **Check nginx error logs:**
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

4. **Verify proxy configuration:**
   ```bash
   grep -A 10 "location /" /etc/nginx/sites-available/n8n
   ```

5. **Restart both services:**
   ```bash
   docker-compose restart
   sudo systemctl restart nginx
   ```

6. **Check for port conflicts:**
   ```bash
   sudo netstat -tlnp | grep 5678
   ```

---

### Issue 9: Workflows Not Saving

**Symptoms:**
- Changes disappear after page refresh
- "Could not save workflow" error

**Solutions:**

1. **Check volume mount:**
   ```bash
   docker volume inspect n8n-production_n8n_data
   ```

2. **Check permissions:**
   ```bash
   docker-compose exec n8n ls -la /home/node/.n8n
   ```

3. **Check disk space:**
   ```bash
   df -h
   ```

4. **Restart container:**
   ```bash
   docker-compose restart
   ```

5. **Check for database corruption:**
   ```bash
   docker-compose exec n8n ls -lh /home/node/.n8n/database.sqlite
   ```

---

### Issue 10: Automatic SSL Renewal Failing

**Symptoms:**
- Certificate expired
- Renewal cron job not working
- certbot errors in logs

**Solutions:**

1. **Check crontab:**
   ```bash
   sudo crontab -l
   ```

2. **Manually renew:**
   ```bash
   sudo certbot renew --force-renewal
   sudo systemctl reload nginx
   ```

3. **Test renewal:**
   ```bash
   sudo certbot renew --dry-run
   ```

4. **Check certbot logs:**
   ```bash
   sudo tail -f /var/log/letsencrypt/letsencrypt.log
   ```

5. **Verify webroot:**
   ```bash
   ls -la /var/www/certbot/.well-known/acme-challenge/
   ```

6. **Re-setup cron job:**
   ```bash
   (sudo crontab -l 2>/dev/null | grep -v certbot; echo "0 0,12 * * * certbot renew --quiet && systemctl reload nginx") | sudo crontab -
   ```

---

## Diagnostic Commands Reference

### System Health Check

```bash
# Full system check
echo "=== System Status ==="
uptime
df -h
free -h

echo "=== Docker Status ==="
docker ps
docker stats --no-stream

echo "=== nginx Status ==="
sudo systemctl status nginx --no-pager

echo "=== SSL Certificates ==="
sudo certbot certificates

echo "=== n8n Logs (last 20 lines) ==="
cd ~/n8n-production && docker-compose logs --tail=20
```

### Network Diagnostics

```bash
# Check all listening ports
sudo netstat -tlnp

# Check specific service
sudo netstat -tlnp | grep -E "(nginx|5678)"

# Test DNS
nslookup yourdomain.com
dig yourdomain.com +short

# Test HTTPS
curl -I https://yourdomain.com

# Test webhook
curl -X POST https://yourdomain.com/webhook-test/test \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}'
```

### Log Files

```bash
# n8n logs
docker-compose logs -f

# nginx access log
sudo tail -f /var/log/nginx/n8n-access.log

# nginx error log
sudo tail -f /var/log/nginx/n8n-error.log

# System log
sudo tail -f /var/log/syslog  # Ubuntu
sudo tail -f /var/log/messages  # Amazon Linux

# SSL renewal log
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

---

## Quick Fixes

### Complete Service Restart

```bash
# Restart everything
cd ~/n8n-production
docker-compose down
sudo systemctl restart nginx
docker-compose up -d

# Wait and check
sleep 5
docker ps
sudo systemctl status nginx
```

### Reset n8n (Destructive - Creates Backup First)

```bash
# Backup data
docker run --rm \
  -v n8n-production_n8n_data:/data \
  -v ~/n8n-backups:/backup \
  ubuntu tar czf /backup/n8n-backup-$(date +%Y%m%d_%H%M%S).tar.gz /data

# Remove and recreate
cd ~/n8n-production
docker-compose down -v
docker-compose up -d
```

### Force SSL Certificate Renewal

```bash
sudo certbot delete --cert-name yourdomain.com
sudo certbot certonly --webroot \
  -w /var/www/certbot \
  -d yourdomain.com \
  -d www.yourdomain.com \
  --force-renewal
sudo systemctl reload nginx
```

---

## Getting Help

If none of these solutions work:

1. **Check n8n Community:**
   - https://community.n8n.io

2. **GitHub Issues:**
   - https://github.com/n8n-io/n8n/issues

3. **Collect diagnostic information:**
   ```bash
   # Create diagnostic report
   cat > diagnostic-report.txt <<EOF
   Date: $(date)

   System Info:
   $(uname -a)

   Docker Version:
   $(docker --version)

   Docker Compose Version:
   $(docker-compose --version)

   n8n Status:
   $(docker ps | grep n8n)

   nginx Status:
   $(sudo systemctl status nginx --no-pager)

   Recent n8n Logs:
   $(cd ~/n8n-production && docker-compose logs --tail=50)

   nginx Error Log:
   $(sudo tail -50 /var/log/nginx/error.log)
   EOF
   ```

4. **Check this project's documentation:**
   - [SETUP_GUIDE.md](../SETUP_GUIDE.md)
   - [AWS_SECURITY_GROUPS.md](AWS_SECURITY_GROUPS.md)
   - [DNS_SETUP.md](DNS_SETUP.md)

---

## Prevention

### Regular Maintenance Checklist

**Weekly:**
- [ ] Check disk space: `df -h`
- [ ] Review n8n logs for errors
- [ ] Verify backups are being created

**Monthly:**
- [ ] Update system packages: `sudo apt update && sudo apt upgrade`
- [ ] Clean Docker: `docker system prune -a`
- [ ] Test SSL renewal: `sudo certbot renew --dry-run`
- [ ] Review workflow execution history

**Quarterly:**
- [ ] Update n8n: `cd ~/n8n-production && docker-compose pull && docker-compose up -d`
- [ ] Review and rotate credentials
- [ ] Check AWS costs and optimize
- [ ] Review Security Group rules

---

**Remember:** Always create a backup before making major changes!

```bash
# Quick backup command
docker run --rm \
  -v n8n-production_n8n_data:/data \
  -v ~/n8n-backups:/backup \
  ubuntu tar czf /backup/n8n-backup-$(date +%Y%m%d_%H%M%S).tar.gz /data
```
