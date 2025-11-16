# MCP Server Setup for Claude Code (Project-Specific)

This guide shows you how to set up MCP servers **for this project only** in Claude Code, without affecting your global configuration.

## Why Project-Specific MCP?

- **Token Efficiency**: MCP servers only load when you're working in this project
- **Team Collaboration**: Configuration can be shared via git (without sensitive data)
- **No Global Pollution**: Other projects remain unaffected
- **On-Demand Activation**: You control when MCP servers are enabled

## Current Configuration

This project includes:
- **`.mcp.json`** - Active MCP configuration (currently only filesystem server)
- **`.mcp.json.template`** - Full template with AWS, SSH, Docker servers (requires your credentials)
- **`.mcp.local.json`** - For local overrides with sensitive data (gitignored)

## Quick Start: Enable Basic MCP (Filesystem Only)

The project already has a basic `.mcp.json` configured with the filesystem server.

**To activate it:**

1. **First time**: Claude Code will prompt you to approve the MCP server when it detects `.mcp.json`
2. Click **"Approve"** when prompted
3. The filesystem MCP server will now be active for this project only

**To test it works:**
Ask Claude: "List all files in this project using MCP"

## Full Setup: Enable AWS, SSH, and Docker MCP Servers

### Prerequisites

1. **Install Node.js** (if not already installed):
   ```bash
   brew install node
   ```

2. **Install MCP Servers**:
   ```bash
   npm install -g @modelcontextprotocol/server-filesystem
   npm install -g @modelcontextprotocol/server-aws
   npm install -g @modelcontextprotocol/server-ssh
   npm install -g @modelcontextprotocol/server-docker
   ```

3. **Configure AWS CLI** (if using AWS MCP):
   ```bash
   aws configure
   # Enter your AWS Access Key, Secret Key, and region
   ```

### Step 1: Create Your Local MCP Configuration

Copy the template and customize it:

```bash
cd "/Users/clancehoskin/Projects/n8n Webhook and Domains"
cp .mcp.json.template .mcp.local.json
```

### Step 2: Edit `.mcp.local.json` with Your Details

```bash
nano .mcp.local.json
```

Replace these placeholders:
- `YOUR_EC2_IP_OR_DOMAIN` → Your actual EC2 public IP or domain
- `/path/to/your-key.pem` → Full path to your SSH key file (e.g., `/Users/clancehoskin/.ssh/my-ec2-key.pem`)
- `us-east-1` → Your AWS region (if different)

**Example:**
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/clancehoskin/Projects/n8n Webhook and Domains"
      ],
      "env": {}
    },
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
        "SSH_HOST": "54.123.45.67",
        "SSH_USER": "ubuntu",
        "SSH_KEY_PATH": "/Users/clancehoskin/.ssh/my-ec2-key.pem",
        "SSH_PORT": "22"
      }
    },
    "docker": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "ssh://ubuntu@54.123.45.67"
      }
    }
  }
}
```

### Step 3: Rename to Activate

Once you've customized `.mcp.local.json`:

```bash
mv .mcp.json .mcp.json.basic
mv .mcp.local.json .mcp.json
```

### Step 4: Restart Claude Code

The next time you open this project in Claude Code:
1. Claude will detect the new `.mcp.json`
2. You'll be prompted to approve each new MCP server
3. Click **"Approve"** for each one

### Step 5: Verify MCP Servers Are Working

Ask Claude these questions:

**Test Filesystem MCP:**
```
List all markdown files in this project
```

**Test AWS MCP:**
```
What is the status of my EC2 instances?
Show me my security group rules
```

**Test SSH MCP:**
```
Check if Docker is installed on my EC2 instance
Show me the nginx status on my server
```

**Test Docker MCP:**
```
List all running Docker containers on my EC2
```

## Managing MCP Servers

### Enable/Disable MCP Servers

**Disable (temporarily):**
```bash
mv .mcp.json .mcp.json.disabled
```

**Enable (re-activate):**
```bash
mv .mcp.json.disabled .mcp.json
```

### Reset Approval Choices

If you need to reset which servers you've approved:
```bash
claude mcp reset-project-choices
```

### Switch Between Configurations

**Use basic (filesystem only):**
```bash
mv .mcp.json .mcp.json.full
mv .mcp.json.basic .mcp.json
```

**Use full (all servers):**
```bash
mv .mcp.json .mcp.json.basic
mv .mcp.json.full .mcp.json
```

## Token Usage Optimization

MCP servers only consume tokens when:
1. **Initial Load**: When Claude Code starts and detects `.mcp.json`
2. **Active Use**: When you ask Claude to use MCP capabilities

**Best Practices:**
- Keep `.mcp.json` disabled when doing simple file edits
- Enable it when you need AWS/SSH/Docker automation
- Use `.mcp.json.basic` for most development work
- Switch to `.mcp.json.full` only when deploying/managing infrastructure

## Security Best Practices

1. **Never commit `.mcp.local.json`** (already in .gitignore)
2. **Restrict SSH key permissions:**
   ```bash
   chmod 400 /path/to/your-key.pem
   ```
3. **Use AWS IAM with minimal permissions**
4. **Rotate credentials regularly**
5. **Review approved MCP servers periodically**

## Troubleshooting

### MCP Server Not Found

```bash
# Check if installed globally
npm list -g @modelcontextprotocol/server-aws

# Reinstall if needed
npm install -g @modelcontextprotocol/server-aws --force
```

### SSH Connection Failed

```bash
# Test SSH connection manually
ssh -i /path/to/your-key.pem ubuntu@your-ec2-ip

# Check key permissions
ls -la /path/to/your-key.pem
# Should show: -r-------- (400)

# Fix if needed
chmod 400 /path/to/your-key.pem
```

### AWS Credentials Not Working

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

### MCP Server Stuck Loading

```bash
# Reset project choices
claude mcp reset-project-choices

# Remove and recreate .mcp.json
rm .mcp.json
cp .mcp.json.template .mcp.json
# Edit and customize...
```

### Check MCP Server Logs

If a server isn't working, check the Claude Code logs:
```bash
# Location varies by OS, check Claude Code settings
# Usually: ~/.claude/logs/
```

## What Each MCP Server Does

### Filesystem MCP (`@modelcontextprotocol/server-filesystem`)
- **Purpose**: File operations within this project
- **Token Usage**: Low (only loads project file structure)
- **Use When**: Always safe to enable
- **Example**: "Show me all nginx config files"

### AWS MCP (`@modelcontextprotocol/server-aws`)
- **Purpose**: Manage AWS resources (EC2, Security Groups, etc.)
- **Token Usage**: Medium (loads AWS resource metadata)
- **Use When**: Configuring infrastructure, checking instances
- **Example**: "Update my security group to allow port 443"

### SSH MCP (`@modelcontextprotocol/server-ssh`)
- **Purpose**: Execute commands on remote servers
- **Token Usage**: Low (establishes connection)
- **Use When**: Installing software, checking server status
- **Example**: "Install Docker on my EC2 instance"

### Docker MCP (`@modelcontextprotocol/server-docker`)
- **Purpose**: Manage Docker containers
- **Token Usage**: Low-Medium (loads container states)
- **Use When**: Deploying, monitoring, debugging containers
- **Example**: "Show me the logs for the n8n container"

## Real-World Workflow Example

### Scenario: Deploy n8n to AWS

**1. Start with basic MCP (filesystem only):**
```bash
# Use default .mcp.json (already configured)
```

Ask Claude to review your configs:
```
Check if my docker-compose.yml has the correct WEBHOOK_URL
```

**2. Enable full MCP when ready to deploy:**
```bash
# Copy your customized local config
mv .mcp.json.full .mcp.json
```

**3. Let Claude automate the deployment:**
```
I need you to:
1. Check my EC2 instance status
2. Verify ports 80 and 443 are open in security groups
3. SSH to the server and install Docker
4. Deploy n8n using the docker-compose.yml
5. Check if n8n is running
```

**4. When done, switch back to basic:**
```bash
mv .mcp.json .mcp.json.full
mv .mcp.json.basic .mcp.json
```

## Time Savings with MCP

| Task | Without MCP | With MCP |
|------|-------------|----------|
| Check EC2 status | 2-3 min (AWS Console) | 10 sec (ask Claude) |
| Update security groups | 3-5 min (AWS Console) | 20 sec (ask Claude) |
| SSH and run commands | 1-2 min (manual SSH) | 15 sec (ask Claude) |
| Deploy Docker containers | 5-10 min (manual) | 30 sec (ask Claude) |
| **Total Setup** | **2-3 hours** | **15-20 minutes** |

## Next Steps

1. **Basic Setup** (do this now):
   - Current `.mcp.json` is ready with filesystem MCP
   - Approve it when Claude Code prompts you

2. **Full Setup** (do when you have EC2 details):
   - Install MCP servers globally: `npm install -g ...`
   - Copy and customize `.mcp.json.template`
   - Test each MCP server individually

3. **Start Deploying**:
   - Follow the main [SETUP_GUIDE.md](SETUP_GUIDE.md)
   - Let Claude automate the infrastructure setup with MCP

## Additional Resources

- [MCP Official Documentation](https://modelcontextprotocol.io/)
- [Claude Code MCP Guide](https://code.claude.com/docs/en/mcp.md)
- [MCP Server GitHub](https://github.com/modelcontextprotocol/servers)
- [This Project's MCP_SERVERS.md](MCP_SERVERS.md) - Original MCP documentation
