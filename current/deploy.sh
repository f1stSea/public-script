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

# ── 工具函数：增量更新单个 key=value，不影响文件里其他行 ──
set_env_var() {
  local key=$1 value=$2
  touch .env
  if grep -q "^${key}=" .env 2>/dev/null; then
    # macOS sed 需要空字符串参数
    sed -i '' "s|^${key}=.*|${key}=${value}|" .env 2>/dev/null || \
      sed -i "s|^${key}=.*|${key}=${value}|" .env
  else
    echo "${key}=${value}" >> .env
  fi
}

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

# ── 自动生成类：有就读旧值保留，没有就随机生成 ──────────
if [ -f .env ]; then
  DB_PASSWORD=$(grep '^DB_PASSWORD=' .env | cut -d= -f2)
  SECRET_KEY=$(grep '^SECRET_KEY=' .env | cut -d= -f2)
fi
if [ -z "$DB_PASSWORD" ]; then
  DB_PASSWORD=$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-20)
  echo "🔑 Generated new DB password"
fi
if [ -z "$SECRET_KEY" ]; then
  SECRET_KEY=$(openssl rand -hex 32)
  echo "🔑 Generated new SECRET_KEY"
fi

# ── 用户提供类 API Key：有就保留，没有就交互式询问 ────────
read_key_if_missing() {
  local key=$1 prompt=$2
  local current_val
  current_val=$(grep "^${key}=" .env 2>/dev/null | cut -d= -f2-)
  if [ -n "$current_val" ]; then
    echo "ℹ️  Keeping existing ${key}"
    eval "${key}='${current_val}'"
  else
    read -rp "🔑 ${prompt}（留空跳过）: " input_val
    eval "${key}='${input_val:-}'"
  fi
}

read_key_if_missing "TUSHARE_TOKEN"          "Tushare Token"
read_key_if_missing "FINNHUB_API_KEY"        "Finnhub API Key"
read_key_if_missing "ALPHAVANTAGE_API_KEY"   "AlphaVantage API Key"
read_key_if_missing "LONGBRIDGE_APP_KEY"     "Longbridge App Key"
read_key_if_missing "LONGBRIDGE_APP_SECRET"  "Longbridge App Secret"
read_key_if_missing "LONGBRIDGE_ACCESS_TOKEN" "Longbridge Access Token"

# ── 增量写入 .env（只碰关心的字段，其余原封不动）────────
set_env_var "DB_PASSWORD"              "$DB_PASSWORD"
set_env_var "SECRET_KEY"               "$SECRET_KEY"
set_env_var "FRONTEND_PORT"            "$FRONTEND_PORT"
set_env_var "BACKEND_PORT"             "$BACKEND_PORT"
set_env_var "DB_PORT"                  "$DB_PORT"
set_env_var "TUSHARE_TOKEN"            "${TUSHARE_TOKEN:-}"
set_env_var "FINNHUB_API_KEY"          "${FINNHUB_API_KEY:-}"
set_env_var "ALPHAVANTAGE_API_KEY"     "${ALPHAVANTAGE_API_KEY:-}"
set_env_var "LONGBRIDGE_APP_KEY"       "${LONGBRIDGE_APP_KEY:-}"
set_env_var "LONGBRIDGE_APP_SECRET"    "${LONGBRIDGE_APP_SECRET:-}"
set_env_var "LONGBRIDGE_ACCESS_TOKEN"  "${LONGBRIDGE_ACCESS_TOKEN:-}"

echo "📝 Ports: frontend=${FRONTEND_PORT}  backend=${BACKEND_PORT}  db=${DB_PORT}"

# ── 拉取 compose 配置 ─────────────────────────────────────
echo "📦 Fetching latest compose..."
curl -fsSL "$COMPOSE_URL" -o docker-compose.yml

# ── 拉取镜像并启动 ────────────────────────────────────────
echo "📦 Pulling images..."
sudo docker compose pull

echo "🚀 Deploying..."
sudo docker compose up -d

echo "✅ Done! http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP'):${FRONTEND_PORT}"
