{
  description = "Tart + NixOS remote builders (multi-arch) without nixos-generators";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      darwinSystem = "aarch64-darwin";
      pkgsDarwin = import nixpkgs { system = darwinSystem; };

      # NixOS builders run as aarch64-linux VMs under Tart on Apple Silicon.
      linuxSystem = "aarch64-linux";
      pkgsLinux = import nixpkgs { system = linuxSystem; };
      lib = nixpkgs.lib;

      # Read SSH pubkey from env at eval time (requires --impure).
      # builder-up.sh sets BUILDER_SSH_PUBKEY.
      sshKeyFromEnv =
        let
          k = builtins.getEnv "BUILDER_SSH_PUBKEY";
        in
        lib.optionals (k != "") [ k ];

      commonBuilderModule =
        {
          enableArm32Emu ? false,
        }:
        { config, pkgs, ... }:
        {
          services.openssh.enable = true;

          users.users.nixbuilder = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = sshKeyFromEnv;
          };

          security.sudo.wheelNeedsPassword = false;

          nix = {
            settings = {
              trusted-users = [
                "root"
                "nixbuilder"
              ];
              experimental-features = [
                "nix-command"
                "flakes"
              ];
              sandbox = true;
              max-jobs = "auto";
              cores = 0;
            };
          };

          # Optional: enable emulation for ARM32 targets (slow)
          boot.binfmt.emulatedSystems = lib.mkIf enableArm32Emu [
            "armv7l-linux"
            "armv6l-linux"
          ];

          # Make sure virtio drivers are there (usually default, but safe)
          boot.initrd.availableKernelModules = [
            "virtio_pci"
            "virtio_blk"
            "virtio_net"
          ];
        };

      # Create a UEFI GPT raw disk image using nixpkgs' make-disk-image.
      #
      # This is a plain derivation producing a raw .img that Tart can boot as a disk.
      mkTartDiskImage =
        {
          name,
          enableArm32Emu ? false,
          diskSizeMiB ? 16384, # 16 GiB
        }:
        let
          nixosCfg = lib.nixosSystem {
            system = linuxSystem;
            modules = [
              (commonBuilderModule { inherit enableArm32Emu; })
              # Minimal base settings
              (
                { ... }:
                {
                  networking.hostName = name;
                  time.timeZone = "UTC";
                  system.stateVersion = "24.11";
                }
              )
            ];
          };

          makeDiskImage = import (nixpkgs + "/nixos/lib/make-disk-image.nix");
        in
        makeDiskImage {
          inherit lib;
          pkgs = pkgsLinux;

          # NixOS system closure to embed in the image
          config = nixosCfg.config;

          name = "${name}-tart-uefi";
          diskSize = diskSizeMiB;
          format = "raw";

          # Ensure a UEFI-capable layout
          partitionTableType = "gpt";
          # Create an EFI System Partition
          efiSize = 256;
        };
    in
    {
      packages.${darwinSystem} = {
        tartDisk-aarch64 = mkTartDiskImage {
          name = "builder-aarch64";
          enableArm32Emu = false;
          diskSizeMiB = 16384;
        };

        tartDisk-arm32 = mkTartDiskImage {
          name = "builder-arm32";
          enableArm32Emu = true;
          diskSizeMiB = 16384;
        };
      };

      apps.${darwinSystem} =
        let
          makeScript = name: scriptPath: pkgsDarwin.writeShellScriptBin name ''
            exec ${pkgsDarwin.bash}/bin/bash ${scriptPath}
          '';
        in
        {
          builder-up = {
            type = "app";
            program = "${makeScript "builder-up" ./scripts/builder-up.sh}/bin/builder-up";
          };
          builder-down = {
            type = "app";
            program = "${makeScript "builder-down" ./scripts/builder-down.sh}/bin/builder-down";
          };
          builder-status = {
            type = "app";
            program = "${pkgsDarwin.writeShellScriptBin "builder-status" ''
              tart list
              echo
              tart ps || true
            ''}/bin/builder-status";
          };
        };

      formatter.${darwinSystem} = pkgsDarwin.nixfmt-rfc-style;
    };
}
