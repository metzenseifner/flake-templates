# Bootstrapping NixOS from Another Linux Distribution

This guide explains how to install NixOS on a system currently running another Linux distribution (Ubuntu, Debian, Arch, etc.) without installation media.

## Method 1: Using nixos-anywhere (Recommended)

The easiest method using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere).

### Prerequisites
- SSH access to the target machine
- Root or sudo access on target
- Nix installed on your local machine

### Steps

1. **On your local machine, add nixos-anywhere to this flake:**

```bash
# Already prepared in flake.nix - just run:
nix run github:nix-community/nixos-anywhere -- --flake .#nixos-x86_64 root@target-host
```

2. **The tool will:**
   - Connect via SSH
   - Partition disks (requires disko configuration)
   - Install NixOS
   - Reboot into NixOS

### Required: Add Disko Configuration

Create `disk-config.nix`:

```nix
{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";  # Change to your disk
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
```

Add to your configuration imports in `flake.nix`.

## Method 2: Manual Bootstrap with nixos-infect

Use the [nixos-infect](https://github.com/elitak/nixos-infect) script to convert existing system.

### Steps

1. **On the target machine:**

```bash
# Install curl if not present
sudo apt-get install -y curl  # Debian/Ubuntu
# or
sudo yum install -y curl      # RHEL/CentOS
# or
sudo pacman -S curl           # Arch

# Download and run nixos-infect
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-unstable bash
```

2. **After reboot, clone this configuration:**

```bash
nix-shell -p git
git clone <your-repo> /etc/nixos/flake
cd /etc/nixos/flake
sudo nixos-rebuild switch --flake .#nixos-x86_64
```

⚠️ **Warning:** This method reformats your system. Backup data first!

## Method 3: NixOS Installation in Existing Partition

Install NixOS alongside existing OS without losing data.

### Prerequisites
- Free disk partition (or resize existing)
- Root access on current system

### Steps

1. **Install Nix on current system:**

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
source /etc/profile.d/nix.sh
```

2. **Enable flakes:**

```bash
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << EOF
experimental-features = nix-command flakes
EOF
```

3. **Prepare target partition:**

```bash
# Identify partition (e.g., /dev/sda2)
lsblk

# Format partition
sudo mkfs.ext4 /dev/sda2

# Mount it
sudo mkdir -p /mnt
sudo mount /dev/sda2 /mnt
```

4. **Bootstrap NixOS:**

```bash
# Clone this configuration
git clone <your-repo> /tmp/nixos-config
cd /tmp/nixos-config

# Generate hardware config
sudo nixos-generate-config --root /mnt

# Copy hardware config to your flake
sudo cp /mnt/etc/nixos/hardware-configuration.nix .

# Uncomment the import in configuration.nix
# imports = [ ./hardware-configuration.nix ];

# Install NixOS
sudo nixos-install --flake .#nixos-x86_64 --root /mnt
```

5. **Set root password:**

```bash
sudo nixos-enter --root /mnt
passwd
exit
```

6. **Setup bootloader:**

Update GRUB/systemd-boot to add NixOS entry, then reboot.

## Method 4: Docker/Container Bootstrap

Test and prepare NixOS configuration in a container first.

### Steps

1. **Run NixOS container:**

```bash
docker run -it -v $(pwd):/config nixos/nix
```

2. **Inside container:**

```bash
cd /config
nix build .#nixosConfigurations.nixos-x86_64.config.system.build.toplevel
```

3. **Once satisfied, use Method 1, 2, or 3 for actual installation**

## Method 5: Live USB with Flake Config

Boot from NixOS live USB but use this flake configuration.

### Steps

1. **Boot NixOS live USB**

2. **Connect to network:**

```bash
# WiFi
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "YourSSID"
> set_network 0 psk "YourPassword"
> enable_network 0
> quit

# Or use NetworkManager
nmcli device wifi connect "YourSSID" password "YourPassword"
```

3. **Partition disks:**

```bash
# Example for simple single-disk setup
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart primary 512MiB 100%

sudo mkfs.fat -F 32 -n boot /dev/sda1
sudo mkfs.ext4 -L nixos /dev/sda2

sudo mount /dev/sda2 /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/sda1 /mnt/boot
```

4. **Generate hardware config:**

```bash
sudo nixos-generate-config --root /mnt
```

5. **Use your flake:**

```bash
# Clone your flake repo
nix-shell -p git
git clone <your-repo> /mnt/etc/nixos/flake
cd /mnt/etc/nixos/flake

# Copy hardware config
sudo cp /mnt/etc/nixos/hardware-configuration.nix .

# Edit configuration.nix to uncomment:
# imports = [ ./hardware-configuration.nix ];

# Install
sudo nixos-install --flake .#nixos-x86_64
```

6. **Set root password and reboot:**

```bash
sudo nixos-enter --root /mnt
passwd
exit
sudo reboot
```

## Post-Installation

After installing via any method:

1. **Update flake:**

```bash
nix flake update
```

2. **Rebuild system:**

```bash
sudo nixos-rebuild switch --flake .#nixos-x86_64
```

3. **Customize configuration.nix** as needed

## Troubleshooting

### Cannot connect via SSH (Method 1)
- Ensure SSH is running: `systemctl status sshd`
- Check firewall rules
- Verify SSH keys are in authorized_keys

### Partition errors
- Verify disk device name: `lsblk`
- Ensure disk is not mounted
- Check for existing partitions: `fdisk -l`

### Flake evaluation errors
- Ensure experimental features enabled
- Check syntax: `nix flake check`
- Update inputs: `nix flake update`

### Boot issues
- Check bootloader installation
- Verify EFI/BIOS settings
- Ensure boot partition is properly mounted

## Resources

- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [nixos-infect](https://github.com/elitak/nixos-infect)
- [NixOS Manual - Installation](https://nixos.org/manual/nixos/stable/index.html#sec-installation)
- [Disko - Declarative Disk Partitioning](https://github.com/nix-community/disko)
