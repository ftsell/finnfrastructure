{ modulesPath, config, lib, pkgs, ... }:
let
  data.network = import ../data/hosting_network.nix;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../modules/base_system.nix
    ../modules/user_ftsell.nix
  ];

  # boot config
  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-uuid/66AB-693B";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    "/" = {
      device = "/dev/disk/by-uuid/ef98ffbb-63c7-4338-929f-241ded7536e7";
      fsType = "bcachefs";
    };
  };

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
    editor = false;
  };

  # networking config
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks.enp1s0 = {
      matchConfig = {
        Type = "ether";
        MACAddress = data.network.guests.main-srv.macAddress;
      };
      DHCP = "yes";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.qemuGuest.enable = true;

  # database config
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureDatabases = [ "ftsell" ];
    ensureUsers = [{
      name = "ftsell";
      ensureDBOwnership = true;
      ensureClauses.superuser = true;
    }];
    authentication = ''
      host all all 10.42.0.0/16 md5
    '';
  };

  # haproxy
  services.haproxy = {
    enable = true;
    config = ''
      defaults
        timeout connect 500ms
        timeout server 1h
        timeout client 1h

      frontend http
        bind :80
        mode tcp
        use_backend ingress-http
      
      frontend https
        bind :443
        mode tcp
        use_backend ingress-https
      
      backend ingress-http
        mode tcp
        server s1 127.0.0.1:30080 check send-proxy

      backend ingress-https
        mode tcp
        server s1 127.0.0.1:30443 check send-proxy
    '';
  };

  # k8s config
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    # TODO add fc00:42::/64 as cluster-cidr and fc00:43::/64 as service-cidr once the server has its own ipv6 address
    extraFlags = "--disable-helm-controller --disable=traefik --disable=servicelb --flannel-backend wireguard-native --cluster-cidr 10.42.0.0/16 --service-cidr 10.43.0.0/16 --egress-selector-mode disabled";
  };
  networking.firewall = {
    # https://docs.k3s.io/installation/requirements#networking
    allowedTCPPorts = [
      6443    # kubernetes api
      10250   # kubelet metrics
      80      # haproxy http
      443     # haproxy https
      30189   # mediamtx webrtc
      30000   # pixelflut server
    ];
    allowedUDPPorts = [
      51820   # k3s networking ip4 (over flannel wireguard)
      51821   # k3s networking ip6 (over flannel wireguard)
      30189   # mediamtx webrtc
      30000   # pixelflut server
    ];
    interfaces = rec {
      "flannel-wg".allowedTCPPorts = [ 5432 ];
      "cni0".allowedTCPPorts = [ 5432 ];
    };
  };

  # user for forgejo ssh access
  users.groups."git" = {
    gid = 10000;
  };
  users.users."git" = {
    uid = 10000;
    group = "git";
    isSystemUser = true;
    home = "/var/lib/forgejo";
    createHome = true;
    shell = (pkgs.writeShellApplication {
      name = "forgejo-shell";
      derivationArgs = {
        passthru = {
          shellPath = "/bin/forgejo-shell";
        };
      };
      runtimeInputs = with pkgs; [ openssh ];
      text = ''
        shift
        ssh -p 30022 -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 git@main.srv.ftsell.de "SSH_ORIGINAL_COMMAND=\"$SSH_ORIGINAL_COMMAND\" $*"
      '';
    });
  };

  # DO NOT CHANGE
  # this defines the first version of NixOS that was installed on the machine so that programs with non-migratable data files are kept compatible
  home-manager.users.ftsell.home.stateVersion = "24.05";
  system.stateVersion = "24.05";
}
