{
  description = "Self-contained NixOS for UTM SE on iPad - automated and declarative";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      # Base configuration for installations
      baseConfiguration = {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./disk-config.nix
          ./configuration.nix
        ];
      };
      
      # ISO configuration with installer modules
      isoConfiguration = {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./configuration.nix
          {
            # Override for ISO
            isoImage = {
              makeEfiBootable = true;
              makeUsbBootable = true;
              contents = [
                {
                  source = ./.;
                  target = "/etc/nixos/flake";
                }
              ];
            };
            # Don't include disko in ISO
            disabledModules = [];
          }
        ];
      };
    in
    {
      # Main NixOS configuration for iPad/UTM
      nixosConfigurations.ipad = nixpkgs.lib.nixosSystem baseConfiguration;
      
      # ISO configuration
      nixosConfigurations.ipad-iso = nixpkgs.lib.nixosSystem isoConfiguration;

      # Build outputs
      packages.${system} = {
        # ISO image with this configuration baked in
        iso = self.nixosConfigurations.ipad-iso.config.system.build.isoImage;
        
        # VM image ready to import (using vm-image format)
        default = self.nixosConfigurations.ipad.config.system.build.vm;
      };

      # Apps for easy installation
      apps.${system} = {
        # Build ISO
        build-iso = {
          type = "app";
          program = toString (pkgs.writeShellScript "build-iso" ''
            set -e
            ${pkgs.coreutils}/bin/echo "🔨 Building ISO image for iPad/UTM..."
            ${pkgs.nix}/bin/nix build .#iso
            ${pkgs.coreutils}/bin/echo "✅ ISO built: result/iso/nixos.iso"
            ${pkgs.coreutils}/bin/echo "📱 Transfer this to your iPad and boot in UTM"
          '');
        };

        # Build VM image
        build-vm = {
          type = "app";
          program = toString (pkgs.writeShellScript "build-vm" ''
            set -e
            ${pkgs.coreutils}/bin/echo "🔨 Building VM image for iPad/UTM..."
            ${pkgs.nix}/bin/nix build .#default
            ${pkgs.coreutils}/bin/echo "✅ VM image built in result/"
            ${pkgs.coreutils}/bin/echo "📱 Transfer to your iPad and import into UTM"
          '');
        };

        # Install script (run from live ISO)
        install = {
          type = "app";
          program = toString (pkgs.writeShellScript "install" ''
            set -e
            ${pkgs.coreutils}/bin/echo "🚀 Installing NixOS for iPad/UTM..."
            ${pkgs.coreutils}/bin/echo ""
            
            # Check if running as root
            if [ "$(${pkgs.coreutils}/bin/id -u)" -ne 0 ]; then
              ${pkgs.coreutils}/bin/echo "❌ This script must be run as root"
              ${pkgs.coreutils}/bin/echo "Try: sudo nix run .#install"
              exit 1
            fi
            
            # Check if running in live environment
            if [ ! -d /mnt ]; then
              ${pkgs.coreutils}/bin/mkdir -p /mnt
            fi
            
            ${pkgs.coreutils}/bin/echo "📦 Partitioning disk with disko..."
            ${pkgs.disko}/bin/disko --mode disko ./disk-config.nix
            
            ${pkgs.coreutils}/bin/echo ""
            ${pkgs.coreutils}/bin/echo "⚙️  Installing NixOS..."
            nixos-install --flake .#ipad --no-root-password
            
            ${pkgs.coreutils}/bin/echo ""
            ${pkgs.coreutils}/bin/echo "✅ Installation complete!"
            ${pkgs.coreutils}/bin/echo ""
            ${pkgs.coreutils}/bin/echo "Next steps:"
            ${pkgs.coreutils}/bin/echo "1. Set password: nixos-enter --root /mnt"
            ${pkgs.coreutils}/bin/echo "   Then run: passwd nixos"
            ${pkgs.coreutils}/bin/echo "2. Reboot: reboot"
            ${pkgs.coreutils}/bin/echo "3. Remove ISO from UTM"
          '');
        };
      };

      # Development shell for building images on other systems
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          qemu
          git
          disko
        ];
        shellHook = ''
          echo "🔧 iPad NixOS Development Environment"
          echo ""
          echo "📦 Available commands:"
          echo "  nix build .#iso        - Build bootable ISO"
          echo "  nix build .#default    - Build VM image"
          echo "  nix run .#build-iso    - Build ISO with helper script"
          echo "  nix run .#build-vm     - Build VM image with helper script"
          echo "  nix run .#install      - Run installer (from live environment)"
          echo ""
          echo "🛠️  To customize, edit:"
          echo "  - configuration.nix (system config)"
          echo "  - disk-config.nix (disk layout)"
          echo ""
          echo "📱 For iPad/UTM usage, see README.md"
        '';
      };
    };
}
