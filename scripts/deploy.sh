#!/bin/bash

#######################################
# n8n Deployment Script
# Quick deployment/update script for n8n
#######################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

# Check if running in correct directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found!"
    print_info "Please run this script from ~/n8n-production directory"
    exit 1
fi

# Welcome message
echo "=========================================="
echo "   n8n Deployment & Management"
echo "=========================================="
echo ""

# Show menu
echo "Select an action:"
echo "  1) Start n8n"
echo "  2) Stop n8n"
echo "  3) Restart n8n"
echo "  4) Update n8n to latest version"
echo "  5) View logs"
echo "  6) View status"
echo "  7) Backup n8n data"
echo "  8) Full deployment (pull + restart)"
echo "  9) Exit"
echo ""
read -p "Enter choice [1-9]: " CHOICE

case $CHOICE in
    1)
        print_message "Starting n8n..."
        docker-compose up -d
        sleep 3
        docker-compose ps
        print_message "n8n started!"
        ;;

    2)
        print_message "Stopping n8n..."
        docker-compose down
        print_message "n8n stopped!"
        ;;

    3)
        print_message "Restarting n8n..."
        docker-compose restart
        sleep 3
        docker-compose ps
        print_message "n8n restarted!"
        ;;

    4)
        print_message "Updating n8n to latest version..."
        print_warning "This will pull the latest n8n image and restart the container"
        read -p "Continue? (y/n): " CONFIRM
        if [ "$CONFIRM" = "y" ]; then
            docker-compose pull
            docker-compose up -d
            sleep 5

            # Show version
            docker-compose exec n8n n8n --version
            print_message "n8n updated successfully!"
        else
            print_info "Update cancelled"
        fi
        ;;

    5)
        print_message "Viewing n8n logs (Ctrl+C to exit)..."
        echo ""
        docker-compose logs -f --tail=100
        ;;

    6)
        print_message "n8n Status:"
        echo ""
        docker-compose ps
        echo ""
        print_message "Container Details:"
        docker-compose exec n8n n8n --version 2>/dev/null || print_warning "n8n is not running"
        echo ""
        print_message "Resource Usage:"
        docker stats --no-stream n8n 2>/dev/null || print_warning "Cannot get stats"
        echo ""
        print_message "nginx Status:"
        sudo systemctl status nginx --no-pager | grep -E "(Active|Main PID)" || true
        ;;

    7)
        print_message "Creating backup of n8n data..."
        BACKUP_DIR="$HOME/n8n-backups"
        mkdir -p $BACKUP_DIR
        DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/n8n-backup-$DATE.tar.gz"

        docker run --rm \
            -v $(docker volume ls -q | grep n8n_data):/data \
            -v $BACKUP_DIR:/backup \
            ubuntu tar czf /backup/n8n-backup-$DATE.tar.gz /data

        print_message "Backup created: $BACKUP_FILE"
        ls -lh $BACKUP_FILE

        # Keep only last 7 backups
        cd $BACKUP_DIR
        ls -t | tail -n +8 | xargs rm -f 2>/dev/null || true
        print_info "Keeping last 7 backups, older ones removed"
        ;;

    8)
        print_message "Full deployment: pulling latest image and restarting..."

        # Create backup first
        print_message "Creating backup before deployment..."
        BACKUP_DIR="$HOME/n8n-backups"
        mkdir -p $BACKUP_DIR
        DATE=$(date +%Y%m%d_%H%M%S)

        docker run --rm \
            -v $(docker volume ls -q | grep n8n_data):/data \
            -v $BACKUP_DIR:/backup \
            ubuntu tar czf /backup/n8n-backup-$DATE.tar.gz /data 2>/dev/null || true

        # Pull latest image
        print_message "Pulling latest n8n image..."
        docker-compose pull

        # Restart containers
        print_message "Restarting containers..."
        docker-compose up -d

        # Wait for startup
        print_message "Waiting for n8n to start..."
        sleep 10

        # Check status
        if docker-compose ps | grep -q "n8n.*Up"; then
            print_message "Deployment successful!"
            docker-compose exec n8n n8n --version
        else
            print_error "Deployment may have failed. Check logs:"
            docker-compose logs --tail=50
        fi
        ;;

    9)
        print_info "Exiting..."
        exit 0
        ;;

    *)
        print_error "Invalid choice!"
        exit 1
        ;;
esac

echo ""
print_message "Done!"
