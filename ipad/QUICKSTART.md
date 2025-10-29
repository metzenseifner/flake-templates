# Quick Start: iPad NixOS Template

The fastest way to get NixOS running on UTM SE on your iPad.

## 🎯 One-Command Setup

**Replacing Ubuntu or another Linux VM?** See [REPLACE-UBUNTU.md](./REPLACE-UBUNTU.md) for specific instructions.

### On Your Mac/Linux Machine

```bash
# Initialize from template
nix flake init -t github:metzenseifner/flake-templates#ipad

# Build bootable ISO
nix build .#iso

# Transfer result/iso/nixos.iso to your iPad
# (via AirDrop, iCloud Drive, or cable)
```

### In UTM on iPad

1. **Create New VM**
   - Tap **Virtualize** (not Emulate)
   - Choose **Linux**
   - Select **ARM64** architecture
   - Set RAM: 4-8 GB
   - Set Storage: 20+ GB
   - Enable UEFI boot
   - Attach the ISO you built

2. **Boot and Install**
   ```bash
   # The ISO has your config in /etc/nixos/flake
   cd /etc/nixos/flake
   
   # Run automated installer
   sudo nix run .#install
   
   # Set password
   sudo nixos-enter --root /mnt
   passwd nixos
   exit
   
   # Reboot
   sudo reboot
   ```

3. **Remove ISO and Boot**
   - Shutdown VM
   - Remove ISO from UTM
   - Start VM
   - You're running NixOS! 🎉

## 🔧 What Gets Installed

- **Console-only system** (lightweight, fast)
- **SSH server** on boot
- **Essential tools**: vim, git, tmux, htop
- **Clipboard sharing** with iPad
- **Automatic disk partitioning**
- **Optimized for UTM** (VirtIO drivers)

## 📱 Access Your System

### From iPad Terminal (Recommended)

```bash
# Find IP in VM console
ip addr show

# SSH from iPad (Termius, Blink, etc.)
ssh nixos@<vm-ip>
```

Default password: `nixos` (change it!)

## ⚡ Customize Before Building

### Edit Hostname
```nix
# In configuration.nix
networking.hostName = "my-nixos";
```

### Add Your SSH Key
```nix
# In configuration.nix
users.users.nixos.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3... your-key"
];
```

### Enable Desktop Environment
```nix
# In configuration.nix, uncomment:
services.xserver.enable = true;
services.xserver.displayManager.lightdm.enable = true;
services.xserver.desktopManager.xfce.enable = true;
```

### Add Packages
```nix
# In configuration.nix
environment.systemPackages = with pkgs; [
  # Add your tools
  nodejs
  python3
  cargo
];
```

## 🚀 Alternative: Pre-built VM Image

If you don't need an ISO:

```bash
# Build VM image directly
nix build .#default

# Transfer to iPad and import into UTM
```

## 🔄 Update Your System

After booting into NixOS:

```bash
# Make changes to configuration.nix
vim /etc/nixos/flake/configuration.nix

# Rebuild system
sudo nixos-rebuild switch --flake /etc/nixos/flake#ipad

# Update packages
nix flake update
```

## 💡 Pro Tips

1. **Passwordless sudo** is enabled by default for convenience
2. **Automatic garbage collection** runs weekly to save space
3. **Clipboard sharing** works via SPICE agent
4. **SSH** is exposed on port 22 for terminal access
5. **Flakes** are enabled by default

## ❓ Common Issues

**Can't build on iPad directly**: Build on Mac/Linux, transfer ISO
**ISO won't boot**: Ensure UEFI is enabled in UTM
**Slow performance**: Use Virtualize mode, not Emulate
**Can't find VM IP**: Check UTM network is set to "Shared"

## 📚 More Info

See [README.md](./README.md) for detailed documentation.

## 🎁 What This Template Does

- ✅ Automated disk partitioning (disko)
- ✅ UTM-optimized configuration
- ✅ Self-contained ISO with config included
- ✅ One-command installation
- ✅ Development-ready environment
- ✅ iPad workflow optimized

**You just `nix flake init` and go!** 🚀
