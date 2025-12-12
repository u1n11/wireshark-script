# WLAN Monitor Automation v0.1.1

This project provides scripts to automate the process of setting up a wireless network interface in monitor mode, scanning for networks, and launching Wireshark on a specific channel.

## How to use it
You can run the scripts directly or use the VS Code Tasks.
### VS Code Tasks
Open the Command Palette (`Ctrl+Shift+P`) and select `Tasks: Run Test Task`.
Available tasks:
1. **Setup WLAN Monitor Tools**: Install dependencies.
2. **Start WLAN Monitor**: Standard single interface mode.
3. **Start WLAN Monitor (All Interfaces)**: Use all available interfaces.
4. **Start WLAN Monitor (With Network)**: Keep network connection alive.
5. **Change Monitor Channel**: Switch channel on active monitor interface.
6. **Restore WLAN**: Restore network connectivity.

### How to decrypt the Wi-Fi
**WPA2 Personal**
1. Edit > Prefrences > Protocols > IEEE 802.11
2. Select `Enable decryption`
3. Edit... Decryption key
    1. key type: `wpa-pwd`
    2. key format: `password:ssid`
**Noticed** Supports WPA2 Personal. It does not support other types. The other types are being studied.

## Scripts Description
### 1. `wlan_monitor_setup.sh`
**Description**: Installs necessary dependencies (`aircrack-ng`, `wireshark`, `iw`, `net-tools`).

### 2. `wlan_monitor.sh`
**Description**: The main script to:
1. List interfaces supporting monitor mode with detailed chipset info.
2. Enable monitor mode on the selected interface (or all interfaces).
3. Scan for available networks.
4. Allow user to select a channel.
5. Set the interface(s) to the selected channel.
6. Launch Wireshark.

**Modes**:
- **Standard**: Interactive selection of a single interface.
- **All Interfaces**: Enable monitor mode on ALL capable interfaces simultaneously.
- **With Network**: Keep NetworkManager running (useful for remote access, but may affect capture quality).

### 3. `wlan_monitor_change_channel.sh`
**Description**: Changes the channel of an interface that is already in monitor mode without restarting the whole process.

### 4. `wlan_monitor_restore.sh`
**Description**: Restores the network interface to managed mode, handles interface renaming, and restarts NetworkManager.

### Manual Execution
```bash
# Setup / 設定
sudo ./wlan_monitor_setup.sh

# Start Monitor (Standard)
sudo ./wlan_monitor.sh

# Start Monitor (All Interfaces)
sudo ./wlan_monitor.sh all

# Start Monitor (Keep Network)
sudo ./wlan_monitor.sh with-network

# Change Channel
sudo ./wlan_monitor_change_channel.sh

# Restore
sudo ./wlan_monitor_restore.sh
```