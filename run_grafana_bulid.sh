#!/usr/bin/env bash
# 自動從 Docker Hub 下載並部署 Grafana
# 需求：docker, docker-compose

set -euo pipefail

#-----------------------------
# 基本參數
#-----------------------------
COMPOSE_DIR=${1:-/opt/grafana}
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

export LC_ALL=C

#-----------------------------
# 輔助函數
#-----------------------------
cecho() { echo -e "\033[1;36m[info]\033[0m $*"; }
eecho() { echo -e "\033[1;31m[fail]\033[0m $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    eecho "請以 root 執行。"
    exit 1
  fi
}

#-----------------------------
# 前置檢查
#-----------------------------
require_root

# 讀取系統資訊
OS_ID="$(. /etc/os-release; echo "${ID:-unknown}")"
OS_VER="$(. /etc/os-release; echo "${VERSION_ID:-unknown}")"
KERNEL="$(uname -r)"
cecho "系統：$OS_ID $OS_VER（kernel $KERNEL）"

#-----------------------------
# 檢查 Docker
#-----------------------------
cecho "檢查 Docker 環境"

if ! command -v docker >/dev/null 2>&1; then
  eecho "docker 未安裝或不可用"; exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  eecho "未找到 docker compose"; exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  eecho "找不到 docker-compose.yml（預期路徑：$COMPOSE_FILE）"; exit 1
fi

#-----------------------------
# 建立資料目錄並部署
#-----------------------------
cecho "建立資料目錄"
mkdir -p "$COMPOSE_DIR/grafana-data"
chown -R 472:472 "$COMPOSE_DIR/grafana-data"

cecho "從 Docker Hub 下載並部署 Grafana"
cd "$COMPOSE_DIR"
$COMPOSE_CMD -f "$COMPOSE_FILE" pull
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

#-----------------------------
# 完成
#-----------------------------
cecho "部署完成 ✅"
cecho "Docker 版本：$(docker --version)"
if docker compose version >/dev/null 2>&1; then
  cecho "Compose 版本：$(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1; then
  cecho "Compose 版本：$(docker-compose --version)"
fi
cecho "現有容器："
docker ps -a || true
