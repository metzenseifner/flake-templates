# Example disk configuration for use with disko and nixos-anywhere
# Modify device paths and sizes according to your needs

{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";  # ⚠️ CHANGE THIS to match your disk (e.g., /dev/nvme0n1, /dev/vda)
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition (for GRUB)
            boot = {
              size = "1M";
              type = "EF02";
            };
            # EFI System Partition
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            # Root partition
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
