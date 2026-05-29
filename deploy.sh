#!/bin/bash
set -e

COMPOSE_URL="https://hajiimi.cc.cd/scripts/docker-compose.yml"
DEPLOY_DIR="${HOME}/evergreen"

echo "🌿 Evergreen Dashboard"

# Check docker
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Please install Docker first."
  exit 1
fi

# Work from a fixed directory so compose state is preserved across runs
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Fetch latest compose configuration
echo "📦 Fetching latest compose configuration..."
curl -fsSL "$COMPOSE_URL" -o docker-compose.yml

# Determine port: prefer existing container's port, then arg, then default
EXISTING_PORT=$(sudo docker inspect evergreen --format='{{(index .HostConfig.PortBindings "3000/tcp" 0).HostPort}}' 2>/dev/null || echo "")
if [ -n "$EXISTING_PORT" ]; then
  export PORT="$EXISTING_PORT"
  echo "ℹ️  Keeping existing port: $PORT"
else
  export PORT="${1:-3198}"
  echo "ℹ️  Using port: $PORT"
fi

# Pull latest image
echo "📦 Pulling latest image..."
sudo docker compose pull

# Check if image actually changed
CURRENT=$(sudo docker inspect evergreen --format='{{.Image}}' 2>/dev/null || echo "")
LATEST=$(sudo docker inspect ghcr.io/f1stsea/evergreen-dashboard:latest --format='{{.Id}}' 2>/dev/null || echo "")

if [ -n "$CURRENT" ] && [ "$CURRENT" = "$LATEST" ]; then
  echo "✅ Already up to date."
  exit 0
fi

# Deploy / update
echo "🚀 Deploying..."
sudo docker compose up -d

echo "✅ Done! http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP'):${PORT}"
