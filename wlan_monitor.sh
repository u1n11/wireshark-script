#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

# Parse command line arguments
MODE_ARG=""
if [ "$1" == "--all" ] || [ "$1" == "all" ]; then
    MODE_ARG="all"
elif [ "$1" == "--with-network" ] || [ "$1" == "with-network" ]; then
    MODE_ARG="with-network"
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
use_all_interfaces=false
keep_network=false
selected_interfaces=()

# Check if mode is set via command line argument
if [ -n "$MODE_ARG" ]; then
    selection=$MODE_ARG
    echo "Mode: $selection (from command line)"
    echo ""
else
    echo "Special modes:"
    echo "  - Type 'all' to enable monitor mode on ALL interfaces"
    echo "  - Type 'with-network' to keep NetworkManager running (slower capture)"
    echo ""
    read -p "Select interface (number, name, 'all', or 'with-network'): " selection
fi

if [ "$selection" == "all" ]; then
    use_all_interfaces=true
    selected_interfaces=("${capable_interfaces[@]}")
    echo "All interfaces mode enabled"
    echo ""
    echo "Select primary interface for scanning and configuration:"
    for i in "${!capable_interfaces[@]}"; do
        echo "$((i+1)). ${capable_interfaces[$i]}"
    done
    read -p "Select primary interface (number or name): " primary_selection
    
    primary_iface=""
    if [[ "$primary_selection" =~ ^[0-9]+$ ]]; then
        index=$((primary_selection-1))
        if [ $index -ge 0 ] && [ $index -lt ${#capable_interfaces[@]} ]; then
            primary_iface=${capable_interfaces[$index]}
        fi
    else
        for iface in "${capable_interfaces[@]}"; do
            if [ "$iface" == "$primary_selection" ]; then
                primary_iface=$iface
                break
            fi
        done
    fi
    
    if [ -z "$primary_iface" ]; then
        echo "Invalid primary interface selection."
        exit 1
    fi
    echo "Primary interface: $primary_iface"
    echo "Other interfaces will follow primary interface settings"
elif [ "$selection" == "with-network" ]; then
    keep_network=true
    echo "Mode: Keep network services running"
    echo "Note: Capture efficiency may be lower"
    echo ""
    read -p "Select interface (number or name): " network_selection
    
    selected_iface=""
    if [[ "$network_selection" =~ ^[0-9]+$ ]]; then
        index=$((network_selection-1))
        if [ $index -ge 0 ] && [ $index -lt ${#capable_interfaces[@]} ]; then
            selected_iface=${capable_interfaces[$index]}
        fi
    else
        for iface in "${capable_interfaces[@]}"; do
            if [ "$iface" == "$network_selection" ]; then
                selected_iface=$iface
                break
            fi
        done
    fi
    
    if [ -z "$selected_iface" ]; then
        echo "Invalid selection."
        exit 1
    fi
    selected_interfaces=("$selected_iface")
    echo "Selected interface: $selected_iface"
else
    # Normal single interface selection
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
    selected_interfaces=("$selected_iface")
    echo "Selected interface: $selected_iface"
fi

# 3. Enable monitor mode
echo "Enabling monitor mode..."

# Kill interfering processes unless in with-network mode
if [ "$keep_network" = false ]; then
    echo "Stopping interfering processes..."
    airmon-ng check kill
else
    echo "Keeping network services running (with-network mode)"
fi

# Enable monitor mode on all selected interfaces
monitor_interfaces=()
primary_mon_iface=""

for iface in "${selected_interfaces[@]}"; do
    echo "Starting monitor mode on $iface..."
    airmon-ng start $iface
    
    # Find the monitor interface name for this interface
    # It might be the same name or have 'mon' appended
    mon_name=$(iw dev | awk -v orig="$iface" '/Interface/ {iface=$2} /type monitor/ && iface~orig {print iface}' | head -n 1)
    
    if [ -z "$mon_name" ]; then
        # Try with 'mon' suffix
        mon_name="${iface}mon"
        if ! iw dev "$mon_name" info &>/dev/null; then
            mon_name=$iface
        fi
    fi
    
    echo "  Monitor interface: $mon_name"
    monitor_interfaces+=("$mon_name")
    
    # Track the primary monitor interface
    if [ "$use_all_interfaces" = true ] && [ "$iface" == "$primary_iface" ]; then
        primary_mon_iface=$mon_name
    fi
done

if [ ${#monitor_interfaces[@]} -eq 0 ]; then
    echo "Failed to enable monitor mode on any interface."
    exit 1
fi

# Set primary interface for scanning
if [ "$use_all_interfaces" = true ]; then
    scan_iface=$primary_mon_iface
    echo ""
    echo "Primary monitor interface: $primary_mon_iface"
    echo "Other monitor interfaces: ${monitor_interfaces[@]}"
else
    scan_iface=${monitor_interfaces[0]}
    echo ""
    echo "Active monitor interface: $scan_iface"
fi

# 4. Scan for channels (use primary or single interface for scanning)
echo "Scanning for networks (10 seconds) using $scan_iface..."
rm -f /tmp/scan_results*
# Run airodump-ng in background for 10 seconds then kill it
# Use -s to send SIGKILL immediately after timeout
timeout -s SIGKILL 10s airodump-ng --write /tmp/scan_results --output-format csv $scan_iface > /dev/null 2>&1
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

# 7. Restrict all monitor interfaces to channel
for mon_iface in "${monitor_interfaces[@]}"; do
    echo "Setting $mon_iface to channel $target_channel..."
    iwconfig $mon_iface channel $target_channel
done

# 8. Open Wireshark with all monitor interfaces
echo "Opening Wireshark..."
if [ ${#monitor_interfaces[@]} -eq 1 ]; then
    # Single interface
    wireshark -i ${monitor_interfaces[0]} -k &
else
    # Multiple interfaces - build interface list for Wireshark
    wireshark_ifaces=""
    for mon_iface in "${monitor_interfaces[@]}"; do
        wireshark_ifaces="${wireshark_ifaces}-i $mon_iface "
    done
    wireshark $wireshark_ifaces -k &
fi

echo "Done. Wireshark launched with ${#monitor_interfaces[@]} interface(s)."
if [ "$use_all_interfaces" = true ]; then
    echo "All interfaces: ${monitor_interfaces[@]}"
fi
