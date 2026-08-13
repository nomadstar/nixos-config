{ config, lib, pkgs, pkgsUnstable, ... }:

{
  programs.hyprland.enable = true;

  # gnome-network-displays' screencast crash-loops a few seconds in
  # ("Asked for a wl_shm buffer which is legacy" -> "Out of buffers" ->
  # pipewiresrc "unhandled format" / "Format negotiation failed" -> session
  # dies, retry, repeat - confirmed live via `journalctl --user -u
  # xdg-desktop-portal-hyprland` and `GST_DEBUG=pipewiresrc:9`). This is
  # https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/423: a race
  # in the screencopy out-of-buffers retry path (Screencopy.cpp
  # wlrOnBufferDone) where `updateStreamParam()` re-enters STREAMING
  # synchronously, installs a new frame callback via startFrameCopy(), and
  # the same branch's `frameCallback.reset()` then destroys it - present in
  # 1.4.0 and 1.4.1 (nixpkgs-unstable's version as of this writing), unchanged
  # on master until fixed by
  # https://github.com/hyprwm/xdg-desktop-portal-hyprland/pull/424, merged
  # 2026-08-06 - after the v1.4.1 tag, so no release contains it yet. Pull
  # that commit directly instead of waiting for the next tag (same
  # fetchFromGitHub as nixpkgs-unstable's derivation, just a newer rev - see
  # `nix log` on this derivation if a future nixpkgs bump makes this
  # redundant and it can be dropped back to `pkgsUnstable.xdg-desktop-portal-hyprland`).
  # #424 stopped it from freezing/spinning at 100% CPU (confirmed: sessions
  # now cleanly destroy-and-recreate instead of wedging), but "Out of
  # buffers" -> MAX_RETRIES(10) -> session dies is still happening on this
  # machine, apparently because the consumer isn't recycling buffers fast
  # enough right at stream start to keep up with the default pool of just
  # XDPH_PWR_BUFFERS=4 (ScreencopyShared.hpp). The PipeWire buffer param is
  # already negotiated as a *range* (4 default, 2 min, 32 max - see
  # ScreencopyShared.cpp SPA_POD_CHOICE_RANGE_Int), so raising just the
  # default gives more slack without touching protocol/max limits. Bumped to
  # 16 - a guess to test, not a measured number; revert this postPatch (and
  # the comment above it) if it doesn't help, or tune further if it does.
  programs.hyprland.portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland.overrideAttrs (old: {
    version = "unstable-2026-08-11";
    src = pkgs.fetchFromGitHub {
      owner = "hyprwm";
      repo = "xdg-desktop-portal-hyprland";
      rev = "9f0e9ff02739cd538d39bd706422dc50e9ca60dd";
      hash = "sha256-/TBQT5rhBB2Dm4HoZzhGDaCwYmRTs3W3DPhMXFWc/BU=";
    };
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/shared/ScreencopyShared.hpp \
        --replace-fail '#define XDPH_PWR_BUFFERS     4' '#define XDPH_PWR_BUFFERS     16'
    '';
  });

  # Without this, Electron/Chromium apps (Discord, VSCode, ...) fall back to
  # XWayland, which doesn't handle this session's fractional/HiDPI scaling
  # right and renders them blurry/pixelated instead of native-Wayland sharp.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    alacritty
    wofi
    wl-clipboard
    grim
    slurp
    nwg-displays
  ];
}
