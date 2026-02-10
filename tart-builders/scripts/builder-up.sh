#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_VM="nix-bootstrap"
BOOTSTRAP_IMAGE="ghcr.io/cirruslabs/ubuntu:22.04"

BUILDER_AARCH64="builder-aarch64"
BUILDER_ARM32="builder-arm32"

SSH_PUBKEY_FILE="${SSH_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}"
SSH_USER="nixbuilder"

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }; }
require tart
require ssh
require scp
require sudo

if [[ ! -f "$SSH_PUBKEY_FILE" ]]; then
echo "Missing SSH public key: $SSH_PUBKEY_FILE" >&2
exit 1
fi
PUBKEY="$(cat "$SSH_PUBKEY_FILE")"

ensure_vm_running() {
local name="$1" image="$2"
if ! tart list | grep -qx "$name"; then
tart clone "$image" "$name"
fi
if ! tart ps | awk '{print $1}' | grep -qx "$name"; then
tart run "$name" --detach
fi
}

wait_for_ip() {
local name="$1"
local ip=""
for _ in {1..60}; do
ip="$(tart ip "$name" 2>/dev/null || true)"
[[ -n "$ip" ]] && { echo "$ip"; return; }
sleep 1
done
echo "Failed to get IP for $name" >&2
exit 1
}

# 1) Bootstrap VM (Ubuntu) to build the NixOS disk images (aarch64-linux)
ensure_vm_running "$BOOTSTRAP_VM" "$BOOTSTRAP_IMAGE"
BOOTSTRAP_IP="$(wait_for_ip "$BOOTSTRAP_VM")"

echo "Bootstrap VM IP: $BOOTSTRAP_IP"

# 2) Ensure bootstrap has Nix (daemon) + flakes enabled
ssh -o StrictHostKeyChecking=no ubuntu@"$BOOTSTRAP_IP" <<'EOF'
set -euo pipefail
sudo apt-get update
sudo apt-get install -y curl xz-utils
if ! command -v nix >/dev/null 2>&1; then
curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi
if ! grep -q "experimental-features" /etc/nix/nix.conf 2>/dev/null; then
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
fi
sudo systemctl restart nix-daemon
EOF

# 3) Copy this repo into bootstrap (so it can run nix build there)
# Uses tar over ssh to avoid rsync dependency.
echo "Sending repo to bootstrap VM..."
tar -cz . | ssh ubuntu@"$BOOTSTRAP_IP" "rm -rf ~/builder-repo && mkdir -p ~/builder-repo && tar -xz -C ~/builder-repo"

# 4) Build NixOS disk images inside bootstrap VM (impure so pubkey is embedded)
echo "Building NixOS builder disks..."
ssh ubuntu@"$BOOTSTRAP_IP" <<EOF
set -euo pipefail
cd ~/builder-repo
export BUILDER_SSH_PUBKEY="$(printf '%s' "$PUBKEY")"
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

nix build --impure .#tartDisk-aarch64
nix build --impure .#tartDisk-arm32

# Copy results to predictable paths
A=\$(readlink -f result)
cp "\$A" ~/builder-aarch64.img
rm -f result

B=\$(readlink -f result)
cp "\$B" ~/builder-arm32.img
rm -f result
EOF

# 5) Create Tart VMs (empty) if missing, then replace their disk.img
ensure_vm_running "$BUILDER_AARCH64" "$BOOTSTRAP_IMAGE"
ensure_vm_running "$BUILDER_ARM32" "$BOOTSTRAP_IMAGE"

# Stop them so we can replace disk safely
tart stop "$BUILDER_AARCH64" || true
tart stop "$BUILDER_ARM32" || true

DISK_A="$HOME/.tart/vms/$BUILDER_AARCH64/disk.img"
DISK_B="$HOME/.tart/vms/$BUILDER_ARM32/disk.img"

echo "Replacing Tart disks..."
scp ubuntu@"$BOOTSTRAP_IP":~/builder-aarch64.img "$DISK_A"
scp ubuntu@"$BOOTSTRAP_IP":~/builder-arm32.img "$DISK_B"

# 6) Start NixOS builder VMs
tart run "$BUILDER_AARCH64" --detach
tart run "$BUILDER_ARM32" --detach

IP_A="$(wait_for_ip "$BUILDER_AARCH64")"
IP_B="$(wait_for_ip "$BUILDER_ARM32")"

echo "Builder IPs:"
echo " $BUILDER_AARCH64 -> $IP_A"
echo " $BUILDER_ARM32 -> $IP_B"

# 7) Update macOS nix.conf builders and restart nix-daemon
sudo tee /etc/nix/nix.conf >/dev/null <<EOF
builders = ssh-ng://$SSH_USER@$IP_A aarch64-linux - 8 1 ssh-ng://$SSH_USER@$IP_B armv6l-linux,armv7l-linux - 4 1
builders-use-substitutes = true
EOF

sudo launchctl kickstart -k system/org.nixos.nix-daemon

echo "Done. Remote builders configured."
