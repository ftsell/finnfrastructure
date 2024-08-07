{ modulesPath, config, lib, pkgs, ... }:
let
  data.network = import ../data/hosting_network.nix;
  data.wg_vpn = import ../data/wg_vpn.nix;

  vpn_clients = (builtins.attrValues
    (lib.filterAttrs (peerName: iPeer: peerName != config.networking.hostName)
      data.wg_vpn.peers));
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
      device = "/dev/disk/by-uuid/E9D6-069D";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    "/" = {
      device = "/dev/disk/by-uuid/27a157c7-50b0-4778-a9e2-2747cb59b5e0";
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

  # enable port-forwarding so that wireguard peers can communicate with each other
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = "1";
    "net.ipv6.conf.all.forwarding" = "1";
  };

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # networking config
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks.enp1s0 = {
      matchConfig = {
        Type = "ether";
        MACAddress = data.network.guests.vpn-srv.macAddress;
      };
      DHCP = "yes";
    };

    netdevs.wgVpn = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wgVpn";
      };
      wireguardConfig = {
        ListenPort = 51820;
        PrivateKeyFile = "/run/secrets/wg_vpn/privkey";
      };
      wireguardPeers = (
        builtins.map
          (iPeer: {
            wireguardPeerConfig = {
              PublicKey = iPeer.pub;
              AllowedIPs = [ iPeer.ownIp4 iPeer.ownIp6 ] ++ iPeer.routedIp4 ++ iPeer.routedIp6;
              Endpoint = lib.mkIf (iPeer.endpoint != null) iPeer.endpoint;
              PersistentKeepalive = lib.mkIf iPeer.keepalive 25;
            };
          })
          vpn_clients);
    };
    networks.wgVpn = {
      matchConfig = {
        Name = "wgVpn";
      };
      address = [
        data.wg_vpn.peers.${config.networking.hostName}.ownIp4
        data.wg_vpn.peers.${config.networking.hostName}.ownIp6
      ];
      routes = (
        lib.flatten (
          builtins.map
            (iPeer:
              [
                # ip4 route
                # TODO: Generate routes for the routedIp4 and routedIp6 attrs too
                {
                  routeConfig = {
                    Destination = iPeer.ownIp4;
                    Source = data.wg_vpn.peers.${config.networking.hostName}.ownIp4;
                  };
                }
                # ip6 route
                {
                  routeConfig = {
                    Destination = iPeer.ownIp6;
                    Source = data.wg_vpn.peers.${config.networking.hostName}.ownIp6;
                  };
                }
              ]
            )
            vpn_clients
        ));
    };
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.qemuGuest.enable = true;

  sops.secrets = {
    "wg_vpn/privkey" = {
      owner = "systemd-network";
    };
  };

  # DO NOT CHANGE
  # this defines the first version of NixOS that was installed on the machine so that programs with non-migratable data files are kept compatible
  home-manager.users.ftsell.home.stateVersion = "24.05";
  system.stateVersion = "24.05";
}
