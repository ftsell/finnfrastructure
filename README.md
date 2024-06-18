# finnfrastructure

My personal infrastructure *configuration-as-code* repository.
Its goal is to contain all necessary configuration for my different servers to allow easier setup.

### How to generate an Installer ISO

Run the following command.
The resulting ISO file is then located in the printed path + `/iso`.

```shell
nix build --print-out-paths '.#installer.x86_64-linux'
```

### How to install a system

2. In the installer, create and mount filesystems.
3. Enter filesystem config into this repository for that server and commit changes.
   
   ```nix
    fileSystems = {
        "/boot" = {
            device = "/dev/disk/by-uuid/…";
            fsType = "vfat";
            options = [ "fmask=0077" "dmask=0077" ];
        };
        "/" = {
            device = "/dev/disk/by-uuid/…";
            fsType = "bcachefs";
        };
    };
   ```
4. Run nixos-install like this:

   ```shell
   sudo nixos-install --no-channel-copy --no-root-passwd --root /mnt --flake 'github:ftsell/finnfrastructure?ref=nix-config#…'
   ```
5. Reboot the system

