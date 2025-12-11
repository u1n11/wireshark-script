#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# 1. Search for interfaces supporting monitor mode
echo "Searching for wireless interfaces supporting monitor mode..."
interfaces=$(iw dev | awk '$1=="Interface"{print $2}')
declare -a capable_interfaces

for iface in $interfaces; do
    # Get phy number
    phy=$(iw dev $iface info | grep wiphy | awk '{print $2}')
    # Check if phy supports monitor mode
    if iw phy phy$phy info | grep -q "monitor"; then
        capable_interfaces+=($iface)
    fi
done

if [ ${#capable_interfaces[@]} -eq 0 ]; then
    echo "No interfaces found that support monitor mode."
    exit 1
fi

echo "Available interfaces:"
for i in "${!capable_interfaces[@]}"; do
    iface=${capable_interfaces[$i]}
    # Get interface details
    phy=$(iw dev $iface info | grep wiphy | awk '{print $2}')
    
    # Get chipset/driver info from ethtool
    driver=$(ethtool -i $iface 2>/dev/null | grep "^driver:" | awk '{print $2}')
    if [ -z "$driver" ]; then
        driver=$(basename $(readlink /sys/class/net/$iface/device/driver) 2>/dev/null || echo "Unknown")
    fi
    
    # Get hardware description
    bus_info=$(ethtool -i $iface 2>/dev/null | grep "^bus-info:" | awk '{print $2}')
    product=""
    
    if [[ $bus_info == *":"*":"* ]]; then
        # PCI device (format: 0000:00:14.3)
        product=$(lspci -s $bus_info 2>/dev/null | cut -d: -f3- | sed 's/^ //')
    elif [[ $bus_info == *"-"* ]]; then
        # USB device (format: 3-9:1.0)
        # Get USB device path from sysfs
        usb_path=$(readlink /sys/class/net/$iface/device 2>/dev/null | sed 's/.*\///; s/:.*//')
        if [ -n "$usb_path" ] && [ -d "/sys/bus/usb/devices/$usb_path" ]; then
            # Read vendor and product IDs
            vid=$(cat /sys/bus/usb/devices/$usb_path/idVendor 2>/dev/null)
            pid=$(cat /sys/bus/usb/devices/$usb_path/idProduct 2>/dev/null)
            if [ -n "$vid" ] && [ -n "$pid" ]; then
                # Get product description from lsusb using VID:PID
                product=$(lsusb -d $vid:$pid 2>/dev/null | cut -d: -f3- | sed 's/^ //')
            fi
        fi
        
        # If not found, try modinfo description
        if [ -z "$product" ] && [ "$driver" != "Unknown" ]; then
            product=$(modinfo $driver 2>/dev/null | grep "^description:" | cut -d: -f2- | sed 's/^ //')
        fi
    fi
    
    echo "$((i+1)). $iface"
    echo "   Chipset: $driver"
    echo "   PHY: phy$phy"
    if [ -n "$product" ]; then
        echo "   Device: $product"
    else
        echo "   Driver: $driver"
    fi
    echo ""
done

# 2. Select interface
read -p "Select interface (number or name): " selection

selected_iface=""
if [[ "$selection" =~ ^[0-9]+$ ]]; then
    index=$((selection-1))
    if [ $index -ge 0 ] && [ $index -lt ${#capable_interfaces[@]} ]; then
        selected_iface=${capable_interfaces[$index]}
    fi
else
    for iface in "${capable_interfaces[@]}"; do
        if [ "$iface" == "$selection" ]; then
            selected_iface=$iface
            break
        fi
    done
fi

if [ -z "$selected_iface" ]; then
    echo "Invalid selection."
    exit 1
fi

echo "Selected interface: $selected_iface"

# 3. Enable monitor mode
echo "Enabling monitor mode..."
airmon-ng check kill
airmon-ng start $selected_iface

# Find the new monitor interface name (often wlan0mon)
# We look for an interface with type monitor
mon_iface=$(iw dev | grep -B 2 "type monitor" | grep Interface | awk '{print $2}' | head -n 1)

if [ -z "$mon_iface" ]; then
    # Fallback: maybe the name didn't change and it's just in monitor mode?
    mon_iface=$selected_iface
fi
echo "Monitor interface: $mon_iface"

# 4. Scan for channels
echo "Scanning for networks (10 seconds)..."
rm -f /tmp/scan_results*
# Run airodump-ng in background for 10 seconds then kill it
# Use -s to send SIGKILL immediately after timeout
timeout -s SIGKILL 10s airodump-ng --write /tmp/scan_results --output-format csv $mon_iface > /dev/null 2>&1
# Wait a moment for file to be written
sleep 1

# 5. List channels
echo "Scan complete. Found networks:"
echo "Channel  ESSID"

if [ ! -f /tmp/scan_results-01.csv ]; then
    echo "No scan results found."
    # It might be that no networks were found or airodump failed.
    # We allow user to proceed manually if they know the channel.
else
    # Parse CSV. 
    # Format: BSSID, First time seen, Last time seen, channel, Speed, Privacy, Cipher, Authentication, Power, # beacons, # IV, LAN IP, ID-length, ESSID, Key
    # We skip header and 'Station MAC' section.
    awk -F, '/Station MAC/ {exit} {if(NR>2 && length($4)>0) printf "%-8s %s\n", $4, $14}' /tmp/scan_results-01.csv | sort -u
fi

# 6. Select channel
read -p "Enter channel to monitor: " target_channel

if [ -z "$target_channel" ]; then
    echo "No channel selected. Exiting."
    exit 1
fi

# 7. Restrict interface to channel
echo "Setting $mon_iface to channel $target_channel..."
iwconfig $mon_iface channel $target_channel

# 8. Open Wireshark
echo "Opening Wireshark..."
wireshark -i $mon_iface -k &

echo "Done. Wireshark launched."
