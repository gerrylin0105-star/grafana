#!/usr/bin/env bash
################################################################################
# Grafana + InfluxDB + Prometheus 一鍵部署腳本
# 用途：自動安裝 Docker 並部署完整監控堆疊
# 使用：sudo ./deploy.sh
################################################################################

set -euo pipefail

#-----------------------------
# 配置參數
#-----------------------------
DEPLOY_DIR="/opt/grafana"
GIT_REPO="https://github.com/gerrylin0105-star/grafana.git"
GRAFANA_PORT="3000"
INFLUXDB_PORT="8086"
PROMETHEUS_PORT="9090"
NODE_EXPORTER_PORT="9100"
ADMIN_USER="admin"
ADMIN_PASS="admin"
INFLUXDB_DATABASE="jmeter"

#-----------------------------
# 輔助函數
#-----------------------------
cecho() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
wecho() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
eecho() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    eecho "此腳本需要 root 權限執行"
    echo "請使用: sudo $0"
    exit 1
  fi
}

print_banner() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║     Grafana + InfluxDB + Prometheus 自動部署腳本           ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
}

#-----------------------------
# 主流程開始
#-----------------------------
print_banner
require_root

# 顯示系統資訊
if [ -f /etc/os-release ]; then
  OS_ID=$(. /etc/os-release; echo "${ID:-unknown}")
  OS_VER=$(. /etc/os-release; echo "${VERSION_ID:-unknown}")
  KERNEL=$(uname -r)
  cecho "系統資訊: $OS_ID $OS_VER (kernel $KERNEL)"
fi

#-----------------------------
# Step 1: 設定時間同步
#-----------------------------
cecho "Step 1: 設定系統時間同步"

# 設定時區為 Asia/Taipei
if [ -f /etc/timezone ]; then
  CURRENT_TZ=$(cat /etc/timezone)
  if [ "$CURRENT_TZ" != "Asia/Taipei" ]; then
    cecho "設定時區為 Asia/Taipei..."
    timedatectl set-timezone Asia/Taipei
  else
    cecho "時區已設定為 Asia/Taipei"
  fi
else
  cecho "設定時區為 Asia/Taipei..."
  timedatectl set-timezone Asia/Taipei
fi

# 配置 systemd-timesyncd
cecho "配置 NTP 時間同步服務..."
cat > /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=tock.stdtime.gov.tw time.stdtime.gov.tw
FallbackNTP=time.google.com time.cloudflare.com
EOF

# 重啟並啟用時間同步服務
systemctl restart systemd-timesyncd
systemctl enable systemd-timesyncd

# 啟用 NTP 同步
timedatectl set-ntp true

# 顯示時間同步狀態
sleep 2
cecho "時間同步狀態:"
timedatectl status | grep -E "Local time|System clock synchronized|NTP service"

#-----------------------------
# Step 2: 檢查並安裝 Docker
#-----------------------------
cecho "Step 2: 檢查 Docker 環境"
if ! command -v docker &> /dev/null; then
  wecho "Docker 未安裝，開始安裝..."

  # 安裝依賴
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release

  # 新增 Docker 官方 GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # 設定 Docker repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # 安裝 Docker
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # 啟動 Docker
  systemctl start docker
  systemctl enable docker

  cecho "Docker 安裝完成: $(docker --version)"
else
  cecho "Docker 已安裝: $(docker --version)"
fi

# 檢查 Docker Compose
if docker compose version >/dev/null 2>&1; then
  cecho "Docker Compose 已安裝: $(docker compose version)"
else
  eecho "Docker Compose 未安裝"
  exit 1
fi

#-----------------------------
# Step 3: 準備部署目錄
#-----------------------------
cecho "Step 3: 準備部署目錄"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

#-----------------------------
# Step 4: 下載或更新代碼
#-----------------------------
cecho "Step 4: 取得部署檔案"
if [ -d ".git" ]; then
  cecho "更新現有 repository..."
  git pull origin main
else
  cecho "Clone repository..."
  git clone "$GIT_REPO" .
fi

#-----------------------------
# Step 5: 建立資料目錄
#-----------------------------
cecho "Step 5: 建立資料目錄"
mkdir -p "$DEPLOY_DIR/grafana-data"
mkdir -p "$DEPLOY_DIR/influxdb-data"
mkdir -p "$DEPLOY_DIR/prometheus-data"
chown -R 472:472 "$DEPLOY_DIR/grafana-data"

#-----------------------------
# Step 6: 停止舊容器（如果存在）
#-----------------------------
cecho "Step 6: 清理舊容器"
if docker ps -a | grep -q grafana; then
  wecho "發現舊容器，正在停止並移除..."
  docker compose -f docker-compose.yml down
fi

#-----------------------------
# Step 7: 下載映像檔並啟動服務
#-----------------------------
cecho "Step 7: 下載並啟動服務"
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d

#-----------------------------
# Step 8: 等待服務啟動
#-----------------------------
cecho "Step 8: 等待服務啟動..."
sleep 5

#-----------------------------
# Step 9: 驗證服務狀態
#-----------------------------
cecho "Step 9: 驗證服務狀態"
CONTAINER_STATUS=$(docker compose -f docker-compose.yml ps --format json 2>/dev/null || echo "[]")

if docker ps | grep -q grafana && docker ps | grep -q influxdb && docker ps | grep -q prometheus && docker ps | grep -q node_exporter; then
  cecho "✓ 所有服務已成功啟動"
else
  wecho "部分服務可能未正常啟動，請檢查日誌"
fi

#-----------------------------
# 完成 - 顯示摘要資訊
#-----------------------------
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  部署完成！ ✅                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 取得主機 IP
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📊 Grafana"
echo "   URL:  http://$HOST_IP:$GRAFANA_PORT"
echo "   帳號: $ADMIN_USER"
echo "   密碼: $ADMIN_PASS"
echo ""
echo "💾 InfluxDB"
echo "   URL:      http://$HOST_IP:$INFLUXDB_PORT"
echo "   Database: $INFLUXDB_DATABASE"
echo "   帳號:     $ADMIN_USER"
echo "   密碼:     $ADMIN_PASS"
echo ""
echo "🔍 Prometheus"
echo "   URL:      http://$HOST_IP:$PROMETHEUS_PORT"
echo ""
echo "📈 Node Exporter"
echo "   URL:      http://$HOST_IP:$NODE_EXPORTER_PORT"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Docker 版本:  $(docker --version)"
echo "Compose 版本: $(docker compose version)"
echo ""
echo "執行中的容器:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "查看日誌: docker compose -f $DEPLOY_DIR/docker-compose.yml logs -f"
echo "停止服務: docker compose -f $DEPLOY_DIR/docker-compose.yml down"
echo "重啟服務: docker compose -f $DEPLOY_DIR/docker-compose.yml restart"
echo ""
