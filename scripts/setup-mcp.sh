#!/bin/bash

# MCP Server Setup Script for n8n Webhook Domains Project
# This script helps configure MCP servers for Claude Desktop

set -e

echo "=================================="
echo "MCP Server Setup for n8n Project"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed${NC}"
    echo "Please install Node.js first:"
    echo "  macOS: brew install node"
    echo "  or download from: https://nodejs.org"
    exit 1
fi

echo -e "${GREEN}✅ Node.js is installed: $(node --version)${NC}"

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ npm is installed: $(npm --version)${NC}"
echo ""

# Ask user what they want to install
echo "Which MCP servers do you want to install?"
echo ""
echo "1. Essential Only (AWS + SSH) - Recommended for basic setup"
echo "2. Full Suite (AWS + SSH + Docker + Filesystem) - Recommended for automation"
echo "3. Custom Selection"
echo ""
read -p "Enter your choice (1-3): " choice

INSTALL_AWS=false
INSTALL_SSH=false
INSTALL_DOCKER=false
INSTALL_FILESYSTEM=false
INSTALL_FETCH=false

case $choice in
    1)
        INSTALL_AWS=true
        INSTALL_SSH=true
        ;;
    2)
        INSTALL_AWS=true
        INSTALL_SSH=true
        INSTALL_DOCKER=true
        INSTALL_FILESYSTEM=true
        ;;
    3)
        read -p "Install AWS MCP Server? (y/n): " ans
        [[ $ans == "y" ]] && INSTALL_AWS=true

        read -p "Install SSH MCP Server? (y/n): " ans
        [[ $ans == "y" ]] && INSTALL_SSH=true

        read -p "Install Docker MCP Server? (y/n): " ans
        [[ $ans == "y" ]] && INSTALL_DOCKER=true

        read -p "Install Filesystem MCP Server? (y/n): " ans
        [[ $ans == "y" ]] && INSTALL_FILESYSTEM=true

        read -p "Install Fetch MCP Server? (y/n): " ans
        [[ $ans == "y" ]] && INSTALL_FETCH=true
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "Installing selected MCP servers..."
echo ""

# Install selected servers
if [ "$INSTALL_AWS" = true ]; then
    echo "📦 Installing AWS MCP Server..."
    npm install -g @modelcontextprotocol/server-aws
    echo -e "${GREEN}✅ AWS MCP Server installed${NC}"
fi

if [ "$INSTALL_SSH" = true ]; then
    echo "📦 Installing SSH MCP Server..."
    npm install -g @modelcontextprotocol/server-ssh
    echo -e "${GREEN}✅ SSH MCP Server installed${NC}"
fi

if [ "$INSTALL_DOCKER" = true ]; then
    echo "📦 Installing Docker MCP Server..."
    npm install -g @modelcontextprotocol/server-docker
    echo -e "${GREEN}✅ Docker MCP Server installed${NC}"
fi

if [ "$INSTALL_FILESYSTEM" = true ]; then
    echo "📦 Installing Filesystem MCP Server..."
    npm install -g @modelcontextprotocol/server-filesystem
    echo -e "${GREEN}✅ Filesystem MCP Server installed${NC}"
fi

if [ "$INSTALL_FETCH" = true ]; then
    echo "📦 Installing Fetch MCP Server..."
    npm install -g @modelcontextprotocol/server-fetch
    echo -e "${GREEN}✅ Fetch MCP Server installed${NC}"
fi

echo ""
echo -e "${GREEN}✅ MCP servers installed successfully!${NC}"
echo ""

# Gather configuration information
echo "=================================="
echo "Configuration Setup"
echo "=================================="
echo ""

read -p "Enter your EC2 public IP or domain: " EC2_HOST
read -p "Enter path to your EC2 SSH key (.pem file): " SSH_KEY
read -p "Enter your AWS region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# Get the absolute path to this project
PROJECT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo ""
echo "Generating Claude Desktop configuration..."
echo ""

# Generate the MCP config for Claude Desktop
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

# Check if Claude Desktop config exists
if [ -f "$CLAUDE_CONFIG" ]; then
    echo -e "${YELLOW}⚠️  Claude Desktop config already exists${NC}"
    echo "Location: $CLAUDE_CONFIG"
    echo ""
    echo "Would you like to:"
    echo "1. Backup existing config and create new one"
    echo "2. Show the configuration to manually add"
    echo "3. Skip configuration"
    read -p "Enter your choice (1-3): " config_choice

    case $config_choice in
        1)
            BACKUP="$CLAUDE_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$CLAUDE_CONFIG" "$BACKUP"
            echo -e "${GREEN}✅ Backup created: $BACKUP${NC}"
            ;;
        2)
            config_choice=2
            ;;
        3)
            echo "Skipping configuration..."
            exit 0
            ;;
    esac
fi

# Create the configuration JSON
cat > /tmp/mcp-config.json << EOF
{
  "mcpServers": {
EOF

if [ "$INSTALL_AWS" = true ]; then
cat >> /tmp/mcp-config.json << EOF
    "aws": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-aws"],
      "env": {
        "AWS_REGION": "$AWS_REGION",
        "AWS_PROFILE": "default"
      }
    },
EOF
fi

if [ "$INSTALL_SSH" = true ]; then
cat >> /tmp/mcp-config.json << EOF
    "ssh-ec2": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-ssh"],
      "env": {
        "SSH_HOST": "$EC2_HOST",
        "SSH_USER": "ubuntu",
        "SSH_KEY_PATH": "$SSH_KEY",
        "SSH_PORT": "22"
      }
    },
EOF
fi

if [ "$INSTALL_DOCKER" = true ]; then
cat >> /tmp/mcp-config.json << EOF
    "docker": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-docker"],
      "env": {
        "DOCKER_HOST": "ssh://ubuntu@$EC2_HOST"
      }
    },
EOF
fi

if [ "$INSTALL_FILESYSTEM" = true ]; then
cat >> /tmp/mcp-config.json << EOF
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "$PROJECT_PATH"
      ]
    },
EOF
fi

if [ "$INSTALL_FETCH" = true ]; then
cat >> /tmp/mcp-config.json << EOF
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
EOF
fi

# Remove trailing comma from last entry
sed -i '' '$ s/,$//' /tmp/mcp-config.json

cat >> /tmp/mcp-config.json << EOF
  }
}
EOF

echo ""
echo "=================================="
echo "MCP Configuration Generated"
echo "=================================="
echo ""

if [ "$config_choice" = "2" ]; then
    echo "Add this to your Claude Desktop config at:"
    echo "$CLAUDE_CONFIG"
    echo ""
    cat /tmp/mcp-config.json
    echo ""
else
    # Save to Claude Desktop config
    mkdir -p "$HOME/Library/Application Support/Claude"
    cp /tmp/mcp-config.json "$CLAUDE_CONFIG"
    echo -e "${GREEN}✅ Configuration saved to Claude Desktop${NC}"
    echo "Location: $CLAUDE_CONFIG"
fi

# Save a copy to the project
mkdir -p "$PROJECT_PATH/.claude"
cp /tmp/mcp-config.json "$PROJECT_PATH/.claude/mcp-config.json"
echo -e "${GREEN}✅ Configuration saved to project${NC}"
echo "Location: $PROJECT_PATH/.claude/mcp-config.json"

# Clean up
rm /tmp/mcp-config.json

echo ""
echo "=================================="
echo "Next Steps"
echo "=================================="
echo ""
echo "1. Restart Claude Desktop app (if you're using it)"
echo "2. Configure AWS credentials:"
echo "   aws configure"
echo ""
echo "3. Test SSH connection:"
echo "   ssh -i $SSH_KEY ubuntu@$EC2_HOST"
echo ""
echo "4. In Claude Desktop, ask:"
echo "   'What is my EC2 instance status?'"
echo "   'Show me my security groups'"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
