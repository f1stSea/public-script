#!/bin/bash
set -e

COMPOSE_URL="https://raw.githubusercontent.com/f1stSea/public-script/main/current/docker-compose.yml"
DEPLOY_DIR="${HOME}/current"

echo "📈 Current — 市场全景"

if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Please install Docker first."
  exit 1
fi

mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# ── 端口：优先读现有容器，其次读环境变量，最后用默认值 ──
get_container_port() {
  sudo docker inspect "$1" --format="{{(index .HostConfig.PortBindings \"$2\" 0).HostPort}}" 2>/dev/null || echo ""
}

EXISTING_FRONTEND=$(get_container_port current-frontend "80/tcp")
EXISTING_BACKEND=$(get_container_port current-backend "8000/tcp")
EXISTING_DB=$(get_container_port current-db "5432/tcp")

FRONTEND_PORT="${EXISTING_FRONTEND:-${FRONTEND_PORT:-3199}}"
BACKEND_PORT="${EXISTING_BACKEND:-${BACKEND_PORT:-127.0.0.1:8000}}"
DB_PORT="${EXISTING_DB:-${DB_PORT:-127.0.0.1:5432}}"

[ -n "$EXISTING_FRONTEND" ] && echo "ℹ️  Keeping existing ports from running containers"

# ── DB 密码：现有 .env 保留，否则生成 ──────────────────
if [ -f .env ]; then
  DB_PASSWORD=$(grep '^DB_PASSWORD=' .env | cut -d= -f2)
fi
if [ -z "$DB_PASSWORD" ]; then
  DB_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)
  echo "🔑 Generated new DB password"
fi

# ── 写入 .env ──────────────────────────────────────────
cat > .env <<EOF
DB_PASSWORD=${DB_PASSWORD}
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_PORT=${BACKEND_PORT}
DB_PORT=${DB_PORT}
EOF

echo "📝 Ports: frontend=${FRONTEND_PORT}  backend=${BACKEND_PORT}  db=${DB_PORT}"

# ── 拉取 compose 配置 ──────────────────────────────────
echo "📦 Fetching latest compose..."
curl -fsSL "$COMPOSE_URL" -o docker-compose.yml

# ── 拉取镜像并启动 ─────────────────────────────────────
echo "📦 Pulling images..."
sudo docker compose pull

echo "🚀 Deploying..."
sudo docker compose up -d

echo "✅ Done! http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP'):${FRONTEND_PORT}"
