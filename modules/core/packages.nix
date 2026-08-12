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

    # Wireless display casting to Smart TVs (Miracast/WFD, DLNA, Chromecast).
    # Beta/community project (see modules/core/fluxcast.nix) - run
    # `fluxcast --doctor` first to check what's actually usable here.
    fluxcast
  ];
}
