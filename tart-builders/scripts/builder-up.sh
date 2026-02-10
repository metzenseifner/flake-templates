#!/usr/bin/env bash
set -euo pipefail

# ---------- Config ----------
VM_AARCH64="${VM_AARCH64:-builder-aarch64}"
VM_ARM32="${VM_ARM32:-builder-arm32}"

# Flake targets that produce raw UEFI disk images (make-disk-image output)
NIX_TARGET_AARCH64="${NIX_TARGET_AARCH64:-.#packages.aarch64-linux.tartDisk-aarch64}"
NIX_TARGET_ARM32="${NIX_TARGET_ARM32:-.#packages.aarch64-linux.tartDisk-arm32}"

# Docker image with nix installed (pin digest if you want)
NIX_DOCKER_IMAGE="${NIX_DOCKER_IMAGE:-nixos/nix:2.22.1}"

# Persist Nix store across runs
NIX_STORE_VOLUME="${NIX_STORE_VOLUME:-nix-store}"

# SSH key used to access the builders (injected into flake via env var)
SSH_PUBKEY_FILE="${SSH_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}"
SSH_USER="${SSH_USER:-nixbuilder}"

# macOS nix.conf path
NIX_CONF_PATH="${NIX_CONF_PATH:-/etc/nix/nix.conf}"

# Scheduling
AARCH64_MAX_JOBS="${AARCH64_MAX_JOBS:-10}"
AARCH64_SPEED="${AARCH64_SPEED:-2}"
ARM32_MAX_JOBS="${ARM32_MAX_JOBS:-2}"
ARM32_SPEED="${ARM32_SPEED:-0.5}"
# ---------------------------

require() { command -v "$1" >/dev/null 2>&1 || {
  echo "Missing command: $1" >&2
  exit 1
}; }
require docker
require tart
require sudo
require ssh

if [[ ! -f "$SSH_PUBKEY_FILE" ]]; then
  echo "Missing SSH public key: $SSH_PUBKEY_FILE" >&2
  exit 1
fi
BUILDER_SSH_PUBKEY="$(tr -d '\n' <"$SSH_PUBKEY_FILE")"
if [[ -z "$BUILDER_SSH_PUBKEY" ]]; then
  echo "SSH public key file is empty: $SSH_PUBKEY_FILE" >&2
  exit 1
fi

tart_has_vm() { tart list | grep -qx "$1"; }
tart_is_running() { tart ps | awk '{print $1}' | grep -qx "$1"; }

ensure_tart_vm_shell() {
  local name="$1"
  if ! tart_has_vm "$name"; then
    # Creates ~/.tart/vms/<name>/disk.img etc.
    tart create --linux "$name"
  fi
}

stop_vm() {
  local name="$1"
  tart stop "$name" >/dev/null 2>&1 || true
}

start_vm_bg() {
  local name="$1"
  if ! tart_is_running "$name"; then
    tart run "$name" >/dev/null 2>&1 &
    sleep 2
  fi
}

wait_for_ip() {
  local name="$1"
  local ip=""
  for _ in {1..180}; do
    ip="$(tart ip "$name" 2>/dev/null || true)"
    [[ -n "$ip" ]] && {
      echo "$ip"
      return 0
    }
    sleep 1
  done
  echo "Failed to get IP for VM: $name" >&2
  exit 1
}

disk_path() {
  local name="$1"
  echo "$HOME/.tart/vms/$name/disk.img"
}

docker_build_target_to() {
  local target="$1"
  local outpath="$2"

  rm -f /tmp/nix-outpaths.txt

  # Build inside Linux/arm64. --privileged is needed for loop/mount during disk-image creation.
  docker run --rm --privileged \
    --platform=linux/arm64 \
    -e "BUILDER_SSH_PUBKEY=$BUILDER_SSH_PUBKEY" \
    -v "$PWD:/src" \
    -v "${NIX_STORE_VOLUME}:/nix" \
    -w /src \
    "$NIX_DOCKER_IMAGE" \
    sh -lc \
    'nix --extra-experimental-features "nix-command flakes" \
build --impure '"$target"' --print-out-paths' \
    /tmp/nix-outpaths.txt

  local storepath
  storepath="$(tail -n 1 /tmp/nix-outpaths.txt | tr -d '\r')"
  if [[ -z "$storepath" ]]; then
    echo "Failed to get store path for target: $target" >&2
    exit 1
  fi

  # Copy the resulting artifact out to the repo directory
  docker run --rm \
    --platform=linux/arm64 \
    -v "${NIX_STORE_VOLUME}:/nix" \
    -v "$PWD:/dst" \
    "$NIX_DOCKER_IMAGE" \
    sh -lc "cp -f '$storepath' '/dst/$outpath'"

  [[ -f "$outpath" ]] || {
    echo "Expected output file not found: $outpath" >&2
    exit 1
  }
}

echo "1) Building NixOS disk images via Docker (impure key injection)..."
docker_build_target_to "$NIX_TARGET_AARCH64" "builder-aarch64.img"
docker_build_target_to "$NIX_TARGET_ARM32" "builder-arm32.img"

echo "2) Creating Tart VM shells..."
ensure_tart_vm_shell "$VM_AARCH64"
ensure_tart_vm_shell "$VM_ARM32"

echo "3) Stopping VMs before disk swap..."
stop_vm "$VM_AARCH64"
stop_vm "$VM_ARM32"

echo "4) Installing disk images into Tart VMs..."
cp -f "builder-aarch64.img" "$(disk_path "$VM_AARCH64")"
cp -f "builder-arm32.img" "$(disk_path "$VM_ARM32")"

echo "5) Booting builder VMs..."
start_vm_bg "$VM_AARCH64"
start_vm_bg "$VM_ARM32"

IP_A="$(wait_for_ip "$VM_AARCH64")"
IP_B="$(wait_for_ip "$VM_ARM32")"
echo "Builder IPs:"
echo " $VM_AARCH64 -> $IP_A"
echo " $VM_ARM32 -> $IP_B"

echo "6) Verifying SSH (key-based) works..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$IP_A" "true"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$IP_B" "true"

echo "7) Writing macOS remote builder config..."
sudo tee "$NIX_CONF_PATH" >/dev/null <<EOF
builders = ssh-ng://$SSH_USER@$IP_A aarch64-linux - $AARCH64_MAX_JOBS $AARCH64_SPEED ssh-ng://$SSH_USER@$IP_B armv6l-linux,armv7l-linux - $ARM32_MAX_JOBS $ARM32_SPEED
builders-use-substitutes = true
EOF

sudo launchctl kickstart -k system/org.nixos.nix-daemon
echo "Done."
