{ config, pkgs, lib, modulesPath, ... }:

{
  imports = lib.optionals (builtins.pathExists "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix") [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # System identification
  system.stateVersion = "24.11";
  networking.hostName = "nixos-ipad";

  # Boot configuration for UTM/QEMU
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    
    # Kernel modules for virtio (UTM uses these)
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi" 
      "virtio_blk"
      "virtio_net"
      "9p"
      "9pnet_virtio"
    ];
    
    kernelModules = [ "virtio_balloon" "virtio_console" "virtio_rng" ];
    
    # Speed up boot
    kernelParams = [ "quiet" ];
  };

  # Hardware configuration for UTM VMs
  hardware = {
    enableRedistributableFirmware = true;
  };

  # Networking
  networking = {
    networkmanager.enable = true;
    # UTM shared network
    useDHCP = true;
    # Enable SSH from boot
    firewall.allowedTCPPorts = [ 22 ];
  };

  # Locale and timezone
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = lib.mkDefault "us";

  # Essential packages for iPad workflow
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    neovim
    
    # Development tools
    git
    gh
    
    # System utilities
    wget
    curl
    htop
    tmux
    rsync
    
    # Network tools
    openssh
    
    # For clipboard sharing in UTM
    spice-vdagent
  ];

  # Enable SSH server for iPad terminal access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # Spice agent for clipboard sharing with UTM
  services.spice-vdagentd.enable = true;

  # QEMU guest agent for better VM integration
  services.qemuGuest.enable = true;

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    description = "NixOS User";
    extraGroups = [ "wheel" "networkmanager" ];
    # Set this password on first boot with 'passwd'
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = [
      # Add your SSH public key here for passwordless login from iPad
      # "ssh-ed25519 AAAAC3... your-key-comment"
    ];
  };

  # Allow passwordless sudo for wheel group (convenient for iPad usage)
  security.sudo.wheelNeedsPassword = false;

  # Nix configuration
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    # Automatic garbage collection to save space
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # For ISO builds - include this flake in the ISO
  isoImage = lib.mkIf (config ? isoImage) {
    makeEfiBootable = true;
    makeUsbBootable = true;
    # Include the flake config in the ISO
    contents = [
      {
        source = ./.;
        target = "/etc/nixos/flake";
      }
    ];
  };

  # Optional: Minimal display server for GUI apps (comment out for console-only)
  # Uncomment these for a lightweight desktop environment:
  # services.xserver = {
  #   enable = true;
  #   displayManager.lightdm.enable = true;
  #   desktopManager.xfce.enable = true;
  #   # Virtio GPU driver for UTM
  #   videoDrivers = [ "modesetting" ];
  # };

  # Optional: Enable VS Code Server for browser-based development
  # Uncomment to enable:
  # services.code-server = {
  #   enable = true;
  #   auth = "password";
  #   hashedPassword = "$6$...";  # Set with: mkpasswd -m sha-512
  #   host = "0.0.0.0";
  #   port = 8080;
  # };
}
