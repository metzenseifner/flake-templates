# Quick Start: Bootstrap NixOS

Choose your bootstrap method based on your scenario:

## 🚀 Method 1: Remote Install with nixos-anywhere (Fastest)

**Best for:** VPS, remote servers, or existing Linux installations you can SSH into

```bash
# 1. Edit disk-config.nix to match your target disk
# 2. Run from your local machine:
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixos-x86_64 \
  root@target-host
```

**That's it!** The tool handles everything: partitioning, installation, and reboot.

## 🔄 Method 2: Convert Existing System with nixos-infect

**Best for:** Converting existing Debian/Ubuntu/etc to NixOS in-place

```bash
# On the target system:
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
  NIX_CHANNEL=nixos-unstable bash

# After reboot, deploy your config:
git clone <your-repo> /etc/nixos/config
cd /etc/nixos/config
sudo nixos-rebuild switch --flake .#nixos-x86_64
```

⚠️ **Backs up data but reformats system - have backups!**

## 💾 Method 3: Manual Install to New Partition

**Best for:** Dual-boot or careful migration

```bash
# 1. Install Nix on existing system
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# 2. Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# 3. Prepare partition
sudo mkfs.ext4 /dev/sdX  # Your target partition
sudo mount /dev/sdX /mnt

# 4. Generate hardware config
sudo nixos-generate-config --root /mnt

# 5. Install with your flake
git clone <your-repo> /tmp/config
cd /tmp/config
sudo cp /mnt/etc/nixos/hardware-configuration.nix .
# Uncomment imports = [ ./hardware-configuration.nix ]; in configuration.nix
sudo nixos-install --flake .#nixos-x86_64 --root /mnt

# 6. Set password and reboot
sudo nixos-enter --root /mnt
passwd
exit
sudo reboot
```

## 🏗️ Method 4: From NixOS Live USB

**Best for:** Clean installation on bare metal

```bash
# 1. Boot NixOS live USB
# 2. Partition disks (example):
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary 512MiB 100%
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot

# 3. Clone config
git clone <your-repo> /mnt/etc/nixos/config
cd /mnt/etc/nixos/config

# 4. Generate hardware config
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix .

# 5. Install
nixos-install --flake .#nixos-x86_64

# 6. Reboot
reboot
```

## 📋 Before You Start

1. **Choose your architecture:**
   - `nixos-x86_64` for Intel/AMD systems
   - `nixos-aarch64` for ARM64 systems

2. **For nixos-anywhere method:**
   - Ensure SSH is enabled on target: `systemctl start sshd`
   - Copy SSH key: `ssh-copy-id root@target-host`
   - Edit `disk-config.nix` to match target disk

3. **Customize first:**
   - Set hostname in `configuration.nix`
   - Update timezone
   - Change default password!
   - Add your SSH keys

## 🔧 After Installation

```bash
# Update flake inputs
nix flake update

# Rebuild system
sudo nixos-rebuild switch --flake .#nixos-x86_64

# Test configuration
sudo nixos-rebuild test --flake .#nixos-x86_64
```

## ❓ Troubleshooting

**Can't SSH to target:** Check firewall, verify SSH is running
**Disk errors:** Verify device name with `lsblk`
**Boot issues:** Check EFI/BIOS settings, verify bootloader config
**Flake errors:** Run `nix flake check` to validate syntax

See [BOOTSTRAP.md](./BOOTSTRAP.md) for detailed instructions and troubleshooting.
