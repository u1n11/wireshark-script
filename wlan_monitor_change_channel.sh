#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

echo "WLAN Monitor Channel Changer"
echo "=============================="
echo ""

# Find all monitor mode interfaces
echo "Searching for monitor mode interfaces..."
mon_interfaces=$(iw dev | awk '/Interface/ {iface=$2} /type monitor/ {print iface}')

if [ -z "$mon_interfaces" ]; then
    echo "No monitor mode interfaces found."
    echo "Please run wlan_monitor.sh first to enable monitor mode."
    exit 1
fi

# Display found interfaces with current channel
echo "Found monitor mode interfaces:"
echo ""
declare -a interface_list
index=1
for iface in $mon_interfaces; do
    interface_list+=("$iface")
    current_channel=$(iw dev $iface info | grep channel | awk '{print $2}')
    current_freq=$(iw dev $iface info | grep channel | awk '{print $3, $4}' | tr -d '()')
    phy=$(iw dev $iface info | grep wiphy | awk '{print $2}')
    
    echo "$index. $iface"
    echo "   PHY: phy$phy"
    if [ -n "$current_channel" ]; then
        echo "   Current: Channel $current_channel $current_freq"
    else
        echo "   Current: Not set"
    fi
    echo ""
    ((index++))
done

# Select interface
read -p "Select interface (number): " selection

selected_interfaces=()

if [[ "$selection" =~ ^[0-9]+$ ]]; then
    idx=$((selection-1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#interface_list[@]} ]; then
        selected_interfaces=("${interface_list[$idx]}")
        echo "Selected interface: ${selected_interfaces[0]}"
    else
        echo "Invalid selection."
        exit 1
    fi
else
    echo "Invalid selection."
    exit 1
fi

echo ""

# Scan for available channels (optional, use first interface)
first_iface=${selected_interfaces[0]}
echo "Scanning for networks (10 seconds) using $first_iface..."
rm -f /tmp/channel_scan*
timeout -s SIGKILL 10s airodump-ng --write /tmp/channel_scan --output-format csv $first_iface > /dev/null 2>&1
sleep 1

# List available channels
echo ""
echo "Available networks:"
echo "Channel  ESSID"

if [ -f /tmp/channel_scan-01.csv ]; then
    awk -F, '/Station MAC/ {exit} {if(NR>2 && length($4)>0) printf "%-8s %s\n", $4, $14}' /tmp/channel_scan-01.csv | sort -u
    echo ""
fi

# Ask for new channel
read -p "Enter new channel number (1-14 for 2.4GHz, 36-165 for 5GHz): " new_channel

if [ -z "$new_channel" ]; then
    echo "No channel specified. Exiting."
    exit 1
fi

# Validate channel is a number
if ! [[ "$new_channel" =~ ^[0-9]+$ ]]; then
    echo "Invalid channel number."
    exit 1
fi

# Apply new channel to selected interfaces
echo ""
echo "Changing channel to $new_channel..."
for iface in "${selected_interfaces[@]}"; do
    echo "Setting $iface to channel $new_channel..."
    iwconfig $iface channel $new_channel 2>/dev/null
    
    # Verify the change
    sleep 0.5
    verify_channel=$(iw dev $iface info | grep channel | awk '{print $2}')
    if [ "$verify_channel" == "$new_channel" ]; then
        echo "  ✓ $iface successfully set to channel $new_channel"
    else
        echo "  ✗ Failed to set $iface to channel $new_channel (current: $verify_channel)"
    fi
done

echo ""
echo "Done. Channel change complete."
echo ""
echo "Current status:"
for iface in "${selected_interfaces[@]}"; do
    current_channel=$(iw dev $iface info | grep channel | awk '{print $2}')
    current_freq=$(iw dev $iface info | grep channel | awk '{print $3, $4}' | tr -d '()')
    echo "  $iface: Channel $current_channel $current_freq"
done
