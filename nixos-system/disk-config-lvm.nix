# Advanced disk configuration with LVM for flexibility
# Allows easy resizing and snapshots

{ ... }:
{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";  # ⚠️ CHANGE THIS to match your disk
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # BIOS boot
            boot = {
              size = "1M";
              type = "EF02";
            };
            # EFI
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
            # LVM partition
            lvm = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "mainvg";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      mainvg = {
        type = "lvm_vg";
        lvs = {
          # Root volume
          root = {
            size = "50G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
          # Home volume
          home = {
            size = "100G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/home";
              mountOptions = [ "noatime" ];
            };
          };
          # Swap
          swap = {
            size = "8G";
            content = {
              type = "swap";
            };
          };
        };
      };
    };
  };
}
