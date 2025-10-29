# Installing NixOS on UTM SE (iPad)

Yes! This template works on UTM SE on iPad. Here's how to use it.

## Architecture Considerations

UTM SE on iPad can run in two modes:

### 1. Apple Virtualization Framework (Recommended)
- **Architecture**: ARM64 (aarch64-linux)
- **Performance**: Native speed (near-native)
- **Use**: `nixos-aarch64` configuration
- **Requires**: iPad with Apple Silicon (M1/M2 chip) or newer iOS devices
- **Best for**: Primary use, development, daily tasks

### 2. QEMU Emulation
- **Architecture**: Can emulate x86_64 or other architectures
- **Performance**: Slower (emulated, not virtualized)
- **Use**: `nixos-x86_64` configuration (but will be slow)
- **Best for**: Testing x86 compatibility, not daily use

## Installation Methods for UTM SE

### Method 1: Create VM and Bootstrap (Recommended)

This is the best approach for UTM SE on iPad.

#### Step 1: Create Empty VM in UTM SE

1. Open UTM SE on your iPad
2. Create New VM → **Virtualize** (not Emulate)
3. Choose **Linux**
4. Configuration:
   - **Architecture**: ARM64 (for Apple Virtualization)
   - **RAM**: 2-4 GB minimum (more is better)
   - **Storage**: 20+ GB
   - **Boot**: UEFI
   - **Network**: Shared Network
   - Skip ISO selection for now

#### Step 2: Download NixOS ARM64 ISO

On your iPad, download:
```
https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-aarch64-linux.iso
```

Or use the graphical ISO for easier setup:
```
https://channels.nixos.org/nixos-unstable/latest-nixos-gnome-aarch64-linux.iso
```

#### Step 3: Attach ISO and Boot

1. In UTM, edit your VM
2. Add CD/DVD drive with the ISO
3. Boot the VM
4. You'll boot into NixOS live environment

#### Step 4: Install Using This Template

Once booted into live NixOS:

```bash
# Connect to WiFi (if needed)
nmcli device wifi connect "YourSSID" password "YourPassword"

# Partition the virtual disk
sudo parted /dev/vda -- mklabel gpt
sudo parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/vda -- set 1 esp on
sudo parted /dev/vda -- mkpart primary 512MiB 100%

sudo mkfs.fat -F 32 -n boot /dev/vda1
sudo mkfs.ext4 -L nixos /dev/vda2

sudo mount /dev/vda2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/vda1 /mnt/boot

# Generate hardware config
sudo nixos-generate-config --root /mnt

# Get this flake (multiple options):

# Option A: If you have it in iCloud/Files:
# Copy your flake config to /mnt/etc/nixos/

# Option B: Clone from GitHub:
nix-shell -p git
git clone https://github.com/yourusername/nixos-config /mnt/etc/nixos/flake
cd /mnt/etc/nixos/flake

# Option C: Create minimal config directly:
cd /mnt/etc/nixos
# Copy the flake files manually

# Copy hardware config
sudo cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/flake/

# Edit configuration.nix to uncomment:
# imports = [ ./hardware-configuration.nix ];

# Install (use aarch64 config!)
sudo nixos-install --flake .#nixos-aarch64

# Set password
sudo nixos-enter --root /mnt
passwd
exit

# Reboot
sudo reboot
```

#### Step 5: Remove ISO and Boot

1. Shutdown the VM
2. Remove the ISO from the CD/DVD drive
3. Boot the VM
4. You now have NixOS running!

### Method 2: Pre-built NixOS Image

Download a pre-built NixOS ARM64 disk image and import it into UTM.

1. On a Mac/Linux system with Nix:
```bash
# Build bootable image
nix build .#nixosConfigurations.nixos-aarch64.config.system.build.virtualBoxImage
# or
nix build .#nixosConfigurations.nixos-aarch64.config.system.build.qcow
```

2. Transfer the image to your iPad (via Files app, iCloud, Airdrop)
3. Import into UTM as existing disk

## iPad-Specific Configuration

Edit `configuration.nix` for better iPad/UTM experience:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network
  networking = {
    hostName = "nixos-ipad";
    networkmanager.enable = true;
  };

  # For UTM virtio-gpu
  services.xserver = {
    enable = true;
    videoDrivers = [ "modesetting" ];
    desktopManager.gnome.enable = true;  # or your preferred DE
  };

  # Better for touch/tablet use
  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  # Clipboard sharing with iPad (via SPICE)
  services.spice-vdagentd.enable = true;

  # File sharing
  services.samba.enable = true;  # Optional: share files with iPad

  # User
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  # Essential packages for VM
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    # For clipboard sharing
    spice-vdagent
  ];

  # SSH for remote access from iPad
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  system.stateVersion = "24.11";
}
```

## Performance Tips

1. **Use ARM64 virtualization** (not x86 emulation) - 10-100x faster
2. **Allocate sufficient RAM** - 4GB minimum, 8GB+ ideal
3. **Enable 3D acceleration** in UTM settings if available
4. **Use VirtIO drivers** for better disk/network performance (auto in UTM)
5. **Console-only install** - Skip GUI for lighter resource usage

## Accessing Your NixOS VM

### SSH Access (Recommended)
From iPad terminal apps (like Termius, Blink, Working Copy):

```bash
# Find VM IP in UTM or in the VM:
# ip addr show

ssh nixos@<vm-ip>
```

### Direct Console
Use UTM's built-in console interface.

### VNC/Display
Enable remote desktop and connect from iPad VNC client for GUI.

## Limitations on iPad

1. **No nested virtualization** - Can't run Docker/VMs inside the VM
2. **Background limitations** - iOS may pause VM when app backgrounded
3. **Storage** - Limited by iPad storage
4. **No host folder sharing** (yet) - Use SFTP/Samba instead
5. **Network** - Shared network mode only (no bridging)

## Working Around Limitations

### File Transfer
```bash
# Install on NixOS VM:
services.openssh.enable = true;

# From iPad, use apps like:
# - Termius (SFTP built-in)
# - Working Copy (Git + SSH)
# - Documents by Readdle (SMB/SFTP)
```

### Code Editing
- **Option 1**: SSH + terminal editor (vim/neovim)
- **Option 2**: VS Code Server in VM, access via browser
- **Option 3**: Use Working Copy app → SSH → edit on iPad

### Persistent Running
Keep UTM app open or in foreground for VM to run continuously.

## Quick Start Summary

1. **Create ARM64 VM** in UTM SE (not emulated)
2. **Boot NixOS ARM64 ISO**
3. **Use `nixos-aarch64` config** from this template
4. **Install normally** following Method 5 in BOOTSTRAP.md
5. **Enable SSH** for easier access from iPad
6. **Enjoy NixOS** on your iPad!

## Resources

- [UTM Documentation](https://docs.getutm.app/)
- [NixOS ARM Downloads](https://nixos.org/download#nixos-iso)
- [This template's README](./README.md)
- [Bootstrap Guide](./BOOTSTRAP.md)

## Troubleshooting

**VM won't boot**: Ensure UEFI is enabled, not BIOS
**Slow performance**: Make sure using Virtualize, not Emulate
**No network**: Select "Shared Network" mode in UTM
**Can't install**: Verify you're using ARM64 ISO and aarch64 config
**Display issues**: Try switching between QEMU and virtio-gpu

## Example: Minimal Console-Only Setup

For best iPad performance, skip GUI:

```nix
# In configuration.nix - console only
{
  boot.loader.systemd-boot.enable = true;
  networking.hostName = "nixos-ipad";
  services.openssh.enable = true;
  # No desktop environment - just console
  # Access via SSH from iPad
}
```

Then SSH from iPad terminal app for a fast, efficient NixOS environment!
