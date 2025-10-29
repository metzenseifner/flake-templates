# Minimal NixOS System Template

A minimal, architecture-agnostic NixOS system configuration template suitable for any architecture.

## Features

- **Multi-architecture support**: Pre-configured for x86_64 and aarch64 (ARM64)
- **Minimal baseline**: Only essential packages and services
- **Flake-based**: Modern Nix flakes configuration
- **Customizable**: Uses `lib.mkDefault` for easy overrides
- **Bootstrap-ready**: Includes disko integration for nixos-anywhere
- **Multiple disk layouts**: Simple and LVM examples included
- **UTM/iPad compatible**: Works with UTM SE virtualization on iPad (see [UTM-iPad.md](./UTM-iPad.md))

## Usage

### Bootstrap from Another Linux Distribution

**See [BOOTSTRAP.md](./BOOTSTRAP.md)** for complete instructions on installing NixOS from Ubuntu, Debian, Arch, or any other Linux distribution without installation media.

Quick start with nixos-anywhere:
```bash
nix run github:nix-community/nixos-anywhere -- --flake .#nixos-x86_64 root@target-host
```

### Initialize a new system

```bash
nix flake init -t github:yourusername/flake-templates#nixos-system
```

### Build the system configuration

For x86_64:
```bash
nixos-rebuild build --flake .#nixos-x86_64
```

For aarch64:
```bash
nixos-rebuild build --flake .#nixos-aarch64
```

### Deploy to current system

```bash
sudo nixos-rebuild switch --flake .#nixos-x86_64
```

## Customization

### 1. Generate hardware configuration

On the target machine:
```bash
nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Then uncomment the import in `configuration.nix`:
```nix
imports = [ ./hardware-configuration.nix ];
```

### 2. Change hostname

Edit `configuration.nix`:
```nix
networking.hostName = "your-hostname";
```

### 3. Add users

Edit the `users.users` section in `configuration.nix`.

### 4. Configure timezone

```nix
time.timeZone = "America/New_York";
```

### 5. Add packages

Add to `environment.systemPackages` in `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  vim
  your-package-here
];
```

## Architecture Support

The template supports multiple architectures out of the box:
- `x86_64-linux` - Standard 64-bit Intel/AMD systems
- `aarch64-linux` - ARM64 systems (Raspberry Pi 4, Apple Silicon under Linux, etc.)

To add more architectures, simply add new entries to `nixosConfigurations` in `flake.nix`.

## What's Included

- **Boot**: systemd-boot with UEFI support
- **Networking**: NetworkManager enabled
- **SSH**: OpenSSH server with secure defaults
- **Packages**: vim, wget, curl, git, htop
- **User**: Default user "nixos" with sudo access

## Next Steps

1. Generate and add your hardware configuration
2. Customize users and passwords
3. Configure additional services as needed
4. Set your timezone and locale
5. Build and deploy!

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [NixOS Options Search](https://search.nixos.org/)
