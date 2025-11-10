#!/usr/bin/env bash
# Grafana 自動部署腳本
# 用途：在目標主機上執行此腳本，自動安裝 Docker 並部署 Grafana

set -euo pipefail

#-----------------------------
# 配置參數
#-----------------------------
DEPLOY_DIR="/opt/grafana"
GIT_REPO="https://github.com/gerrylin0105-star/grafana.git"

#-----------------------------
# 輔助函數
#-----------------------------
cecho() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
eecho() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    eecho "請以 root 執行此腳本"
    exit 1
  fi
}

#-----------------------------
# Step 1: 檢查 root 權限
#-----------------------------
require_root

cecho "開始部署 Grafana..."

#-----------------------------
# Step 2: 安裝 Docker
#-----------------------------
if ! command -v docker &> /dev/null; then
  cecho "Docker 未安裝，開始安裝..."

  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl start docker
  systemctl enable docker

  cecho "Docker 安裝完成"
else
  cecho "Docker 已安裝: $(docker --version)"
fi

#-----------------------------
# Step 3: Clone 或更新 Repository
#-----------------------------
cecho "準備部署目錄..."
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

if [ -d ".git" ]; then
  cecho "更新現有 repository..."
  git pull origin main
else
  cecho "Clone repository..."
  git clone "$GIT_REPO" .
fi

#-----------------------------
# Step 4: 建立資料目錄
#-----------------------------
cecho "建立 Grafana 資料目錄..."
mkdir -p "$DEPLOY_DIR/grafana-data"
chown -R 472:472 "$DEPLOY_DIR/grafana-data"

#-----------------------------
# Step 5: 部署 Grafana
#-----------------------------
cecho "下載並啟動 Grafana..."
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d

#-----------------------------
# 完成
#-----------------------------
cecho "=========================================="
cecho "部署完成！ ✅"
cecho "=========================================="
cecho "Grafana URL: http://$(hostname -I | awk '{print $1}'):3000"
cecho "預設帳號: admin"
cecho "預設密碼: admin"
cecho "=========================================="
cecho "Docker 版本: $(docker --version)"
cecho "Compose 版本: $(docker compose version)"
cecho ""
cecho "執行中的容器："
docker ps
