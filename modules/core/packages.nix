{ config, lib, pkgs, ... }:

{
  # Needed for discord and wpsoffice (both unfree). Everything else installed
  # here stays free software; these are the deliberate exceptions.
  nixpkgs.config.allowUnfree = true;

  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.mtr.enable = true;

  # dconf/gsettings backend for GTK4/libadwaita apps (accent color, dark
  # mode, ...) - not pulled in automatically outside of GNOME.
  programs.dconf.enable = true;

  # gvfs backs Nemo's trash, network mounts (smb://, sftp://) and
  # removable-media auto-mount.
  services.gvfs.enable = true;

  # Wires glib-networking's TLS module into GIO_EXTRA_MODULES (plain
  # environment.systemPackages does NOT do this - GIO_EXTRA_MODULES is only
  # populated by NixOS modules that explicitly set
  # environment.sessionVariables, same as services.gvfs/programs.dconf
  # above). Without it, GIO falls back to GDummyTlsBackend and
  # gnome-network-displays' Chromecast backend fails every connection at
  # the TLS handshake ("El soporte de TSL no está disponible").
  services.gnome.glib-networking.enable = true;

  # Enable XDG Desktop Portal (crucial for Wayland screen sharing)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
  ];
  xdg.portal.config.common.default = "*";

  environment.systemPackages = with pkgs; [
    # Editors
    vim
    neovim
    nano

    # File manager (hyprland.conf's $fileManager, SUPER+W)
    nemo

    # CLI
    git
    wget
    curl
    unzip
    zip
    p7zip
    fastfetch
    bat
    gh

    # Basic monitoring
    htop
    tree
    file
    pciutils
    usbutils

    # Shell utils
    ripgrep
    fd

    # Network diagnostics
    bmon
    iftop
    nload
    nethogs
    tcpdump
    iperf3

    # Wayland wallpaper daemon for hyprland.conf's exec-once
    hyprpaper

    # Audio control (PipeWire/Wireplumber native GUI)
    pwvucontrol

    # Chat - both clients installed on purpose (same account, pick per use)
    discord
    vesktop

    # Notes / productivity
    obsidian

    # Notion has no real Linux client. notion-app-enhanced (tried first)
    # bundles a fossilized Electron 11/Chrome 87 that Notion's web app now
    # refuses to load ("browser is not compatible") - and it's stuck there,
    # nixpkgs-unstable pins the same dead upstream release. chromium here
    # exists to run it as a `--app=` window instead (see hosts/*/home.nix's
    # xdg.desktopEntries.notion) - an actually-maintained browser engine.
    chromium

    # Privacy-focused browsing over the Tor network
    tor-browser

    # Git GUI
    github-desktop

    # Secret Service (org.freedesktop.secrets) provider for apps that store
    # credentials (github-desktop, browsers, ...) - no GNOME/KDE session
    # here to supply one, so it needs to be started explicitly (see
    # hyprland.conf's exec-once) with Secret Service integration enabled
    # once in its own Settings.
    keepassxc

    # Remote desktop: wayvnc is the server (see hyprland.conf's exec-once
    # for how it's started), tigervnc provides the vncviewer client for
    # connecting out to other VNC servers.
    wayvnc
    tigervnc

    # Office suite (unfree, hence allowUnfree above)
    wpsoffice

    # Screen recording / streaming
    obs-studio

    # Wireless display casting to Smart TVs (Miracast/WFD). Replaced
    # fluxcast - drops the connection after exactly 30s every time.
    # Confirmed via tcpdump against the Roku Express 4K: SETUP/PLAY
    # advertise `Session: ...;timeout=30`, the RTSP keep-alive
    # (GET_PARAMETER) goes out at t+25s right on schedule, and the Roku
    # never replies - no RTSP text at all after that request in the
    # capture - so the session dies at exactly t+30s.
    # Matches https://github.com/benzea/gnome-network-displays/issues/20
    # (and #95): the keep-alive in wfd_client_timeout_session_filter_func
    # (src/wfd/wfd-client.c) targets the per-stream URL
    # rtsp://localhost/wfd1.0/streamid=0 instead of the spec-correct
    # aggregate control URL rtsp://localhost/wfd1.0 (which is what the
    # *other* GET_PARAMETER/SET_PARAMETER calls in the same file already
    # use). The maintainer floated this exact one-line change in #20 as
    # "more correct per spec" but the original reporter's device still
    # hung with it, so it was never merged upstream. Confirmed fixed on
    # this Roku 2026-08-12: casting no longer drops at 30s.
    (gnome-network-displays.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/wfd/wfd-client.c \
          --replace-fail \
            'gst_rtsp_message_init_request (&msg, GST_RTSP_GET_PARAMETER, "rtsp://localhost/wfd1.0/streamid=0");' \
            'gst_rtsp_message_init_request (&msg, GST_RTSP_GET_PARAMETER, "rtsp://localhost/wfd1.0");'

        # NdCCProvider's Avahi service browser fires service_added_cb once
        # per protocol for dual-stack (IPv4+IPv6) mDNS announcements - every
        # Chromecast/Android TV on this network announces both. The
        # callback ignores which protocol it was actually called for and
        # unconditionally creates a new GA_PROTOCOL_INET resolver, so a
        # dual-stack sink gets two simultaneous duplicate IPv4-resolve
        # requests. Avahi's mDNS duplicate-query suppression (RFC 6762) only
        # answers one; the other's resolver just sits there until GND's own
        # timeout fires "Failed to resolve Avahi service: Resolving failed:
        # Timeout reached" - confirmed via source read 2026-08-14, and via
        # `avahi-browse -r` resolving 100% cleanly at the same moment GND
        # logged failures (ruling out avahi-daemon/network/opensnitch).
        # Fix: only act on the IPv4 browse event, since we only ever
        # request an IPv4 resolver anyway - the IPv6 event's info is
        # redundant for this callback's purposes.
        substituteInPlace src/nd-cc-provider.c \
          --replace-fail \
            'resolver = ga_service_resolver_new (iface,' \
            $'if (proto != GA_PROTOCOL_INET)\n    return;\n\n  resolver = ga_service_resolver_new (iface,'
      '';
    }))
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi
  ];

  environment.sessionVariables.GST_PLUGIN_SYSTEM_PATH_1_0 = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (with pkgs.gst_all_1; [
    gstreamer 
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
    gst-vaapi
  ]);
}
