# Automated disk configuration for UTM virtual disk
# This is declarative and will be applied automatically

{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # In UTM, virtual disk is typically /dev/vda
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot partition for compatibility
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
            # Root partition takes remaining space
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "noatime" ];
              };
            };
          };
        };
      };
    };
  };
}
