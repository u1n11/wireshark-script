#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

echo "Restoring network interfaces..."
echo ""

# Kill interfering processes first
echo "Stopping interfering processes..."
airmon-ng check kill
sleep 1

# Find all monitor mode interfaces
echo "Searching for monitor mode interfaces..."
mon_interfaces=$(iw dev | awk '/Interface/ {iface=$2} /type monitor/ {print iface}')

# Also find interfaces with 'mon' suffix
mon_suffix=$(iw dev | awk '/Interface/ {if($2 ~ /mon$/) print $2}')

# Combine both lists
all_interfaces=$(echo -e "$mon_interfaces\n$mon_suffix" | sort -u | grep -v '^$')

if [ -z "$all_interfaces" ]; then
    echo "No monitor mode interfaces found."
else
    echo "Found interfaces to restore:"
    echo "$all_interfaces"
    echo ""
    
    for iface in $all_interfaces; do
        echo "=== Processing $iface ==="
        
        # Check if interface exists
        if ! ip link show $iface &>/dev/null; then
            echo "Interface $iface does not exist, skipping..."
            continue
        fi
        
        # Get current type
        current_type=$(iw dev $iface info 2>/dev/null | awk '/type/ {print $2}')
        echo "Current type: $current_type"
        
        # If already managed, skip
        if [ "$current_type" = "managed" ]; then
            echo "$iface is already in managed mode."
            
            # Check if it has 'mon' suffix, try to restore original name
            if [[ $iface == *mon ]]; then
                base_name=${iface%mon}
                echo "Attempting to restore original interface name to $base_name..."
                airmon-ng stop $iface 2>/dev/null
            fi
            echo ""
            continue
        fi
        
        # Try airmon-ng stop
        echo "Trying airmon-ng stop..."
        airmon-ng stop $iface 2>/dev/null
        sleep 1
        
        # Check if interface was renamed after airmon-ng stop
        if ! ip link show $iface &>/dev/null && [[ $iface == *mon ]]; then
            base_name=${iface%mon}
            if ip link show $base_name &>/dev/null; then
                echo "Interface renamed to $base_name"
                iface=$base_name
            fi
        fi
        
        # Check if still exists and still in monitor mode
        if ip link show $iface &>/dev/null; then
            current_type=$(iw dev $iface info 2>/dev/null | awk '/type/ {print $2}')
            
            if [ "$current_type" = "monitor" ]; then
                echo "Still in monitor mode, converting manually..."
                ip link set $iface down
                iw dev $iface set type managed
                ip link set $iface up
                sleep 1
                
                # Verify
                new_type=$(iw dev $iface info 2>/dev/null | awk '/type/ {print $2}')
                if [ "$new_type" = "managed" ]; then
                    echo "✓ Successfully converted $iface to managed mode"
                else
                    echo "✗ Failed to convert $iface (current type: $new_type)"
                fi
            else
                echo "✓ $iface is now in $current_type mode"
            fi
        fi
        echo ""
    done
fi

# Kill any remaining processes that might interfere
echo "Checking for interfering processes..."
airmon-ng check kill

echo "Restarting NetworkManager..."
service NetworkManager restart

# Wait for NetworkManager to initialize
sleep 2

echo "Network interfaces restored."
echo ""
echo "Current interface status:"
iw dev | grep -E "Interface|type"
