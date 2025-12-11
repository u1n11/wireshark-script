
# 1. 殺掉會干擾抓包的程序 (如 NetworkManager)
sudo airmon-ng check kill

# 2. 開啟網卡的 Monitor Mode
sudo airmon-ng start wlan0

sudo ip link set wlan0 down