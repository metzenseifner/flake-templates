#!/usr/bin/env bash
set -euo pipefail
# ---- Config (override via env) ----
BOOTSTRAP_VM="${BOOTSTRAP_VM:-nix-bootstrap}"
BOOTSTRAP_IMAGE="${BOOTSTRAP_IMAGE:-ghcr.io/cirruslabs/ubuntu:22.04}"
# Cirrus Labs Tart Linux images default creds
BOOTSTRAP_USER="${BOOTSTRAP_USER:-admin}"
BOOTSTRAP_PASS="${BOOTSTRAP_PASS:-admin}" # admin/admin per Tart docs
BUILDER_AARCH64="${BUILDER_AARCH64:-builder-aarch64}"
BUILDER_ARM32="${BUILDER_ARM32:-builder-arm32}"
SSH_PUBKEY_FILE="${SSH_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}"
SSH_USER_ON_BUILDERS="${SSH_USER_ON_BUILDERS:-nixbuilder}"
# macOS nix.conf
NIX_CONF_PATH="${NIX_CONF_PATH:-/etc/nix/nix.conf}"
# Scheduling defaults (tune to your VM vCPU count)
AARCH64_MAX_JOBS="${AARCH64_MAX_JOBS:-10}"
AARCH64_SPEED="${AARCH64_SPEED:-2}"
ARM32_MAX_JOBS="${ARM32_MAX_JOBS:-2}"
ARM32_SPEED="${ARM32_SPEED:-0.5}"
# -----------------------------------
require() { command -v "$1" >/dev/null 2>&1 || {
  echo "Missing command: $1" >&2
  exit 1
}; }
require tart
require ssh
require scp
require tar
require sudo
require sshpass
if [[ ! -f "$SSH_PUBKEY_FILE" ]]; then
  echo "Missing SSH public key: $SSH_PUBKEY_FILE" >&2
  exit 1
fi
PUBKEY="$(cat "$SSH_PUBKEY_FILE")"
tart_has_vm() { tart list | grep -qx "$1"; }
tart_is_running() { tart ps | awk '{print $1}' | grep -qx "$1"; }
ensure_vm_exists() {
  local name="$1" image="$2"
  if ! tart_has_vm "$name"; then
    echo "Creating Tart VM: $name from $image"
    tart clone "$image" "$name"
  fi
}
start_vm_bg() {
  local name="$1"
  if ! tart_is_running "$name"; then
    echo "Starting VM: $name"
    # Tart runs in foreground; background it.
    tart run "$name" >/dev/null 2>&1 &
    sleep 2
  fi
}
wait_for_ip() {
  local name="$1"
  local ip=""
  for _ in {1..180}; do
    ip="$(tart ip "$name" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
    sleep 1
  done
  echo "Failed to get IP for VM: $name" >&2
  exit 1
}
ssh_bootstrap_pw() {
  local ip="$1"
  shift
  sshpass -p "$BOOTSTRAP_PASS" ssh
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  "$BOOTSTRAP_USER@$ip" "$@"
}
scp_bootstrap_from_pw() {
  local ip="$1" remote="$2" localpath="$3"
  sshpass -p "$BOOTSTRAP_PASS" scp
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  "$BOOTSTRAP_USER@$ip:$remote" "$localpath"
}
# After we install the SSH key into bootstrap, prefer key-based access (faster, safer)
ssh_bootstrap_key() {
  local ip="$1"
  shift
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  "$BOOTSTRAP_USER@$ip" "$@"
}
scp_bootstrap_from_key() {
  local ip="$1" remote="$2" localpath="$3"
  scp -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  "$BOOTSTRAP_USER@$ip:$remote" "$localpath"
}
bootstrap_has_key_auth() {
  local ip="$1"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  "$BOOTSTRAP_USER@$ip" "true" >/dev/null 2>&1
}
install_key_on_bootstrap() {
  local ip="$1"
  echo "Installing SSH key on bootstrap VM (so no passwords needed afterwards)..."
  ssh_bootstrap_pw "$ip" "set -euo pipefail
    umask 077
    mkdir -p ~/.ssh
    touch ~/.ssh/authorized_keys
    grep -qxF '$(printf "%s" "$PUBKEY")' ~/.ssh/authorized_keys || echo '$(printf "%s" "$PUBKEY")' >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
  "
}
# ---- 1) Bring up bootstrap VM ----
ensure_vm_exists "$BOOTSTRAP_VM" "$BOOTSTRAP_IMAGE"
start_vm_bg "$BOOTSTRAP_VM"
BOOTSTRAP_IP="$(wait_for_ip "$BOOTSTRAP_VM")"
echo "Bootstrap VM IP: $BOOTSTRAP_IP"
# ---- 2) Ensure we can do non-interactive SSH for the rest of the run ----
if ! bootstrap_has_key_auth "$BOOTSTRAP_IP"; then
  install_key_on_bootstrap "$BOOTSTRAP_IP"
fi
# From here on: key-based SSH (no prompts)
echo "Ensuring Nix is installed in bootstrap VM..."
ssh_bootstrap_key "$BOOTSTRAP_IP" 'set -euo pipefail
  sudo apt-get update
  sudo apt-get install -y curl xz-utils ca-certificates
  if ! command -v nix >/dev/null 2>&1; then
    curl -L https://nixos.org/nix/install | sh -s -- --daemon
  fi
  if ! grep -q "^experimental-features = .*flakes" /etc/nix/nix.conf 2>/dev/null; then
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
  fi
  sudo systemctl restart nix-daemon
'
# ---- 3) Send repo to bootstrap VM ----
echo "Sending repo to bootstrap VM..."
tar -cz . | ssh_bootstrap_key "$BOOTSTRAP_IP"
"rm -rf ~/builder-repo && mkdir -p ~/builder-repo && tar -xz -C ~/builder-repo"
# ---- 4) Build NixOS disk images inside bootstrap VM ----
echo "Building NixOS builder disk images inside bootstrap VM..."
ssh_bootstrap_key "$BOOTSTRAP_IP" "set -euo pipefail
  cd ~/builder-repo
  export BUILDER_SSH_PUBKEY=\"$(printf '%s' "$PUBKEY")\"
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  # Build sequentially (safe). You can parallelize later if you want.
  nix build --impure .#tartDisk-aarch64
  cp \$(readlink -f result) ~/builder-aarch64.img
  rm -f result
  nix build --impure .#tartDisk-arm32
  cp \$(readlink -f result) ~/builder-arm32.img
  rm -f result
"
# ---- 5) Create builder VMs (placeholders), then replace disk.img ----
ensure_vm_exists "$BUILDER_AARCH64" "$BOOTSTRAP_IMAGE"
ensure_vm_exists "$BUILDER_ARM32" "$BOOTSTRAP_IMAGE"
tart stop "$BUILDER_AARCH64" >/dev/null 2>&1 || true
tart stop "$BUILDER_ARM32" >/dev/null 2>&1 || true
DISK_A="$HOME/.tart/vms/$BUILDER_AARCH64/disk.img"
DISK_B="$HOME/.tart/vms/$BUILDER_ARM32/disk.img"
echo "Replacing Tart disks with NixOS images..."
scp_bootstrap_from_key "$BOOTSTRAP_IP" "~/builder-aarch64.img" "$DISK_A"
scp_bootstrap_from_key "$BOOTSTRAP_IP" "~/builder-arm32.img" "$DISK_B"
# ---- 6) Start builders and get IPs ----
start_vm_bg "$BUILDER_AARCH64"
start_vm_bg "$BUILDER_ARM32"
IP_A="$(wait_for_ip "$BUILDER_AARCH64")"
IP_B="$(wait_for_ip "$BUILDER_ARM32")"
echo "Builder IPs:"
echo "  $BUILDER_AARCH64 -> $IP_A"
echo "  $BUILDER_ARM32   -> $IP_B"
# ---- 7) Configure macOS nix.conf builders ----
echo "Updating $NIX_CONF_PATH"
sudo tee "$NIX_CONF_PATH" >/dev/null <<EOF
builders = ssh-ng://$SSH_USER_ON_BUILDERS@$IP_A aarch64-linux - $AARCH64_MAX_JOBS $AARCH64_SPEED ssh-ng://$SSH_USER_ON_BUILDERS@$IP_B armv6l-linux,armv7l-linux - $ARM32_MAX_JOBS $ARM32_SPEED
builders-use-substitutes = true
EOF
sudo launchctl kickstart -k system/org.nixos.nix-daemon
echo "Done."
