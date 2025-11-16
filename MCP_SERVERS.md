# Recommended MCP Servers for n8n AWS Setup

## Overview
Model Context Protocol (MCP) servers provide specialized capabilities to Claude for working with specific tools and services. This document outlines the MCP servers that will make your n8n AWS setup faster and easier.

## Core Recommended MCP Servers

### 1. **AWS MCP Server** (ESSENTIAL)
**Priority: HIGH**

Provides direct interaction with AWS services including EC2, Security Groups, Route53, and more.

**Installation:**
```bash
npm install -g @modelcontextprotocol/server-aws
```

**Configuration for this project only:**
Create or edit `~/Projects/n8n Webhook and Domains/.mcp/settings.json`:

```json
{
  "mcpServers": {
    "aws": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws"],
      "env": {
        "AWS_REGION": "us-east-1",
        "AWS_PROFILE": "default"
      }
    }
  }
}
```

**Benefits:**
- Directly query and modify EC2 security groups
- Check instance status and IP addresses
- Manage Route53 DNS records
- View CloudWatch logs
- No need to constantly switch to AWS Console

**Use Cases for This Project:**
- Automatically configure security group rules
- Verify EC2 instance public IP
- Set up Route53 DNS records (if using Route53)
- Monitor instance health

---

### 2. **SSH/Remote MCP Server** (ESSENTIAL)
**Priority: HIGH**

Enables direct SSH connections to your EC2 instance for command execution.

**Installation:**
```bash
npm install -g @modelcontextprotocol/server-ssh
```

**Configuration for this project only:**
In `~/Projects/n8n Webhook and Domains/.mcp/settings.json`, add:

```json
{
  "mcpServers": {
    "aws": { ... },
    "ssh-ec2": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-ssh"],
      "env": {
        "SSH_HOST": "your-ec2-public-ip-or-domain",
        "SSH_USER": "ubuntu",
        "SSH_KEY_PATH": "/path/to/your-key.pem",
        "SSH_PORT": "22"
      }
    }
  }
}
```

**Benefits:**
- Execute commands directly on EC2 instance
- Check service status (nginx, Docker)
- View logs in real-time
- Deploy configurations without manual SSH

**Use Cases for This Project:**
- Install Docker and Docker Compose
- Configure nginx
- Start/stop n8n container
- View application logs
- Test configurations

---

### 3. **Docker MCP Server** (RECOMMENDED)
**Priority: MEDIUM-HIGH**

Manages Docker containers and Docker Compose applications.

**Installation:**
```bash
npm install -g @modelcontextprotocol/server-docker
```

**Configuration:**
```json
{
  "mcpServers": {
    "docker": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "ssh://ubuntu@your-ec2-ip"
      }
    }
  }
}
```

**Benefits:**
- View running containers
- Check container logs
- Restart services
- Monitor resource usage

**Use Cases for This Project:**
- Deploy n8n with docker-compose
- Check n8n container status
- View n8n logs
- Restart n8n after configuration changes

---

### 4. **File System MCP Server** (RECOMMENDED)
**Priority: MEDIUM**

Provides file system operations for reading and writing configuration files.

**Installation:**
```bash
npm install -g @modelcontextprotocol/server-filesystem
```

**Configuration:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/clancehoskin/Projects/n8n Webhook and Domains"
      ]
    }
  }
}
```

**Benefits:**
- Read and write nginx configs locally
- Manage docker-compose.yml
- Create scripts and documentation
- Organize project files

**Use Cases for This Project:**
- Create docker-compose.yml
- Write nginx configuration files
- Generate deployment scripts
- Store backup configurations

---

### 5. **Web Fetch MCP Server** (OPTIONAL)
**Priority: LOW-MEDIUM**

Fetches documentation and checks domain DNS status.

**Installation:**
```bash
npm install -g @modelcontextprotocol/server-fetch
```

**Configuration:**
```json
{
  "mcpServers": {
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
```

**Benefits:**
- Check DNS propagation
- Fetch n8n and nginx documentation
- Verify SSL certificate status
- Test webhook endpoints

**Use Cases for This Project:**
- Verify domain DNS configuration
- Check SSL certificate validity
- Test webhook URLs
- Reference latest documentation

---

### 6. **Git MCP Server** (OPTIONAL)
**Priority: LOW**

Manages version control for your configurations.

**Installation:**
```bash
npm install -g @modelcontextprotocol/server-git
```

**Configuration:**
```json
{
  "mcpServers": {
    "git": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-git",
        "--repository",
        "/Users/clancehoskin/Projects/n8n Webhook and Domains"
      ]
    }
  }
}
```

**Benefits:**
- Version control configurations
- Track changes to nginx configs
- Rollback if needed
- Collaborate with team

---

## Complete Configuration for This Project

Create this file: `~/Projects/n8n Webhook and Domains/.mcp/settings.json`

```json
{
  "mcpServers": {
    "aws": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws"],
      "env": {
        "AWS_REGION": "us-east-1",
        "AWS_PROFILE": "default"
      }
    },
    "ssh-ec2": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-ssh"],
      "env": {
        "SSH_HOST": "YOUR_EC2_IP_OR_DOMAIN",
        "SSH_USER": "ubuntu",
        "SSH_KEY_PATH": "/path/to/your-key.pem",
        "SSH_PORT": "22"
      }
    },
    "docker": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "ssh://ubuntu@YOUR_EC2_IP"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/clancehoskin/Projects/n8n Webhook and Domains"
      ]
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "git": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-git",
        "--repository",
        "/Users/clancehoskin/Projects/n8n Webhook and Domains"
      ]
    }
  }
}
```

**IMPORTANT:** Replace:
- `YOUR_EC2_IP_OR_DOMAIN` with your actual EC2 public IP or domain
- `/path/to/your-key.pem` with the actual path to your EC2 key pair
- `us-east-1` with your AWS region if different

---

## How to Activate MCP Servers for This Project Only

### Method 1: Project-Specific Configuration (Recommended)

1. **Create MCP directory in your project:**
   ```bash
   cd "/Users/clancehoskin/Projects/n8n Webhook and Domains"
   mkdir -p .mcp
   ```

2. **Create settings file:**
   ```bash
   nano .mcp/settings.json
   ```
   Paste the complete configuration above.

3. **Tell Claude Code to use this configuration:**
   When working in this project, Claude Code will automatically detect and use the `.mcp/settings.json` file.

### Method 2: Claude Desktop Configuration

If using Claude Desktop, edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "workspaces": {
    "n8n-webhook-domains": {
      "path": "/Users/clancehoskin/Projects/n8n Webhook and Domains",
      "mcpServers": {
        // Same configuration as above
      }
    }
  }
}
```

### Method 3: Environment Variables (Temporary)

For a single session:

```bash
export MCP_CONFIG_PATH="/Users/clancehoskin/Projects/n8n Webhook and Domains/.mcp/settings.json"
```

---

## Installation Steps

### Step 1: Install Node.js (if not already installed)

```bash
# macOS with Homebrew
brew install node

# Or download from https://nodejs.org
```

### Step 2: Install Essential MCP Servers

```bash
# Install all recommended servers at once
npm install -g \
  @modelcontextprotocol/server-aws \
  @modelcontextprotocol/server-ssh \
  @modelcontextprotocol/server-docker \
  @modelcontextprotocol/server-filesystem \
  @modelcontextprotocol/server-fetch \
  @modelcontextprotocol/server-git
```

### Step 3: Configure AWS Credentials

```bash
# Install AWS CLI if needed
brew install awscli  # macOS

# Configure credentials
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name (e.g., us-east-1)
- Default output format (json)

### Step 4: Test SSH Access

```bash
# Test SSH connection to your EC2 instance
ssh -i /path/to/your-key.pem ubuntu@your-ec2-ip

# If successful, exit
exit
```

### Step 5: Create Project MCP Configuration

```bash
cd "/Users/clancehoskin/Projects/n8n Webhook and Domains"
mkdir -p .mcp
cat > .mcp/settings.json << 'EOF'
{
  "mcpServers": {
    "aws": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws"],
      "env": {
        "AWS_REGION": "us-east-1",
        "AWS_PROFILE": "default"
      }
    },
    "ssh-ec2": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-ssh"],
      "env": {
        "SSH_HOST": "YOUR_EC2_IP",
        "SSH_USER": "ubuntu",
        "SSH_KEY_PATH": "/path/to/your-key.pem",
        "SSH_PORT": "22"
      }
    }
  }
}
EOF
```

### Step 6: Edit with Your Details

```bash
nano .mcp/settings.json
```

Update with your actual:
- EC2 IP address
- SSH key path
- AWS region

---

## Verification

### Test AWS MCP Server

Ask Claude:
```
"What is the status of my EC2 instance?"
"Show me my security group rules"
```

### Test SSH MCP Server

Ask Claude:
```
"Check if Docker is installed on my EC2 instance"
"Show me the nginx status on my server"
```

### Test Docker MCP Server

Ask Claude:
```
"List all running Docker containers on my EC2 instance"
"Show me the logs for the n8n container"
```

---

## Troubleshooting

### MCP Server Not Found

```bash
# Check if installed
npm list -g @modelcontextprotocol/server-aws

# Reinstall if needed
npm install -g @modelcontextprotocol/server-aws --force
```

### SSH Connection Issues

```bash
# Check SSH key permissions
chmod 400 /path/to/your-key.pem

# Test connection manually
ssh -i /path/to/your-key.pem -v ubuntu@your-ec2-ip
```

### AWS Credentials Issues

```bash
# Verify credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

---

## Security Best Practices

1. **Never commit `.mcp/settings.json` with sensitive data**
   ```bash
   echo ".mcp/settings.json" >> .gitignore
   ```

2. **Use AWS IAM roles with minimal permissions**

3. **Rotate SSH keys regularly**

4. **Use AWS Secrets Manager for sensitive data**

5. **Restrict SSH key file permissions:**
   ```bash
   chmod 400 /path/to/your-key.pem
   ```

---

## Summary

**For the fastest setup of this n8n project, install these in order:**

1. **AWS MCP Server** - Manage AWS resources
2. **SSH MCP Server** - Execute commands on EC2
3. **Docker MCP Server** - Manage n8n container
4. **File System MCP Server** - Manage local configs

With these four MCP servers, Claude can:
- Configure your AWS security groups automatically
- Install and configure nginx and Docker on your EC2 instance
- Deploy and manage your n8n container
- Create and manage all configuration files
- Monitor and troubleshoot your setup

**Time Saved:** With MCP servers configured, the entire setup process can be completed in 15-20 minutes instead of 2-3 hours of manual work.

---

## Additional Resources

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP Server GitHub](https://github.com/modelcontextprotocol)
- [AWS MCP Server Docs](https://github.com/modelcontextprotocol/servers/tree/main/src/aws)
- [SSH MCP Server Docs](https://github.com/modelcontextprotocol/servers/tree/main/src/ssh)
