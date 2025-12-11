#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

echo "Restoring network interfaces..."

# Find monitor mode interfaces
mon_interfaces=$(iw dev | grep -B 2 "type monitor" | grep Interface | awk '{print $2}')

if [ -z "$mon_interfaces" ]; then
    echo "No monitor mode interfaces found."
else
    for iface in $mon_interfaces; do
        echo "Stopping monitor mode on $iface..."
        
        # Try airmon-ng first
        airmon-ng stop $iface
        
        # Double check and manually disable if still in monitor mode
        sleep 1
        if iw dev $iface info 2>/dev/null | grep -q "type monitor"; then
            echo "Manually disabling monitor mode on $iface..."
            ip link set $iface down
            iw dev $iface set type managed
            ip link set $iface up
            
            # Check if conversion was successful
            sleep 1
            if iw dev $iface info 2>/dev/null | grep -q "type managed"; then
                echo "Successfully converted $iface to managed mode."
                # Unlock channel restrictions
                echo "Removing channel restrictions..."
                iw dev $iface set channel auto 2>/dev/null || true
                iwconfig $iface channel auto 2>/dev/null || true
            else
                echo "Warning: $iface may still be in monitor mode."
            fi
        fi
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
