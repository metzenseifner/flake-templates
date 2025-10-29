# NixOS for iPad/UTM - Self-Contained Template

Fully automated, declarative NixOS installation for UTM SE on iPad. Just initialize and deploy!

## 🚀 Quick Start

### Method 1: Initialize on iPad (Via iSH or a-Shell)

If you have Nix installed on your iPad via iSH or a-Shell:

```bash
# Initialize the template
nix flake init -t github:metzenseifner/flake-templates#ipad

# Customize if needed (hostname, timezone, etc.)
vim configuration.nix

# Build disk image
nix build .#qcow

# Transfer result/nixos.qcow2 to UTM and import
```

### Method 2: Build on Mac/Linux, Transfer to iPad

```bash
# Initialize template
nix flake init -t github:metzenseifner/flake-templates#ipad

# Build bootable ISO
nix build .#iso

# Or build ready-to-use disk image
nix build .#qcow

# Transfer to iPad via AirDrop, iCloud, or cable
# Import into UTM
```

### Method 3: Boot from Live ISO and Auto-Install

```bash
# 1. Build ISO on your Mac/Linux:
nix build .#iso

# 2. Transfer to iPad and create VM in UTM:
#    - Boot from ISO
#    - Configuration is already in /etc/nixos/flake

# 3. In the live environment, run:
cd /etc/nixos/flake
sudo nix run .#install

# 4. Set password:
sudo nixos-enter --root /mnt
passwd nixos
exit

# 5. Reboot and remove ISO
```

## ✨ What's Included

### Automatic Configuration
- ✅ **Disk partitioning**: Automated with disko (GPT, EFI, ext4)
- ✅ **UTM optimization**: VirtIO drivers, QEMU guest agent
- ✅ **Networking**: DHCP, NetworkManager, SSH enabled
- ✅ **Clipboard sharing**: SPICE agent for copy/paste with iPad
- ✅ **ARM64 native**: Optimized for Apple Silicon

### Pre-configured Features
- SSH server (port 22) for terminal app access
- Passwordless sudo for convenience
- Essential development tools (git, vim, neovim, tmux)
- Automatic garbage collection
- Flakes enabled by default

### Optional Add-ons (Commented Out)
- Lightweight desktop (XFCE)
- VS Code Server for browser-based coding
- Additional development tools

## 📋 Files

- **flake.nix** - Main configuration with build targets
- **configuration.nix** - System configuration
- **disk-config.nix** - Declarative disk layout (disko)
- **README.md** - This file

## 🔧 Customization

### Change Hostname
```nix
# In configuration.nix
networking.hostName = "my-ipad-nixos";
```

### Set Timezone
```nix
# In configuration.nix
time.timeZone = "America/New_York";
```

### Add SSH Key for Passwordless Login
```nix
# In configuration.nix
users.users.nixos.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAAC3Nza... your-key"
];
```

### Add Packages
```nix
# In configuration.nix
environment.systemPackages = with pkgs; [
  # Your packages here
  nodejs
  python3
  rustc
];
```

### Enable Desktop Environment
```nix
# In configuration.nix, uncomment:
services.xserver = {
  enable = true;
  displayManager.lightdm.enable = true;
  desktopManager.xfce.enable = true;
  videoDrivers = [ "modesetting" ];
};
```

### Enable VS Code Server
```nix
# In configuration.nix, uncomment and configure:
services.code-server = {
  enable = true;
  auth = "password";
  host = "0.0.0.0";
  port = 8080;
};
# Then access via iPad browser at http://localhost:8080
```

## 🎯 Build Targets

### Build ISO Image
```bash
nix build .#iso
# Output: result/iso/nixos.iso
```

### Build QCOW2 Disk Image
```bash
nix build .#qcow
# Output: result/nixos.qcow2
```

### Build Raw Disk Image
```bash
nix build .#raw
# Output: result/nixos.img
```

### Run Auto-Installer (from live environment)
```bash
sudo nix run .#install
```

## 📱 Using on iPad

### Via SSH (Recommended)
1. Find VM IP: `ip addr show` in VM console
2. From iPad terminal app (Termius, Blink, etc.):
   ```bash
   ssh nixos@<vm-ip>
   ```

### Via UTM Console
Direct console access through UTM's built-in terminal.

### Via Browser (with VS Code Server)
1. Enable code-server in configuration.nix
2. Rebuild system
3. Access from iPad browser: `http://localhost:8080`

## 🔄 Updating System

After changing configuration:

```bash
# Rebuild and switch
sudo nixos-rebuild switch --flake .#ipad

# Or test without switching boot default
sudo nixos-rebuild test --flake .#ipad

# Update inputs
nix flake update
```

## 📦 VM Settings in UTM

### Recommended Settings
- **System**: QEMU
- **Architecture**: ARM64 (aarch64)
- **Boot**: UEFI
- **RAM**: 4-8 GB
- **Storage**: 20-50 GB
- **Network**: Shared Network
- **Display**: virtio-gpu-pci or virtio-ramfb-gl

### Performance Tips
1. Use **Virtualize** mode, not Emulate
2. Enable hardware OpenGL if available
3. Allocate multiple CPU cores
4. Use VirtIO for all devices

## 🔍 Troubleshooting

### ISO Won't Boot
- Ensure UEFI boot is enabled in UTM
- Check that you're using ARM64 ISO on ARM64 VM

### Disk Auto-Partition Fails
- Verify disk device name (usually /dev/vda in UTM)
- Check disk isn't already partitioned/mounted
- Edit disk-config.nix if needed

### Can't Connect via SSH
- Check VM IP: `ip addr show`
- Ensure shared network is enabled in UTM
- Check firewall: `sudo systemctl status firewall`

### Build Fails on iPad
- Ensure enough free space
- Check Nix installation: `nix --version`
- Update nixpkgs: `nix flake update`

## 🌟 Advanced Usage

### Build from Non-NixOS System
```bash
# On Mac with Nix installed:
nix build .#iso --system aarch64-linux
```

### Build in GitHub Actions
```yaml
- uses: cachix/install-nix-action@v20
- run: nix build .#iso
```

### Customize Disk Layout
Edit `disk-config.nix` to change partition sizes, add LVM, or use different filesystems.

### Add Secrets
Use `agenix` or `sops-nix` for managing secrets:
```nix
# Add to flake.nix inputs:
agenix.url = "github:ryantm/agenix";
```

## 📚 Resources

- [UTM Documentation](https://docs.getutm.app/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Disko Documentation](https://github.com/nix-community/disko)
- [Parent Template Repo](https://github.com/metzenseifner/flake-templates)

## 🤝 Contributing

Feel free to customize this template for your needs. To contribute back:

1. Fork the parent repository
2. Make your changes
3. Submit a pull request

## 📝 License

Same as parent repository.
