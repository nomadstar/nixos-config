{ config, lib, pkgs, pkgsUnstable, ... }:

let
  # curl-cffi 0.15.0's test suite (test_verify, in particular) asserts on an
  # old libcurl "SSL certificate problem" error string; the curl-impersonate
  # build it's tested against here reports a newer, differently-worded
  # hostname-mismatch message instead, so the assertion fails and the build
  # breaks - a nixpkgs-unstable packaging bug (upstream hasn't pinned/patched
  # it yet), not anything in this config. yt-dlp only uses curl-cffi as a
  # runtime HTTP-impersonation backend, so skipping its test suite doesn't
  # affect that.
  #
  # yt-dlp's package.nix doesn't expose curl-cffi as an overridable argument
  # (it's pulled in internally via python3Packages.curl-cffi), so the fix has
  # to go the other way: patch curl-cffi, then splice the patched derivation
  # into yt-dlp's `dependencies` list in place of the stock one. (A
  # `python3.override { packageOverrides = ...; }` on the whole pkgs set was
  # tried first and silently had no effect - nixpkgs-unstable's python3
  # derivation doesn't wire that argument through - hence this more direct
  # substitution instead.)
  fixedCurlCffi = pkgsUnstable.python3Packages.curl-cffi.overridePythonAttrs (_: { doCheck = false; });
  yt-dlp = pkgsUnstable.yt-dlp.overridePythonAttrs (old: {
    dependencies = map (d: if (d.pname or null) == "curl-cffi" then fixedCurlCffi else d) old.dependencies;
  });
in
{
  # Needed for discord and wpsoffice (both unfree). Everything else installed
  # here stays free software; these are the deliberate exceptions.
  nixpkgs.config.allowUnfree = true;

  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.mtr.enable = true;

  # iOS device access over USB (ifuse mounts, libimobiledevice's idevice*
  # CLI tools below). The daemon itself, not just the package: it's what
  # multiplexes USB connections to the phone and creates /run/usbmuxd's
  # socket - ifuse/idevicepair etc. can't reach the device without it
  # running, so this needs to be enabled, not just have usbmuxd installed.
  services.usbmuxd.enable = true;

  # Lets prebuilt (non-nixpkgs-packaged) Linux binaries run unmodified -
  # RAPIDS'/PyTorch's pip wheels (compiled extensions), VSCode extensions'
  # native bits, Camoufox/Playwright browser binaries, Qt/PySide6, etc.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    zstd
    brotli
    bzip2
    expat
    harfbuzz
    krb5
    libpulseaudio
    speechd
    openssl
    curl
    ncurses
    icu

    # GUI / Browser / Qt / Playwright / Camoufox runtime dependencies
    glib
    gtk3
    pango
    cairo
    gdk-pixbuf
    atk
    at-spi2-atk
    at-spi2-core
    dbus
    libxkbcommon
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXrender
    xorg.libXtst
    xorg.libxkbfile
    xorg.xcbutil
    xorg.xcbutilcursor
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    mesa
    libglvnd
    libGL
    alsa-lib
    nspr
    nss
    cups
    fontconfig
    freetype
    ffmpeg
    systemd
    libdrm
    wayland
  ];

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

    # GUI archive manager (zip/7z/tar/rar/iso...). xarchiver over
    # file-roller: it's built for exactly this kind of lightweight
    # GTK-but-not-full-GNOME setup (thunar/pcmanfm/nemo) without pulling in
    # nautilus/gnome-autoar as deps, and nemo auto-detects it on PATH to
    # enable its own right-click Extract Here/Compress... context menu
    # entries (same detection mechanism as the terminal exec below).
    xarchiver

    # Provides org.cinnamon.desktop.default-applications.terminal, the
    # gsettings schema nemo's "Open in Terminal" reads (see
    # hosts/*/home.nix's dconf.settings for the actual exec=alacritty
    # value) - nemo is Cinnamon's file manager, but this system doesn't run
    # Cinnamon, so that schema is otherwise never installed/compiled into
    # /run/current-system's gsettings schema path.
    cinnamon-desktop

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

    # iOS device access over USB (services.usbmuxd.enable above runs the
    # actual daemon - this is just its CLI, `iproxy`, for TCP port
    # forwarding over the USB mux). libimobiledevice: ideviceinfo,
    # idevicepair, idevicebackup2, etc. ifuse: mount an iPhone/iPad's
    # filesystem via FUSE (`ifuse ~/mnt/iphone` after pairing with
    # idevicepair).
    usbmuxd
    libimobiledevice
    ifuse

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
  ] ++ (with pkgsUnstable; [
    # Ships new releases often enough that waiting for nixos-25.11 means
    # running months-old versions - see flake.nix's pkgsUnstable comment.
    # (the patched local `yt-dlp` let-binding above shadows this `with`'s
    # pkgsUnstable.yt-dlp - see the curl-cffi comment above.)
    yt-dlp
  ]);

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
