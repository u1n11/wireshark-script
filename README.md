# WLAN Monitor Automation

This project provides scripts to automate the process of setting up a wireless network interface in monitor mode, scanning for networks, and launching Wireshark on a specific channel.

## Scripts / 腳本

### 1. `wlan_monitor_setup.sh`
**Description**: Installs necessary dependencies (`aircrack-ng`, `wireshark`, `iw`, `net-tools`).
**描述**: 安裝必要的依賴套件 (`aircrack-ng`, `wireshark`, `iw`, `net-tools`)。

### 2. `wlan_monitor.sh`
**Description**: The main script to:
1. List interfaces supporting monitor mode.
2. Enable monitor mode on the selected interface.
3. Scan for available networks.
4. Allow user to select a channel.
5. Set the interface to the selected channel.
6. Launch Wireshark.
**描述**: 主要腳本，功能如下：
1. 列出支援監控模式的介面。
2. 在選定的介面上啟用監控模式。
3. 掃描可用的網路。
4. 允許使用者選擇頻道。
5. 將介面設定為選定的頻道。
6. 啟動 Wireshark。

### 3. `wlan_monitor_restore.sh`
**Description**: Restores the network interface to managed mode and restarts NetworkManager.
**描述**: 將網路介面恢復為管理模式並重新啟動 NetworkManager。

## Usage / 使用方法

You can run the scripts directly or use the VS Code Tasks.
您可以直接執行腳本或使用 VS Code Tasks。

### VS Code Tasks / VS Code 任務

Open the Command Palette (`Ctrl+Shift+P`) and select `Tasks: Run Task`.
開啟命令面板 (`Ctrl+Shift+P`) 並選擇 `Tasks: Run Task`。

Available tasks / 可用任務:
1. **Setup WLAN Monitor Tools**: Run this first to install dependencies. (請先執行此任務以安裝依賴)
2. **Start WLAN Monitor**: Run this to start the monitoring process. (執行此任務以開始監控流程)
3. **Restore WLAN**: Run this to restore network connectivity. (執行此任務以恢復網路連線)

### Manual Execution / 手動執行

```bash
# Setup / 設定
sudo ./wlan_monitor_setup.sh

# Start Monitor / 開始監控
sudo ./wlan_monitor.sh

# Restore / 恢復
sudo ./wlan_monitor_restore.sh
```
