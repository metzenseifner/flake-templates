# Replace Ubuntu (or any distro) with NixOS on UTM SE

This guide shows you how to replace an existing Ubuntu (or other Linux distribution) VM on UTM SE with NixOS, using this template.

## ⚠️ Warning

**This will completely wipe your existing Ubuntu VM.** Back up any important data first!

## 🎯 Three Methods

### Method 1: Replace In-Place (Quickest)

Boot a NixOS ISO in your existing Ubuntu VM and install over it.

#### Steps

1. **Build NixOS ISO on Mac/Linux**
   ```bash
   nix flake init -t github:metzenseifner/flake-templates#ipad
   # Customize if desired
   nix build .#iso
   ```

2. **Attach ISO to Existing Ubuntu VM**
   - Open your Ubuntu VM in UTM (don't start it)
   - Edit VM settings
   - Add CD/DVD Drive
   - Select the ISO you built (result/iso/nixos.iso)
   - Change boot order to boot from CD first
   - Save settings

3. **Boot from ISO**
   - Start the VM
   - It will boot into NixOS live environment
   - The configuration is already in `/etc/nixos/flake`

4. **Run Automated Installer**
   ```bash
   cd /etc/nixos/flake
   
   # This will wipe the existing disk and install NixOS
   sudo nix run .#install
   ```

5. **Set Password and Reboot**
   ```bash
   sudo nixos-enter --root /mnt
   passwd nixos
   exit
   
   sudo reboot
   ```

6. **Remove ISO**
   - Shutdown VM
   - Remove ISO from UTM settings
   - Start VM
   - You're now running NixOS! 🎉

---

### Method 2: Preserve Data Partition (Careful Migration)

Keep your `/home` or data partition and only replace the system.

⚠️ **Advanced users only** - requires manual partitioning.

#### Steps

1. **From Ubuntu, Backup Data**
   ```bash
   # Identify your partitions
   lsblk
   
   # Example: /dev/vda2 is your data partition
   # Make note of what you want to keep
   ```

2. **Boot NixOS ISO** (follow steps from Method 1)

3. **Manual Partitioning**
   ```bash
   # Don't use the automated installer!
   # Instead, manually partition:
   
   # Example: Keep /dev/vda3 as data, recreate others
   sudo parted /dev/vda
   # Delete only system partitions (e.g., /, /boot)
   # Keep data partition (e.g., /home)
   
   # Create new partitions for NixOS
   sudo parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
   sudo parted /dev/vda -- set 1 esp on
   sudo parted /dev/vda -- mkpart primary 512MiB 20GiB
   
   # Format new partitions only
   sudo mkfs.fat -F 32 /dev/vda1
   sudo mkfs.ext4 /dev/vda2
   
   # Mount everything
   sudo mount /dev/vda2 /mnt
   sudo mkdir -p /mnt/boot /mnt/home
   sudo mount /dev/vda1 /mnt/boot
   sudo mount /dev/vda3 /mnt/home  # Your data partition
   ```

4. **Generate Hardware Config**
   ```bash
   sudo nixos-generate-config --root /mnt
   ```

5. **Install NixOS**
   ```bash
   cd /etc/nixos/flake
   
   # Copy hardware config
   sudo cp /mnt/etc/nixos/hardware-configuration.nix .
   
   # Edit configuration.nix to uncomment:
   # imports = [ ./hardware-configuration.nix ];
   
   # Install
   sudo nixos-install --flake .#ipad
   ```

6. **Reboot**
   ```bash
   sudo reboot
   ```

Your `/home` data is preserved!

---

### Method 3: Create New VM, Migrate Data Later

Safest approach - create fresh NixOS VM, then copy data.

#### Steps

1. **Create New VM in UTM**
   - Don't touch your Ubuntu VM yet
   - Create new VM for NixOS
   - Follow standard installation from QUICKSTART.md

2. **Boot Both VMs**
   - Start your new NixOS VM
   - Start your Ubuntu VM

3. **Transfer Data**
   
   **Option A: Via SSH**
   ```bash
   # In Ubuntu VM, find IP
   ip addr show
   
   # In NixOS VM, copy data
   scp -r ubuntu-user@<ubuntu-ip>:/home/ubuntu/data ~/
   ```
   
   **Option B: Via Shared Folder**
   - Use UTM's folder sharing feature
   - Copy data through iPad Files app
   
   **Option C: Via iCloud/Files**
   - Export data from Ubuntu to iPad storage
   - Import into NixOS

4. **Verify Everything Works**
   - Test your NixOS setup completely
   - Ensure all data is transferred

5. **Delete Ubuntu VM**
   - Only after you're 100% sure everything works
   - Delete the Ubuntu VM in UTM

---

## 📋 Pre-Migration Checklist

Before replacing Ubuntu, make sure you know:

- [ ] What packages you need (Ubuntu → NixOS equivalents)
- [ ] Important configuration files to back up
- [ ] Data locations (home directory, etc.)
- [ ] Services you're running
- [ ] Network configuration
- [ ] SSH keys and credentials

### Package Translation Examples

| Ubuntu | NixOS |
|--------|-------|
| `apt install nodejs` | `environment.systemPackages = [ pkgs.nodejs ];` |
| `apt install python3-pip` | `environment.systemPackages = [ pkgs.python3 ];` |
| `systemctl enable nginx` | `services.nginx.enable = true;` |

## 🔧 Customizing for Your Use Case

Before replacing Ubuntu, customize `configuration.nix`:

### 1. Install Your Packages

```nix
environment.systemPackages = with pkgs; [
  # Your Ubuntu packages translated to NixOS
  nodejs
  python3
  docker
  postgresql
  # etc.
];
```

### 2. Enable Services

```nix
# If you were running services in Ubuntu
services.postgresql.enable = true;
services.docker.enable = true;
services.nginx.enable = true;
```

### 3. Configure Users

```nix
users.users.yourname = {
  isNormalUser = true;
  extraGroups = [ "wheel" "docker" "networkmanager" ];
  openssh.authorizedKeys.keys = [
    "your-ssh-key-here"
  ];
};
```

### 4. Set Up Networking

```nix
networking = {
  hostName = "your-hostname";
  # Copy any special network config from Ubuntu
};
```

## 📦 Migrating Specific Setups

### Development Environment

```nix
# In configuration.nix
environment.systemPackages = with pkgs; [
  git gh
  vim neovim
  tmux
  nodejs python3 go rustc
  docker docker-compose
];

virtualisation.docker.enable = true;
```

### Web Server

```nix
services.nginx = {
  enable = true;
  virtualHosts."example.com" = {
    locations."/" = {
      proxyPass = "http://localhost:3000";
    };
  };
};
```

### Database Server

```nix
services.postgresql = {
  enable = true;
  authentication = ''
    local all all trust
  '';
};
```

### Desktop Environment

```nix
# If your Ubuntu had a desktop
services.xserver = {
  enable = true;
  displayManager.lightdm.enable = true;
  desktopManager.xfce.enable = true;  # or gnome, kde, etc.
};
```

## 🔄 Quick Migration Script

Save this in your Ubuntu VM before replacing:

```bash
#!/bin/bash
# migration-backup.sh - Run this in Ubuntu before replacing

BACKUP_DIR="$HOME/nixos-migration"
mkdir -p "$BACKUP_DIR"

# Backup important configs
cp -r ~/.ssh "$BACKUP_DIR/"
cp -r ~/.config "$BACKUP_DIR/"
cp ~/.bashrc ~/.profile ~/.zshrc "$BACKUP_DIR/" 2>/dev/null

# List installed packages
dpkg --get-selections > "$BACKUP_DIR/ubuntu-packages.txt"

# List running services
systemctl list-units --type=service --state=running > "$BACKUP_DIR/services.txt"

# Backup data
cp -r ~/Documents ~/Projects ~/Desktop "$BACKUP_DIR/" 2>/dev/null

echo "Backup complete in $BACKUP_DIR"
echo "Transfer this to your iPad storage before replacing Ubuntu"

# Create package translation hints
echo "# Package translation hints" > "$BACKUP_DIR/package-hints.nix"
echo "environment.systemPackages = with pkgs; [" >> "$BACKUP_DIR/package-hints.nix"
dpkg --get-selections | grep -v deinstall | awk '{print "  # " $1}' >> "$BACKUP_DIR/package-hints.nix"
echo "];" >> "$BACKUP_DIR/package-hints.nix"
```

Run in Ubuntu:
```bash
chmod +x migration-backup.sh
./migration-backup.sh

# Copy ~/nixos-migration to iPad storage
```

## 🎯 Quick Replacement Workflow

**If you don't care about data and just want NixOS:**

1. Build ISO: `nix build .#iso`
2. Attach to Ubuntu VM in UTM
3. Boot from ISO
4. Run: `sudo nix run /etc/nixos/flake#install`
5. Reboot
6. Done! ✨

**Total time: ~10 minutes**

## ⚡ One-Liner for Quick Replace

If you've already built the ISO and just want to nuke Ubuntu:

```bash
# Boot the ISO, then:
cd /etc/nixos/flake && sudo nix run .#install && sudo nixos-enter --root /mnt -c "passwd nixos" && sudo reboot
```

## 🔍 Troubleshooting

### "Can't attach ISO to running VM"
- Shut down the Ubuntu VM first
- Attach ISO to stopped VM
- Start VM

### "ISO won't boot"
- Check boot order in UTM settings
- Ensure UEFI is enabled
- Try removing the hard disk temporarily to force ISO boot

### "Lost data after replacement"
- This is expected with Method 1
- You should have backed up first
- Use Method 2 or 3 to preserve data

### "Need to go back to Ubuntu"
- If you have a backup of the VM image, restore it
- Otherwise, you'll need to reinstall Ubuntu
- Lesson: Test in a new VM first (Method 3)

## 💡 Pro Tips

1. **Test first**: Use Method 3 to create a new NixOS VM and test your setup before replacing Ubuntu

2. **Snapshot**: If UTM SE supports snapshots, snapshot your Ubuntu VM before replacing

3. **Document**: Write down all the services and packages you use in Ubuntu before migrating

4. **Gradual**: Don't try to replicate everything at once. Start with basics, add more as you go

5. **Learn NixOS**: The configuration is very different from Ubuntu. Take time to learn Nix language basics

## 📚 Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Package Search](https://search.nixos.org/)
- [NixOS Wiki](https://nixos.wiki/)
- [This template's README](./README.md)
- [QUICKSTART](./QUICKSTART.md)

## 🎁 Example: Complete Replacement

Here's a real example replacing Ubuntu with NixOS:

```bash
# On Mac, build ISO
nix flake init -t github:metzenseifner/flake-templates#ipad
vim configuration.nix  # Add my packages
nix build .#iso

# Transfer to iPad, attach to Ubuntu VM in UTM
# Boot from ISO

# In live environment
cd /etc/nixos/flake
sudo nix run .#install

# Set password
sudo nixos-enter --root /mnt
passwd nixos
exit

# Reboot
sudo reboot

# SSH from iPad
ssh nixos@<vm-ip>

# Configure as needed
sudo vim /etc/nixos/flake/configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos/flake#ipad
```

**Done!** Ubuntu → NixOS in minutes! 🚀

---

## ❓ FAQ

**Q: Can I dual-boot Ubuntu and NixOS in UTM?**
A: Not really in one VM. Better to have two separate VMs.

**Q: Will my Ubuntu apps work on NixOS?**
A: Most apps are available in nixpkgs. Check https://search.nixos.org/

**Q: Can I still use apt/dpkg?**
A: No. NixOS uses Nix package manager exclusively.

**Q: What about my dotfiles?**
A: Back them up and copy to NixOS. Or use Home Manager for declarative dotfiles.

**Q: Is this reversible?**
A: Only if you backed up your Ubuntu VM. Otherwise, you'll need to reinstall Ubuntu.

**Q: Can I access my Ubuntu files after replacing?**
A: No, unless you preserved a data partition (Method 2) or backed up first.

**Q: How long does this take?**
A: Method 1: ~10-15 minutes. Method 2: ~30 minutes. Method 3: ~30 minutes + testing time.

---

**Ready to replace Ubuntu with NixOS?** Follow Method 1 for quick replacement, or Method 3 for safe migration! 🎉
