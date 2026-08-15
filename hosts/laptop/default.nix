{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/hardware/nvidia-prime.nix
    ../../modules/hardware/backlight.nix
    ../../modules/hardware/rtl-sdr.nix
  ];

  networking.hostName = "nanixos";
  time.timeZone = "America/Santiago";

  # This laptop's internal panel enumerates as eDP-1, not the desktop's
  # DP-1 - see modules/desktop/regreet.nix for why a mismatch here makes
  # greetd crash-loop (sway ends up with every output disabled).
  desktop.greeter.output = "eDP-1";

  i18n.defaultLocale = "es_CL.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "la-latin1";
    useXkbConfig = false;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;

    # gnome-network-displays' Miracast/WFD audio capture dies after ~5-30s
    # of silence: it creates a virtual "Network-Displays" null-sink via the
    # pipewire-pulse compat layer (not a WirePlumber monitor, so per-node
    # `session.suspend-timeout-seconds` rules can't reach it), and
    # WirePlumber's default node/suspend-node.lua hook suspends any
    # Audio/Video node idle for 5s. A presentation with no embedded
    # audio/video hits this constantly - pulsesrc then fails to read from
    # the suspended node ("error reading data -1"), which kills the whole
    # muxed audio+video RTSP pipeline, not just audio.
    # There's no way to disable suspend for just that one node (it isn't
    # WirePlumber-managed at creation time), so this disables the
    # auto-suspend hook system-wide instead: slightly more idle power draw
    # from audio/video hardware, traded for casts/presentations that don't
    # randomly die.
    wireplumber.extraConfig."51-no-node-suspend" = {
      "wireplumber.profiles" = {
        main."hooks.node.suspend" = "disabled";
      };
    };
  };

  # Miracast/Wi-Fi Direct casting to the Roku (gnome-network-displays) needs
  # this RTSP port reachable; NixOS's firewall blocks it by default.
  networking.firewall.allowedTCPPorts = [ 7236 ];

  # WFD's actual RTP audio/video stream rides UDP on whatever ephemeral
  # port GStreamer's udpsink picks, not 7236 (that's RTSP control only).
  # Kernel's default ephemeral range (net.ipv4.ip_local_port_range).
  # Not yet confirmed to matter for the Samsung Q60CA failure - every
  # capture so far has died during 802.11 P2P GO negotiation, before any
  # IP traffic exists at all - but harmless to have open regardless.
  networking.firewall.allowedUDPPortRanges = [{ from = 32768; to = 60999; }];

  # mt7921e (MT7922 firmware) has a MediaTek-specific CLC ("Country/Local
  # Compliance") mechanism that restricts channels/TX power based on the
  # detected regulatory domain. Every P2P negotiation attempt so far logs
  # "Country XX" (world/unset domain, not CL) for both this device and the
  # peer's WFD IE - CLC under an unset domain is a known source of overly
  # conservative behavior with off-channel P2P Action frames on this chip
  # family. Testing this because casting to this exact Samsung TV worked
  # previously on the same hardware under Arch/i3 (X11) - the WFD
  # negotiation path (wpa_supplicant/NetworkManager) is compositor-agnostic,
  # so the regression points at a kernel/driver-level default differing
  # from Arch's, not anything X11-vs-Wayland.
  boot.extraModprobeConfig = ''
    options mt7921_common disable_clc=1
  '';

  # Miracast needs Wi-Fi scan MAC randomization off (see
  # modules/desktop/wifi-panel.nix for why: no in-tree kernel driver,
  # including mt76/mt7921, declares
  # NL80211_EXT_FEATURE_MGMT_TX_RANDOM_TA_CONNECTED, so cfg80211 rejects
  # the P2P GO Negotiation Request frame's randomized source address with
  # EINVAL while wlo1 stays connected to the home AP - confirmed live,
  # kernel accepts the frame once randomization is off). Kept on
  # (default/secure) here; wifi-panel's waybar toggle drops it temporarily
  # around a cast instead of baking the insecure setting in persistently.

  # This value should NOT be changed once set for this host.
  # See https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  system.stateVersion = "25.11";
}
