#!/usr/bin/env bash
set -e

VPC_NAME="$1"
STATE_FILE="/var/lib/vpcctl/${VPC_NAME}.json"

if [[ -z "$VPC_NAME" ]]; then
  echo "Usage: $0 <vpc_name>"
  exit 1
fi

echo "🔎 Searching for all VPC components containing '$VPC_NAME'..."

# Find all namespaces that match the VPC name
NAMESPACES=$(ip netns list | grep "$VPC_NAME" | awk '{print $1}')
BRIDGES=$(ip link show | grep "$VPC_NAME" | awk -F: '{print $2}' | tr -d ' ')

if [[ -z "$NAMESPACES" && -z "$BRIDGES" && ! -f "$STATE_FILE" ]]; then
  echo "⚠️  No matching VPC components found for '$VPC_NAME'. Nothing to do."
  exit 0
fi

echo "🧹 Deleting namespaces..."
for ns in $NAMESPACES; do
  echo "   ➜ $ns"
  sudo ip netns pids "$ns" | xargs -r sudo kill -9 || true
  sudo ip netns del "$ns" 2>/dev/null || true
done

echo "🧹 Removing bridges and veths..."
for br in $BRIDGES; do
  echo "   ➜ $br"
  sudo ip link set "$br" down 2>/dev/null || true
  sudo ip link del "$br" 2>/dev/null || true
done

echo "🧹 Clearing any iptables rules referencing $VPC_NAME..."
sudo iptables-save | grep -v "$VPC_NAME" | sudo iptables-restore

if [[ -f "$STATE_FILE" ]]; then
  echo "🗑️  Removing state file..."
  sudo rm -f "$STATE_FILE"
fi

echo "✅ $VPC_NAME fully cleaned up."

