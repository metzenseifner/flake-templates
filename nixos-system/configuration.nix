{ config, pkgs, lib, ... }:

{
  # Boot loader configuration
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    efi.canTouchEfiVariables = lib.mkDefault true;
  };

  # Networking
  networking = {
    hostName = "nixos";
    networkmanager.enable = lib.mkDefault true;
  };

  # Time zone and locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
  };

  # Essential system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    htop
  ];

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkDefault "no";
      PasswordAuthentication = lib.mkDefault true;
    };
  };

  # User configuration example
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  # Allow sudo for wheel group
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # System state version
  system.stateVersion = "24.11";

  # Hardware configuration (should be generated with nixos-generate-config)
  # Uncomment and modify as needed:
  # imports = [ ./hardware-configuration.nix ];
}
