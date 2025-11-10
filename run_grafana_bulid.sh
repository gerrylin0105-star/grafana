#!/usr/bin/env bash
# 需求：檔案與本腳本置於同一資料夾
# - grafana.tar.gz           # docker image 檔
# - influxdb.tar.gz           # docker image 檔
# - 內有 docker-compose.yml

set -euo pipefail

#-----------------------------
# 基本參數（必要時可修改）
#-----------------------------
GRAFANA_IMG="grafana.tar.gz"
INFLUXDB_IMG="influxdb.tar.gz"
COMPOSE_DIR=${5:-/opt/grafana}  # 輸出目錄（可自訂）
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

# RMI/部署等後續腳本若需環境變數，可在此補上
export LC_ALL=C

#-----------------------------
# 輔助：輸出與清理
#-----------------------------
cecho() { echo -e "\033[1;36m[info]\033[0m $*"; }
wecho() { echo -e "\033[1;33m[warn]\033[0m $*"; }
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

for f in "$GRAFANA_IMG" "$INFLUXDB_IMG"; do
  if [[ ! -f "$f" ]]; then
    wecho "警告：找不到檔案 $f（若某步驟不需要，可忽略）。"
  fi
done

# 讀取系統資訊
OS_ID="$(. /etc/os-release; echo "${ID:-unknown}")"
OS_VER="$(. /etc/os-release; echo "${VERSION_ID:-unknown}")"
KERNEL="$(uname -r)"
cecho "系統：$OS_ID $OS_VER（kernel $KERNEL）"

#-----------------------------
# Step 1：載入 Docker Image (Grafana + InfluxDB)
#-----------------------------
if [[ -f "$GRAFANA_IMG" ]]; then
  cecho "Step 1：載入 Grafana Image（$GRAFANA_IMG）"
  if ! command -v docker >/dev/null 2>&1; then
    eecho "找不到 docker 指令，請先完成。"
    exit 1
  fi
  docker load -i "$GRAFANA_IMG"
  cecho "目前 grafana 相關 images："
  docker images | awk 'NR==1 || /jmeter|slave|load|perf|perfsonar|apache/'
else
  wecho "略過 Step 1：$GRAFANA_IMG 不存在。"
fi

##################

if [[ -f "$INFLUXDB_IMG" ]]; then
  cecho "Step 1：載入 Influxdb Image（$INFLUXDB_IMG）"
  if ! command -v docker >/dev/null 2>&1; then
    eecho "找不到 docker 指令，請先完成。"
    exit 1
  fi
  docker load -i "$INFLUXDB_IMG"
  cecho "目前 influxdb 相關 images："
  docker images | awk 'NR==1 || /jmeter|slave|load|perf|perfsonar|apache/'
else
  wecho "略過 Step 1：$INFLUXDB_IMG 不存在。"
fi


#-----------------------------
# Step 2：部署 Grafana
#-----------------------------

# ---------- 前置檢查 ----------
if ! command -v docker >/dev/null 2>&1; then
  eecho "docker 未安裝或不可用"; exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  eecho "未找到 docker compose，請先安裝 docker-compose-plugin 或 docker-compose"; exit 1
fi

# ---------- 檢查 docker-compose.yml ----------
if [[ ! -f "$COMPOSE_FILE" ]]; then
  eecho "找不到 docker-compose.yml（預期路徑：$COMPOSE_FILE）"; exit 1
fi

# ---------- 部署 ----------
cecho "開始部署 Grafana + InfluxDB…"
$COMPOSE_CMD -p grafan -f "$COMPOSE_FILE" up -d

chown 472:472 /opt/grafana/grafana-data

#-----------------------------
# 收尾與摘要
#-----------------------------
cecho "部署完成 ✅"
if command -v docker >/dev/null 2>&1; then
  cecho "Docker 版本：$(docker --version)"
  if docker compose version >/dev/null 2>&1; then
    cecho "Compose 版本：$(docker compose version)"
  elif command -v docker-compose >/dev/null 2>&1; then
    cecho "Compose 版本：$(docker-compose --version)"
  fi
  cecho "現有容器："
  docker ps -a || true
fi
