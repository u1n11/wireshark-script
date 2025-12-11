# WLAN Monitor Automation v0.1.1

This project provides scripts to automate the process of setting up a wireless network interface in monitor mode, scanning for networks, and launching Wireshark on a specific channel.

## Scripts / 腳本

### 1. `wlan_monitor_setup.sh`
**Description**: Installs necessary dependencies (`aircrack-ng`, `wireshark`, `iw`, `net-tools`).
**描述**: 安裝必要的依賴套件 (`aircrack-ng`, `wireshark`, `iw`, `net-tools`)。

### 2. `wlan_monitor.sh`
**Description**: The main script to:
1. List interfaces supporting monitor mode with detailed chipset info.
2. Enable monitor mode on the selected interface (or all interfaces).
3. Scan for available networks.
4. Allow user to select a channel.
5. Set the interface(s) to the selected channel.
6. Launch Wireshark.

**Modes / 模式**:
- **Standard**: Interactive selection of a single interface. (標準模式：互動式選擇單一介面)
- **All Interfaces**: Enable monitor mode on ALL capable interfaces simultaneously. (全介面模式：同時在所有支援的介面上啟用監控模式)
- **With Network**: Keep NetworkManager running (useful for remote access, but may affect capture quality). (保留網路模式：保持 NetworkManager 運作)

**描述**: 主要腳本，功能如下：
1. 列出支援監控模式的介面（包含詳細晶片資訊）。
2. 在選定的介面（或所有介面）上啟用監控模式。
3. 掃描可用的網路。
4. 允許使用者選擇頻道。
5. 將介面設定為選定的頻道。
6. 啟動 Wireshark。

### 3. `wlan_monitor_change_channel.sh`
**Description**: Changes the channel of an interface that is already in monitor mode without restarting the whole process.
**描述**: 在不重新啟動整個流程的情況下，更改已處於監控模式的介面的頻道。

### 4. `wlan_monitor_restore.sh`
**Description**: Restores the network interface to managed mode, handles interface renaming, and restarts NetworkManager.
**描述**: 將網路介面恢復為管理模式，處理介面重新命名，並重新啟動 NetworkManager。

## Usage / 使用方法

You can run the scripts directly or use the VS Code Tasks.
您可以直接執行腳本或使用 VS Code Tasks。

### VS Code Tasks / VS Code 任務

Open the Command Palette (`Ctrl+Shift+P`) and select `Tasks: Run Task`.
開啟命令面板 (`Ctrl+Shift+P`) 並選擇 `Tasks: Run Task`。

Available tasks / 可用任務:
1. **Setup WLAN Monitor Tools**: Install dependencies. (安裝依賴)
2. **Start WLAN Monitor**: Standard single interface mode. (標準單介面模式)
3. **Start WLAN Monitor (All Interfaces)**: Use all available interfaces. (使用所有可用介面)
4. **Start WLAN Monitor (With Network)**: Keep network connection alive. (保持網路連線)
5. **Change Monitor Channel**: Switch channel on active monitor interface. (切換監控頻道)
6. **Restore WLAN**: Restore network connectivity. (恢復網路連線)

### Manual Execution / 手動執行

```bash
# Setup / 設定
sudo ./wlan_monitor_setup.sh

# Start Monitor (Standard) / 啟動監控 (標準)
sudo ./wlan_monitor.sh

# Start Monitor (All Interfaces) / 啟動監控 (所有介面)
sudo ./wlan_monitor.sh all

# Start Monitor (Keep Network) / 啟動監控 (保留網路)
sudo ./wlan_monitor.sh with-network

# Change Channel / 更改頻道
sudo ./wlan_monitor_change_channel.sh

# Restore / 恢復
sudo ./wlan_monitor_restore.sh
```

# Start Monitor / 開始監控
sudo ./wlan_monitor.sh

# Restore / 恢復
sudo ./wlan_monitor_restore.sh
```
