{ modulesPath, config, lib, pkgs, home-manager, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/base_system.nix
    ../modules/gnome.nix
    ../modules/user_ftsell.nix
    ../modules/dev_env.nix
    ../modules/vpn_client.nix
  ];

  # boot config
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_9;
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/5e4c1696-760d-4823-89c8-64f4345f081a";
      fsType = "bcachefs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/5C6D-BE54";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };
  swapDevices = [{
    device = "/dev/disk/by-partuuid/d9f43f65-d7c9-4394-aee3-8d1822cee200";
    randomEncryption.enable = true;
  }];
  hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = "x86_64-linux";
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "bcachefs" ];

  # hardware config
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    driSupport = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = false;
    prime = {
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  # backup settings
  custom.backup.rsync-net = {
    enable = true;
    repoPath = "./backups/private-systems";
  };

  # additional packages
  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
    virt-manager
    libreoffice-fresh
    evince
    ranger
    sops
    git-crypt
    gnupg
    sieveshell
  ];


  virtualisation.podman = {
    enable = true;
    dockerSocket.enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
  };
  services.printing.enable = true;
  services.earlyoom.enable = true;
  programs.gnupg.agent.enable = true;

  sops.age.keyFile = /home/ftsell/.config/sops/age/keys.txt;

  # DO NOT CHANGE
  # this defines the first version of NixOS that was installed on the machine so that programs with non-migratable data files are kept compatible
  home-manager.users.ftsell.home.stateVersion = "24.05";
  system.stateVersion = "24.05";
}
