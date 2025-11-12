#!/usr/bin/env bash
# Automated test for vpcctl CLI
# Runs full workflow: create VPCs, add subnets, deploy apps, verify connectivity, apply firewall, peer VPCs, cleanup.

set -euo pipefail

log() {
  echo -e "\n\033[1;34m▶ $1\033[0m"
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root (sudo ./test_vpcctl.sh)"
    exit 1
  fi
}

check_root

# ====== Variables ======
VPC1="vpc1"
VPC2="vpc2"
CIDR1="10.10.0.0/16"
CIDR2="10.20.0.0/16"
PUB1="public"
PRIV1="private"
PUB2="public"
PRIV2="private"

# ====== Setup Phase ======
log "Cleaning up old state (if any)"
./vpcctl delete-vpc --name "$VPC1" || true
./vpcctl delete-vpc --name "$VPC2" || true

# ====== Create VPCs ======
log "Creating VPCs"
./vpcctl create-vpc --name "$VPC1" --cidr "$CIDR1"
./vpcctl create-vpc --name "$VPC2" --cidr "$CIDR2"

# ====== Add Subnets ======
log "Adding subnets to VPC1"
./vpcctl add-subnet --vpc "$VPC1" --name "$PUB1" --cidr 10.10.1.0/24 --public
./vpcctl add-subnet --vpc "$VPC1" --name "$PRIV1" --cidr 10.10.2.0/24

log "Adding subnets to VPC2"
./vpcctl add-subnet --vpc "$VPC2" --name "$PUB2" --cidr 10.20.1.0/24 --public
./vpcctl add-subnet --vpc "$VPC2" --name "$PRIV2" --cidr 10.20.2.0/24

# ====== Deploy simple web servers ======
log "Deploying test web servers"
ip netns exec ns-${VPC1}-${PUB1} bash -c "nohup python3 -m http.server 80 >/dev/null 2>&1 &"
ip netns exec ns-${VPC1}-${PRIV1} bash -c "nohup python3 -m http.server 8080 >/dev/null 2>&1 &"
ip netns exec ns-${VPC2}-${PUB2} bash -c "nohup python3 -m http.server 80 >/dev/null 2>&1 &"
ip netns exec ns-${VPC2}-${PRIV2} bash -c "nohup python3 -m http.server 8080 >/dev/null 2>&1 &"

# ====== Connectivity Tests ======
log "Testing intra-VPC communication (VPC1 public ↔ private)"
ip netns exec ns-${VPC1}-${PRIV1} curl -I 10.10.1.2:80 || echo "❌ Failed private→public"
ip netns exec ns-${VPC1}-${PUB1} curl -I 10.10.2.2:8080 || echo "❌ Expected failure (private port blocked)"

log "Testing NAT connectivity (from VPC1 public)"
ip netns exec ns-${VPC1}-${PUB1} ping -c 2 8.8.8.8 || echo "❌ NAT unreachable (expected if not configured)"

log "Testing VPC isolation (no peering)"
ip netns exec ns-${VPC1}-${PUB1} ping -c 2 10.20.1.2 && echo "❌ Should NOT reach another VPC" || echo "✅ Isolated"

# ====== Apply Firewall Policy ======
log "Applying firewall rule to block port 8080 on VPC1 private"
cat > /tmp/fw_policy.json <<EOF
{
  "subnet": "private",
  "ingress": [
    {"port": 80, "protocol": "tcp", "action": "allow"},
    {"port": 8080, "protocol": "tcp", "action": "deny"}
  ]
}
EOF
./vpcctl apply-firewall --vpc "$VPC1" --policy /tmp/fw_policy.json

# ====== Peering ======
log "Creating peering between VPC1 and VPC2"
./vpcctl peer-vpcs --a "$VPC1" --b "$VPC2"

log "Testing peering connectivity"
ip netns exec ns-${VPC1}-${PUB1} ping -c 2 10.20.1.2 && echo "✅ Peering works"

# ====== Inspection ======
log "Inspecting VPC1 state"
./vpcctl inspect-vpc --name "$VPC1"

# ====== Cleanup ======
log "Tearing down all resources"
./vpcctl delete-vpc --name "$VPC1"
./vpcctl delete-vpc --name "$VPC2"

log "✅ Full test sequence completed"
