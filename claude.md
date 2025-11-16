# Project: n8n Webhook and Domain Configuration

## Overview

This project provides complete setup documentation and automation scripts to fix n8n webhook URLs on AWS EC2 instances. The goal is to replace `http://0.0.0.0:5678/...` URLs with proper HTTPS URLs using a custom domain.

## Rules

- Always ask questions when the system doesn't understand - do not make up scenarios or assume
- Always remember to clean and organize and delete old files
- Keep documentation up to date when making changes
- Never commit sensitive data (credentials, .env files, SSH keys)

## Project Structure

- `/docs` - Detailed documentation (DNS, AWS, troubleshooting)
- `/scripts` - Automation scripts (setup, SSL, deployment)
- `/nginx` - nginx configuration templates
- Root files - Main documentation and Docker configs

## Key Files to Maintain

- README.md - Main entry point
- SETUP_GUIDE.md - Step-by-step instructions
- docker-compose.yml - n8n configuration
- .env.example - Environment template
- All scripts in /scripts directory

## When Working on This Project

1. Test all scripts before committing
2. Update documentation if changing configurations
3. Maintain consistency between examples in docs
4. Keep MCP_SERVERS.md updated with latest MCP server versions
5. Ensure all file paths use the full project path when needed
