# Grafana 監控系統設定說明

## 📋 服務清單

部署完成後，可以透過以下 URL 訪問各服務：

| 服務 | URL | 帳號 | 密碼 | 說明 |
|------|-----|------|------|------|
| **Grafana** | http://223.27.43.107:3000 | admin | admin | 視覺化監控儀表板 |
| **InfluxDB** | http://223.27.43.107:8086 | admin | admin | 時序資料庫 (Database: jmeter) |
| **Prometheus** | http://223.27.43.107:9090 | - | - | 指標收集與查詢 |
| **Node Exporter** | http://223.27.43.107:9100 | - | - | 系統指標採集器 |

---

## 🚀 快速開始

### 1. 部署服務

在目標主機上執行：

```bash
# 下載部署腳本
curl -o deploy.sh https://raw.githubusercontent.com/gerrylin0105-star/grafana/main/deploy.sh

# 執行部署
chmod +x deploy.sh
sudo ./deploy.sh
```

部署腳本會自動：
- ✅ 設定系統時間同步 (Asia/Taipei)
- ✅ 安裝 Docker 和 Docker Compose
- ✅ 下載並啟動所有服務
- ✅ 建立必要的資料目錄

---

## 🔧 Grafana 設定

### 步驟 1: 登入 Grafana

1. 開啟瀏覽器訪問：http://223.27.43.107:3000
2. 使用預設帳號登入：
   - 帳號：`admin`
   - 密碼：`admin`
3. 首次登入會要求更改密碼（建議更改）

---

### 步驟 2: 新增 Prometheus 資料源

1. 點選左側選單 **⚙️ Configuration** → **Data Sources**
2. 點選 **Add data source**
3. 選擇 **Prometheus**
4. 設定以下參數：
   - **Name**: `Prometheus` (或自訂名稱)
   - **URL**: `http://prometheus:9090`
   - **Access**: `Server (default)`
5. 點選 **Save & Test**
6. 看到綠色勾勾「Data source is working」表示成功

> 💡 **注意**：URL 使用 `http://prometheus:9090` 而非 `localhost`，因為容器間使用 Docker 網路通訊。

---

### 步驟 3: 新增 InfluxDB 資料源（選用）

如果需要使用 InfluxDB 儲存 JMeter 測試數據：

1. 點選 **Add data source**
2. 選擇 **InfluxDB**
3. 設定以下參數：
   - **Name**: `InfluxDB`
   - **Query Language**: `InfluxQL`
   - **URL**: `http://influxdb:8086`
   - **Database**: `jmeter`
   - **User**: `admin`
   - **Password**: `admin`
4. 點選 **Save & Test**

---

## 📊 匯入監控 Dashboard

### 方案 1: 匯入 Node Exporter Full Dashboard (推薦)

監控 Linux 主機系統資源（CPU、記憶體、磁碟、網路等）

1. 點選左側選單 **📊 Dashboards** → **Import**
2. 在「Import via grafana.com」欄位輸入：`1860`
3. 點選 **Load**
4. 設定以下選項：
   - **Name**: `Node Exporter Full` (可自訂)
   - **Folder**: 選擇要放置的資料夾
   - **Prometheus**: 選擇剛才建立的 Prometheus 資料源
5. 點選 **Import**

完成後即可看到完整的系統監控儀表板！

---

### 方案 2: 其他熱門 Dashboard

| Dashboard | ID | 說明 |
|-----------|-----|------|
| Node Exporter Full | 1860 | 最完整的主機監控 |
| Node Exporter for Prometheus | 11074 | 簡潔版主機監控 |
| Docker Container & Host Metrics | 10619 | Docker 容器監控 |
| Prometheus 2.0 Stats | 3662 | Prometheus 自身監控 |

匯入方式相同，只需輸入對應的 Dashboard ID。

---

## 🖥️ Windows 主機監控設定

### 1. 在 Windows 主機上安裝 windows_exporter

1. 前往 [windows_exporter releases](https://github.com/prometheus-community/windows_exporter/releases)
2. 下載最新版本的 `.msi` 安裝檔
3. 執行安裝（預設會在 port 9182 啟動服務）
4. 檢查服務是否正常：開啟瀏覽器訪問 `http://localhost:9182/metrics`

### 2. 設定 Prometheus 抓取 Windows 指標

1. 在 Ubuntu 主機上編輯 Prometheus 設定檔：

```bash
sudo nano /opt/grafana/prometheus.yml
```

2. 找到 `windows-node` 區塊，將 Windows 主機 IP 填入：

```yaml
  - job_name: 'windows-node'
    static_configs:
      - targets: ['192.168.1.100:9182']  # 改成實際的 Windows IP
        labels:
          instance: 'windows-server'
```

3. 重新啟動 Prometheus：

```bash
cd /opt/grafana
sudo docker compose restart prometheus
```

4. 驗證：訪問 http://223.27.43.107:9090/targets 確認 Windows 目標狀態為 UP

### 3. 匯入 Windows Dashboard

1. 在 Grafana 中點選 **Dashboards** → **Import**
2. 輸入 Dashboard ID: `14694` (Windows Node)
3. 選擇 Prometheus 資料源
4. 點選 **Import**

---

## 🛠️ 常用管理指令

### 查看服務狀態

```bash
cd /opt/grafana
docker compose ps
```

### 查看服務日誌

```bash
# 查看所有服務日誌
docker compose logs -f

# 查看特定服務日誌
docker compose logs -f grafana
docker compose logs -f prometheus
docker compose logs -f influxdb
```

### 重啟服務

```bash
# 重啟所有服務
docker compose restart

# 重啟特定服務
docker compose restart grafana
docker compose restart prometheus
```

### 停止服務

```bash
docker compose down
```

### 啟動服務

```bash
docker compose up -d
```

### 更新服務

```bash
# 拉取最新映像檔
docker compose pull

# 重新建立並啟動容器
docker compose up -d
```

---

## 📁 資料目錄位置

所有資料持久化儲存在以下目錄：

```
/opt/grafana/
├── grafana-data/       # Grafana 資料（儀表板、使用者等）
├── influxdb-data/      # InfluxDB 資料庫檔案
├── prometheus-data/    # Prometheus 時序資料
├── docker-compose.yml  # Docker Compose 配置
└── prometheus.yml      # Prometheus 配置
```

---

## 🔒 安全性建議

### 1. 更改預設密碼

首次登入後**務必**更改 Grafana 和 InfluxDB 的預設密碼。

**Grafana 更改密碼：**
- 點選左下角頭像 → Profile → Change Password

**InfluxDB 更改密碼：**
```bash
docker exec -it influxdb influx
> use jmeter
> SET PASSWORD FOR admin = 'new_password'
```

### 2. 設定防火牆

建議只開放必要的 port：

```bash
# 允許 Grafana (3000)
sudo ufw allow 3000/tcp

# 其他服務建議只允許內部網路訪問
sudo ufw allow from 192.168.1.0/24 to any port 8086  # InfluxDB
sudo ufw allow from 192.168.1.0/24 to any port 9090  # Prometheus
```

### 3. 啟用 HTTPS

生產環境建議使用 Nginx 或 Traefik 作為反向代理，並配置 SSL 憑證。

---

## ❓ 常見問題

### Q1: Grafana 無法連線到 Prometheus

**A**: 確認：
1. Prometheus 容器正常運行：`docker ps | grep prometheus`
2. 資料源 URL 使用容器名稱：`http://prometheus:9090`（不是 localhost）
3. 查看 Grafana 日誌：`docker compose logs grafana`

### Q2: Node Exporter 沒有數據

**A**: 檢查：
1. Node Exporter 容器運行正常：`docker ps | grep node_exporter`
2. Prometheus targets 頁面顯示 node_exporter 狀態為 UP
3. 訪問 http://223.27.43.107:9090/targets 查看

### Q3: InfluxDB 連線失敗

**A**: 確認：
1. InfluxDB 容器運行中：`docker ps | grep influxdb`
2. 資料庫已建立：進入容器執行 `influx` → `SHOW DATABASES`
3. 防火牆允許 8086 port

### Q4: 時間顯示不正確

**A**: 檢查：
1. 系統時區：`timedatectl status`
2. 時間同步狀態：`systemctl status systemd-timesyncd`
3. Grafana 時區設定：Profile → Preferences → Timezone

---

## 📚 參考資源

- [Grafana 官方文件](https://grafana.com/docs/grafana/latest/)
- [Prometheus 官方文件](https://prometheus.io/docs/)
- [InfluxDB 官方文件](https://docs.influxdata.com/influxdb/)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [Windows Exporter](https://github.com/prometheus-community/windows_exporter)
- [Grafana Dashboard 市集](https://grafana.com/grafana/dashboards/)

---

## 📞 技術支援

如遇到問題，請檢查：
1. 容器日誌：`docker compose logs`
2. 系統資源：`htop` 或 `docker stats`
3. 網路連線：`docker network inspect grafana_default`

---

**最後更新：2025-11-10**
