#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit 1
fi

echo "Updating package list..."
apt-get update

echo "Installing necessary tools..."
apt-get install -y aircrack-ng wireshark iw net-tools

echo "Setup complete."
